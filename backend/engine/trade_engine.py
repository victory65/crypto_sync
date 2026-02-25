import asyncio
import secrets
import ccxt.async_support as ccxt
from typing import List, Dict, Any
from core.websocket import broadcast_event
from core.logger import trades_logger, system_logger

class TradeEngine:
    def __init__(self):
        self.is_running = False
        self.retry_limit = 3

    async def start(self):
        self.is_running = True
        system_logger.info("Trade Engine started.")
        await broadcast_event("sync_status_update", {"status": "active", "message": "Engine Started"})

    async def stop(self):
        self.is_running = False
        system_logger.info("Trade Engine stopped.")
        await broadcast_event("sync_status_update", {"status": "inactive", "message": "Engine Stopped"})

    async def fetch_balance(self, exchange_id: str, api_key: str, api_secret: str) -> float:
        """
        Fetches the actual balance from the exchange using CCXT.
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
            # We prioritize USDT for the sync dashboard
            return float(balance.get('total', {}).get('USDT', 0.0))
        except Exception as e:
            system_logger.error(f"Error fetching real balance for {exchange_id}: {e}")
            return 0.0
        finally:
            if exchange:
                await exchange.close()

    async def mirror_trade(self, master_trade: Dict[str, Any], investor_accounts: List[Dict[str, Any]]):
        """
        Mirrors a trade from master to multiple investors in parallel.
        """
        trades_logger.info(f"New Master Trade Detected: {master_trade}")
        
        # Emit initial position update
        position_id = master_trade.get('id', 'PX-' + str(int(asyncio.get_event_loop().time())))
        trade_type = master_trade.get('trade_type', 'spot')
        
        await broadcast_event("position_update", {
            "position_id": position_id,
            "master_status": "detected",
            "symbol": master_trade.get('symbol'),
            "side": master_trade.get('side'),
            "trade_type": trade_type,
            "investor_updates": []
        })

        tasks = [self.execute_investor_trade(position_id, master_trade, investor) for investor in investor_accounts]
        results = await asyncio.gather(*tasks)
        
        trades_logger.info(f"Mirroring completed for position {position_id}. Results: {results}")

    async def execute_investor_trade(self, position_id: str, master_trade: Dict[str, Any], investor: Dict[str, Any]):
        """
        Executes a single trade on a investor account with retry logic.
        """
        account_id = investor.get('id')
        symbol = master_trade.get('symbol')
        side = master_trade.get('side')
        trade_type = master_trade.get('trade_type', 'spot')
        investor_trade_type = investor.get('trade_type', 'spot')
        
        # Trade Type Filtering
        if investor_trade_type != 'both' and investor_trade_type != trade_type:
            trades_logger.info(f"Skipping account {account_id}: Investor type {investor_trade_type} does not match trade type {trade_type}")
            await broadcast_event("investor_execution_update", {
                "position_id": position_id,
                "account_id": account_id,
                "status": "ignored",
                "reason": f"Mismatched type ({investor_trade_type} vs {trade_type})"
            })
            return {"status": "ignored", "reason": "Mismatched trade type"}

        # Calculate lot size based on investor settings (Fixed or Percentage)
        lot_size_val = investor.get('lot_size', 0.01)
        mode = investor.get('lot_size_mode', 'fixed')
        balance = investor.get('balance', 0.0)
        
        if mode == 'percentage':
            # lot_size_val is a percentage (e.g. 10 for 10%)
            lot_size = balance * (lot_size_val / 100.0)
        else:
            # Fixed amount
            lot_size = lot_size_val

        for attempt in range(1, self.retry_limit + 1):
            try:
                trades_logger.info(f"Attempt {attempt}/{self.retry_limit} for Account {account_id} | {symbol} {side}")
                
                # Emit retry event if not first attempt
                if attempt > 1:
                    await broadcast_event("trade_retry", {
                        "position_id": position_id,
                        "account_id": account_id,
                        "attempt": attempt,
                        "status": "retrying"
                    })

                # In production, we fetch encrypted keys from DB and decrypt them here
                # encrypted_api_key = investor.get('encrypted_api_key')
                # api_key = decrypt_api_key(encrypted_api_key)
                
                # Simulate the use of the decrypted key
                trades_logger.info(f"Decrypting API key for account {account_id}...")
                
                # Simulate API call to exchange
                await asyncio.sleep(0.5) # Simulate network latency
                
                if attempt < 2 and account_id == "investor_fail_demo": # Simulation of failure
                    raise Exception("Mock Exchange API Error")

                # Success
                result = {"status": "filled", "order_id": f"ord-{secrets.token_hex(4)}"}
                await broadcast_event("investor_execution_update", {
                    "position_id": position_id,
                    "account_id": account_id,
                    "status": "filled",
                    "attempt": attempt,
                    "order_id": result['order_id']
                })
                return result

            except Exception as e:
                trades_logger.error(f"Error on account {account_id}, attempt {attempt}: {e}")
                if attempt == self.retry_limit:
                    await broadcast_event("investor_execution_update", {
                        "position_id": position_id,
                        "account_id": account_id,
                        "status": "failed",
                        "reason": str(e),
                        "attempt": attempt
                    })
                    return {"status": "failed", "reason": str(e)}
                
                await asyncio.sleep(1) # Wait before retry

import secrets
engine = TradeEngine()

