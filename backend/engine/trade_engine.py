import asyncio
import secrets
import ccxt.async_support as ccxt
from typing import List, Dict, Any
from core.websocket import broadcast_event
from core.logger import trades_logger, system_logger
from core.security import decrypt_api_key
from core.database import get_db
from datetime import datetime

class TradeEngine:
    def __init__(self):
        self.is_running = False
        self.retry_limit = 3
        self.background_task = None

    async def start(self):
        if self.is_running:
            return
        self.is_running = True
        self.background_task = asyncio.create_task(self.monitor_masters())
        system_logger.info("Trade Engine started.")

    async def stop(self):
        self.is_running = False
        if self.background_task:
            self.background_task.cancel()
        system_logger.info("Trade Engine stopped.")

    async def fetch_balance(self, exchange_id: str, api_key: str, api_secret: str) -> float:
        """
        Fetches the actual USDT balance from the exchange using CCXT.
        """
        exchange = None
        try:
            if not exchange_id or exchange_id == "mock":
                return 0.0
                
            exchange_class = getattr(ccxt, exchange_id)
            exchange = exchange_class({
                'apiKey': api_key,
                'secret': api_secret,
                'enableRateLimit': True,
            })
            
            balance = await exchange.fetch_balance()
            return float(balance.get('total', {}).get('USDT', 0.0))
        except Exception as e:
            system_logger.error(f"Error fetching balance for {exchange_id}: {e}")
            return 0.0
        finally:
            if exchange:
                await exchange.close()

    async def mirror_trade(self, master_trade: Dict[str, Any], investor_accounts: List[Dict[str, Any]], master_trade_id: str = None):
        """
        Mirrors a trade from master to multiple investors in parallel.
        """
        position_id = f"PX-{secrets.token_hex(4)}"
        trades_logger.info(f"Mirroring Trade {position_id} to {len(investor_accounts)} investors")
        
        await broadcast_event("position_update", {
            "position_id": position_id,
            "master_status": "detected",
            "symbol": master_trade.get('symbol'),
            "side": master_trade.get('side'),
            "quantity": master_trade.get('quantity'),
            "investor_updates": []
        })

        tasks = [self.execute_investor_trade(position_id, master_trade, investor, master_trade_id) for investor in investor_accounts]
        await asyncio.gather(*tasks)

    async def monitor_masters(self):
        """
        Background loop that polls Master accounts for new trades.
        """
        while self.is_running:
            try:
                # 1. Fetch enabled master accounts with non-expired plans
                async with get_db() as conn:
                    async with conn.execute("""
                        SELECT a.*, u.plan_expiry 
                        FROM accounts a 
                        JOIN users u ON a.user_id = u.id 
                        WHERE a.type = 'master' AND a.enabled = 1
                    """) as cursor:
                        masters = [dict(r) for r in await cursor.fetchall()]

                now = datetime.now(timezone.utc).timestamp()
                for master in masters:
                    # Skip if plan is expired
                    if master['plan_expiry'] and now > master['plan_expiry']:
                         trades_logger.warning(f"Skipping monitor for user {master['user_id']}: Plan expired")
                         continue
                    await self._scan_master_account(master)

            except Exception as e:
                system_logger.error(f"Error in monitor_masters: {e}")
            
            await asyncio.sleep(10) # Poll every 10 seconds

    async def _scan_master_account(self, master: Dict[str, Any]):
        exchange_id = master['exchange']
        api_key = decrypt_api_key(master['encrypted_key'])
        api_secret = decrypt_api_key(master['encrypted_secret'])
        user_id = master['user_id']
        
        exchange = None
        try:
            exchange_class = getattr(ccxt, exchange_id)
            exchange = exchange_class({
                'apiKey': api_key,
                'secret': api_secret,
                'enableRateLimit': True,
            })
            
            # Fetch last 3 orders to detect new ones
            orders = await exchange.fetch_orders(limit=3)
            
            # For each order, check if it's already processed
            for order in orders:
                if order['status'] not in ['closed', 'filled']:
                    continue
                
                # Check uniqueness in DB
                async with get_db() as conn:
                    async with conn.execute("SELECT id FROM trades WHERE master_trade_id = ? AND account_id = ?", (order['id'], master['id'])) as cursor:
                        if await cursor.fetchone():
                            continue # Already processed for this master

                # New Trade Detected! Trigger Mirroring
                trades_logger.info(f"New EXTERNAL trade detected on master {master['name']} ({master['id']}): {order['id']}")
                
                # Fetch investors for this user
                async with get_db() as conn:
                    async with conn.execute("SELECT * FROM accounts WHERE user_id = ? AND type = 'investor' AND enabled = 1", (user_id,)) as cursor:
                        investors = [dict(r) for r in await cursor.fetchall()]
                
                # Mirroring
                master_trade_data = {
                    "symbol": order['symbol'],
                    "side": order['side'],
                    "quantity": order['amount']
                }
                
                # Log the master trade itself first
                async with get_db() as conn:
                    await conn.execute(
                        "INSERT INTO trades (id, master_trade_id, user_id, account_id, symbol, side, quantity, price, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        (f"MTR-{secrets.token_hex(4)}", order['id'], user_id, master['id'], order['symbol'], order['side'], order['amount'], order['price'], 'filled', datetime.now().isoformat())
                    )
                    await conn.commit()

                await self.mirror_trade(master_trade_data, investors, master_trade_id=order['id'])

        except Exception as e:
            system_logger.warning(f"Failed to scan master {master['id']}: {e}")
        finally:
            if exchange:
                await exchange.close()

    async def execute_investor_trade(self, position_id: str, master_trade: Dict[str, Any], investor: Dict[str, Any], master_trade_id: str = None):
        """
        Executes a spot trade on an investor account using CCXT.
        """
        account_id = investor.get('id')
        user_id = investor.get('user_id')
        symbol = master_trade.get('symbol')
        side = master_trade.get('side').lower() # 'buy' or 'sell'
        qty = master_trade.get('quantity')
        
        # Calculate investor quantity based on lot size settings
        investor_qty = self._calculate_quantity(investor, qty)
        
        exchange_id = investor.get('exchange', 'binance')
        api_key = decrypt_api_key(investor.get('encrypted_key'))
        api_secret = decrypt_api_key(investor.get('encrypted_secret'))

        for attempt in range(1, self.retry_limit + 1):
            exchange = None
            try:
                exchange_class = getattr(ccxt, exchange_id)
                exchange = exchange_class({
                    'apiKey': api_key,
                    'secret': api_secret,
                    'enableRateLimit': True,
                })
                
                # Spot Market Order
                order = await exchange.create_market_order(symbol, side, investor_qty)
                
                trades_logger.info(f"Success: Account {account_id} | {symbol} {side} {investor_qty} | Order ID: {order['id']}")
                
                # Persist to DB
                async with get_db() as conn:
                    await conn.execute(
                        "INSERT INTO trades (id, master_trade_id, user_id, account_id, symbol, side, quantity, price, status, exchange_order_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        (f"INV-{secrets.token_hex(4)}", master_trade_id, user_id, account_id, symbol, side, investor_qty, order.get('average', order.get('price')), 'filled', order['id'], datetime.now().isoformat())
                    )
                    await conn.commit()

                await broadcast_event("investor_execution_update", {
                    "position_id": position_id,
                    "account_id": account_id,
                    "status": "filled",
                    "price": order.get('average', order.get('price')),
                    "qty": investor_qty,
                    "order_id": order['id']
                })
                return {"status": "filled", "order_id": order['id']}

            except Exception as e:
                trades_logger.error(f"Trade Error (Account {account_id}, Attempt {attempt}): {e}")
                if attempt == self.retry_limit:
                    await broadcast_event("investor_execution_update", {
                        "position_id": position_id,
                        "account_id": account_id,
                        "status": "failed",
                        "reason": str(e)
                    })
                    return {"status": "failed", "reason": str(e)}
                
                await asyncio.sleep(2 ** attempt) # Exponential backoff
            finally:
                if exchange:
                    await exchange.close()

    def _calculate_quantity(self, investor: Dict[str, Any], master_qty: float) -> float:
        mode = investor.get('lot_size_mode', 'fixed')
        value = investor.get('lot_size', 0.01)
        
        if mode == 'percentage':
            # lot_size is a multiplier of master qty (e.g., 50 means 50%)
            return master_qty * (value / 100.0)
        return value # Fixed lot

engine = TradeEngine()

