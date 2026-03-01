import asyncio
import secrets
import json
import aiohttp
import ccxt.async_support as ccxt
from typing import List, Dict, Any, Optional
from core.websocket import broadcast_event
from core.logger import trades_logger, system_logger
from core.security import decrypt_api_key
from core.database import get_db
from datetime import datetime, timezone

class TradeEngine:
    def __init__(self):
        self.is_running = False
        self.retry_limit = 3
        self.monitor_task = None
        self.balance_task = None
        self._supported_exchanges = [
            'binance', 'binanceus', 'bybit', 'bitget', 'okx', 'gateio', 'mexc',
            'kraken', 'phemex', 'deribit', 'bitmex', 'coinbase', 'kucoin'
        ]
    
    async def start(self):
        if self.is_running:
            return
        self.is_running = True
        self.monitor_task = asyncio.create_task(self.monitor_masters())
        system_logger.info("Trade Engine started (Manual Balance Sync).")
    
    async def stop(self):
        self.is_running = False
        if self.monitor_task:
            self.monitor_task.cancel()
        if self.balance_task:
            self.balance_task.cancel()
        
        try:
            if self.monitor_task: await self.monitor_task
            if self.balance_task: await self.balance_task
        except asyncio.CancelledError:
            pass
        system_logger.info("Trade Engine stopped.")
    
    def _validate_exchange(self, exchange_id: str) -> bool:
        """Validate if exchange is supported."""
        if not exchange_id or exchange_id == "mock":
            return False
        return exchange_id.lower() in self._supported_exchanges
    
    async def fetch_balance(self, exchange_id: str, api_key: str, api_secret: str, passphrase: str = None, is_testnet: bool = False) -> float:
        """
        Fetches the actual USDT balance from the exchange using CCXT.
        """
        if not self._validate_exchange(exchange_id):
            return 0.0
        
        if not api_key or not api_secret:
            return 0.0
        
        exchange = None
        try:
            exchange_options = {
                'apiKey': api_key.strip() if api_key else api_key,
                'secret': api_secret.strip() if api_secret else api_secret,
                'password': passphrase.strip() if passphrase else passphrase,
                'enableRateLimit': True,
                'options': {
                    'defaultType': 'spot',
                }
            }
            
            if exchange_id.lower() in ['binance', 'binanceus']:
                exchange_options['adjustForTimeDifference'] = True
                exchange_options['options']['recvWindow'] = 60000  # Max 60s window
                exchange_options['options']['adjustForTimeDifference'] = True
                
            exchange_class = getattr(ccxt, exchange_id.lower())
            exchange = exchange_class(exchange_options)
            
            if is_testnet:
                exchange.set_sandbox_mode(True)
                
            balance = await exchange.fetch_balance()
            usdt_balance = float(balance.get('total', {}).get('USDT', 0.0))
            return usdt_balance
        except Exception as e:
            error_msg = str(e)
            if exchange_id.lower() == 'binance' and "Invalid Api-Key ID" in error_msg:
                # Detection: Binance Testnet keys often start with 'vm' or are shorter
                if api_key.startswith('vm') or len(api_key) < 32:
                    system_logger.error(f"Binance Error: Detected potential TESTNET key being used on MAINNET. Please use production API keys.")
                else:
                    # Log the IP for whitelisting help
                    try:
                        async with aiohttp.ClientSession() as session:
                            async with session.get('https://api.ipify.org?format=json') as resp:
                                ip_data = await resp.json()
                                current_ip = ip_data.get('ip', 'Unknown')
                                system_logger.error(f"Binance Auth Failure: Invalid API Key. Please ensure IP Whitelisting is DISABLED or your server IP ({current_ip}) is added to the whitelist on Binance.")
                    except:
                        system_logger.error(f"Binance Auth Failure: Invalid API Key. Ensure IP whitelisting is configured correctly on Binance.")
            else:
                system_logger.error(f"Error fetching balance for {exchange_id}: {e}")
            return 0.0
        finally:
            if exchange:
                try:
                    await exchange.close()
                except:
                    pass
    
    async def mirror_trade(self, master_trade: Dict[str, Any], investor_accounts: List[Dict[str, Any]], master_trade_id: str = None):
        """
        Mirrors a trade from master to multiple investors in parallel.
        """
        if not investor_accounts:
            trades_logger.warning("No investor accounts to mirror trade to")
            return
        
        if not master_trade:
            trades_logger.error("Invalid master_trade data")
            return
        
        position_id = f"PX-{secrets.token_hex(4)}"
        symbol = master_trade.get('symbol')
        side = master_trade.get('side')
        quantity = master_trade.get('quantity')
        
        if not symbol or not side or quantity is None:
            trades_logger.error(f"Invalid trade data: symbol={symbol}, side={side}, qty={quantity}")
            return
        
        trades_logger.info(f"Mirroring Trade {position_id} to {len(investor_accounts)} investors")
        
        try:
            await broadcast_event("position_update", {
                "position_id": position_id,
                "master_status": "detected",
                "symbol": symbol,
                "side": side,
                "quantity": quantity,
                "total_investors": len(investor_accounts),
                "investor_updates": []
            })
        except Exception as e:
            system_logger.error(f"Failed to broadcast position update: {e}")
        
        # Execute trades for all investors in parallel
        tasks = [
            self.execute_investor_trade(position_id, master_trade, investor, master_trade_id)
            for investor in investor_accounts
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Log results
        success_count = sum(1 for r in results if isinstance(r, dict) and r.get('status') == 'filled')
        failed_count = len(results) - success_count
        
        trades_logger.info(f"Trade mirroring complete: {success_count} success, {failed_count} failed")
        
        # Refresh balances for all involved accounts (Master + Investors)
        user_id = master_trade.get('user_id')
        if user_id:
            asyncio.create_task(self.sync_user_balances(user_id))
    
    async def monitor_masters(self):
        """
        Background loop that polls Master accounts for new trades.
        """
        while self.is_running:
            try:
                # Fetch enabled master accounts with non-expired plans
                async with get_db() as conn:
                    async with conn.execute(
                        """
                        SELECT a.*, u.plan_expiry, u.email
                        FROM accounts a
                        JOIN users u ON a.user_id = u.id
                        WHERE a.type = 'master' AND a.enabled = 1
                        """
                    ) as cursor:
                        masters = [dict(r) for r in await cursor.fetchall()]
                
                now = datetime.now(timezone.utc).timestamp()
                
                for master in masters:
                    # Skip if plan is expired (Admin bypass)
                    plan_expiry = master.get('plan_expiry')
                    is_admin = master.get('email') == "admin@crypto.sync"
                    if not is_admin and plan_expiry and now > plan_expiry:
                        trades_logger.warning(f"Skipping monitor for user {master['user_id']}: Plan expired")
                        continue
                    
                    try:
                        await self._scan_master_account(master)
                    except Exception as e:
                        system_logger.error(f"Error scanning master {master.get('id')}: {e}")
                
            except Exception as e:
                system_logger.error(f"Error in monitor_masters: {e}")
            
            await asyncio.sleep(10)  # Poll every 10 seconds
            
    async def sync_user_balances(self, user_id: str):
        """
        Refreshes and broadcasts account balances for a specific user.
        """
        try:
            # Fetch all active accounts for this user
            async with get_db() as conn:
                async with conn.execute(
                    "SELECT id, user_id, type, exchange, encrypted_key, encrypted_secret, encrypted_passphrase, is_testnet FROM accounts WHERE user_id = ? AND enabled = 1",
                    (user_id,)
                ) as cursor:
                    accounts = [dict(r) for r in await cursor.fetchall()]
            
            if not accounts:
                return

            balances = {}
            for account in accounts:
                acc_id = account['id']
                
                api_key = decrypt_api_key(account.get('encrypted_key')).strip()
                api_secret = decrypt_api_key(account.get('encrypted_secret')).strip()
                
                passphrase = None
                enc_pass = account.get('encrypted_passphrase')
                if enc_pass:
                    passphrase = decrypt_api_key(enc_pass).strip()
                
                if not api_key or not api_secret:
                    continue
                    
                is_testnet = bool(account.get('is_testnet', 0))
                balance = await self.fetch_balance(account.get('exchange'), api_key, api_secret, passphrase=passphrase, is_testnet=is_testnet)
                
                if balance >= 0:
                    balances[acc_id] = balance
                    # Update DB
                    async with get_db() as conn:
                        await conn.execute(
                            "UPDATE accounts SET balance = ? WHERE id = ?",
                            (balance, acc_id)
                        )
                        await conn.commit()
            
            if balances:
                # Calculate total investors balance
                investors_total = sum(bal for acc_id, bal in balances.items() if acc_id.startswith('acc_'))
                balances['investors_total'] = investors_total
                
                try:
                    await broadcast_event("balance_update", balances, user_id=user_id)
                    system_logger.debug(f"Broadcasted manual balance update for user {user_id}")
                except Exception as e:
                    system_logger.error(f"Failed to broadcast balances for {user_id}: {e}")
                            
        except Exception as e:
            system_logger.error(f"Error in sync_user_balances: {e}")
    
    async def _scan_master_account(self, master: Dict[str, Any]):
        exchange_id = master.get('exchange')
        encrypted_key = master.get('encrypted_key')
        encrypted_secret = master.get('encrypted_secret')
        user_id = master.get('user_id')
        master_id = master.get('id')
        
        if not self._validate_exchange(exchange_id):
            return
        
        if not encrypted_key or not encrypted_secret:
            return
        
        api_key = decrypt_api_key(encrypted_key).strip()
        api_secret = decrypt_api_key(encrypted_secret).strip()
        
        if not api_key or not api_secret:
            system_logger.warning(f"Invalid API credentials for master {master_id}")
            return
        
        passphrase = None
        enc_pass = master.get('encrypted_passphrase')
        if enc_pass:
            passphrase = decrypt_api_key(enc_pass).strip()
        
        exchange = None
        try:
            exchange_options = {
                'apiKey': api_key,
                'secret': api_secret,
                'password': passphrase,
                'enableRateLimit': True,
                'options': {
                    'defaultType': master.get('trade_type', 'spot'),
                }
            }
            if exchange_id.lower() in ['binance', 'binanceus']:
                exchange_options['adjustForTimeDifference'] = True
                exchange_options['options']['recvWindow'] = 60000
                exchange_options['options']['adjustForTimeDifference'] = True
                
            exchange_class = getattr(ccxt, exchange_id.lower())
            exchange = exchange_class(exchange_options)
            
            if bool(master.get('is_testnet', 0)):
                exchange.set_sandbox_mode(True)
            
            # Scanning logic: many exchanges like Binance require a symbol for fetch_orders
            # We first try to fetch open orders (some exchanges allow this without symbol)
            # If that fails, we use a default symbol or skip
            orders = []
            try:
                if exchange_id.lower() in ['binance', 'binanceus']:
                    # Special Case: Binance fetch_orders REQUIRES a symbol
                    # We iterate through some common symbols to catch trades
                    common_symbols = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'ADA/USDT', 'BNB/USDT']
                    for sym in common_symbols:
                        try:
                            sym_orders = await exchange.fetch_orders(symbol=sym, limit=2)
                            orders.extend(sym_orders)
                        except Exception:
                            continue
                else:
                    orders = await exchange.fetch_orders(limit=3)
            except Exception as e:
                system_logger.error(f"Scan Warning: {exchange_id} couldn't poll orders without specific symbol: {e}")
                # Fallback to fetching specific recent trades if possible
                try:
                    orders = await exchange.fetch_open_orders()
                except:
                    pass
            
            # For each order, check if it's already processed
            for order in orders:
                if order.get('status') not in ['closed', 'filled']:
                    continue
                
                order_id = order.get('id')
                if not order_id:
                    continue
                
                # Check uniqueness in DB
                async with get_db() as conn:
                    async with conn.execute(
                        "SELECT id FROM trades WHERE master_trade_id = ? AND account_id = ?",
                        (order_id, master_id)
                    ) as cursor:
                        if await cursor.fetchone():
                            continue  # Already processed for this master
                
                # New Trade Detected! Trigger Mirroring
                trades_logger.info(f"New EXTERNAL trade detected on master {master.get('name')} ({master_id}): {order_id}")
                
                # Fetch investors for this user
                async with get_db() as conn:
                    async with conn.execute(
                        "SELECT * FROM accounts WHERE user_id = ? AND type = 'investor' AND enabled = 1",
                        (user_id,)
                    ) as cursor:
                        investors = [dict(r) for r in await cursor.fetchall()]
                
                if not investors:
                    trades_logger.info(f"No active investors for user {user_id}")
                    continue
                
                # Mirroring
                master_trade_data = {
                    "symbol": order.get('symbol'),
                    "side": order.get('side'),
                    "quantity": order.get('amount')
                }
                
                # Log the master trade itself first
                try:
                    async with get_db() as conn:
                        await conn.execute(
                            """INSERT INTO trades 
                                (id, master_trade_id, user_id, account_id, symbol, side, quantity, price, status, created_at) 
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                            (
                                f"MTR-{secrets.token_hex(4)}",
                                order_id,
                                user_id,
                                master_id,
                                order.get('symbol'),
                                order.get('side'),
                                order.get('amount'),
                                order.get('price'),
                                'filled',
                                datetime.now().isoformat()
                            )
                        )
                        await conn.commit()
                except Exception as e:
                    system_logger.error(f"Failed to log master trade: {e}")
                
                # Trigger mirroring
                await self.mirror_trade(master_trade_data, investors, master_trade_id=order_id)
                
        except Exception as e:
            error_msg = str(e)
            if exchange_id.lower() == 'binance' and "Invalid Api-Key ID" in error_msg:
                # Specialized Binance Diagnostic
                key_preview = f"{api_key[:4]}...{api_key[-4:]}" if len(api_key) > 8 else "****"
                trades_logger.error(f"Binance AUTH FAILURE for Master {master_id} (Key: {key_preview}). Ensure IP is whitelisted or Key is valid.")
            system_logger.warning(f"Failed to scan master {master_id}: {e}")
        finally:
            if exchange:
                try:
                    await exchange.close()
                except:
                    pass
    
    async def execute_investor_trade(self, position_id: str, master_trade: Dict[str, Any], investor: Dict[str, Any], master_trade_id: str = None):
        """
        Executes a spot trade on an investor account using CCXT.
        """
        account_id = investor.get('id')
        user_id = investor.get('user_id')
        
        if not account_id or not user_id:
            trades_logger.error("Invalid investor data: missing id or user_id")
            return {"status": "failed", "reason": "Invalid investor data"}
        
        symbol = master_trade.get('symbol')
        side = master_trade.get('side', '').lower()
        qty = master_trade.get('quantity')
        
        if not symbol or not side or qty is None:
            error_msg = f"Invalid trade parameters: symbol={symbol}, side={side}, qty={qty}"
            trades_logger.error(error_msg)
            return {"status": "failed", "reason": error_msg}
        
        # Calculate investor quantity based on lot size settings
        investor_qty = self._calculate_quantity(investor, qty)
        
        if investor_qty <= 0:
            error_msg = f"Invalid calculated quantity: {investor_qty}"
            trades_logger.error(f"Account {account_id}: {error_msg}")
            return {"status": "failed", "reason": error_msg}
        
        exchange_id = investor.get('exchange', 'binance')
        encrypted_key = investor.get('encrypted_key')
        encrypted_secret = investor.get('encrypted_secret')
        
        if not encrypted_key or not encrypted_secret:
            error_msg = "Missing API credentials"
            trades_logger.error(f"Account {account_id}: {error_msg}")
            return {"status": "failed", "reason": error_msg}
        
        api_key = decrypt_api_key(encrypted_key).strip()
        api_secret = decrypt_api_key(encrypted_secret).strip()
        
        passphrase = None
        enc_pass = investor.get('encrypted_passphrase')
        if enc_pass:
            passphrase = decrypt_api_key(enc_pass).strip()
        
        if not api_key or not api_secret:
            error_msg = "Invalid API credentials (decryption failed)"
            trades_logger.error(f"Account {account_id}: {error_msg}")
            return {"status": "failed", "reason": error_msg}
        
        # Validate exchange
        if not self._validate_exchange(exchange_id):
            error_msg = f"Unsupported exchange: {exchange_id}"
            trades_logger.error(f"Account {account_id}: {error_msg}")
            return {"status": "failed", "reason": error_msg}
        
        for attempt in range(1, self.retry_limit + 1):
            exchange = None
            try:
                exchange_options = {
                    'apiKey': api_key,
                    'secret': api_secret,
                    'password': passphrase,
                    'enableRateLimit': True,
                    'options': {
                        'defaultType': investor.get('trade_type', 'spot'),
                    }
                }
                if exchange_id.lower() in ['binance', 'binanceus']:
                    exchange_options['adjustForTimeDifference'] = True
                    exchange_options['options']['recvWindow'] = 60000
                    exchange_options['options']['adjustForTimeDifference'] = True
                    
                exchange_class = getattr(ccxt, exchange_id.lower())
                exchange = exchange_class(exchange_options)
                
                if bool(investor.get('is_testnet', 0)):
                    exchange.set_sandbox_mode(True)
                
                # Minimum Notional Check for Binance
                if exchange_id.lower() in ['binance', 'binanceus']:
                    try:
                        ticker = await exchange.fetch_ticker(symbol)
                        price = ticker.get('last') or ticker.get('close')
                        if price:
                            notional = investor_qty * price
                            if notional < 10.1:  # Binance min is 5-10 USDT, use 10.1 as safe buffer
                                error_msg = f"Order value ${notional:.2f} is below Binance minimum ($10.00)"
                                trades_logger.warning(f"Account {account_id} SKIP: {error_msg}")
                                await self._notify_trade_failure(position_id, account_id, f"SKIP: Below Min Notional (${notional:.2f})")
                                return {"status": "failed", "reason": error_msg}
                    except Exception as ticker_err:
                        system_logger.error(f"Failed to fetch ticker for notional check: {ticker_err}")

                # Spot Market Order
                order = await exchange.create_market_order(symbol, side, investor_qty)
                
                trades_logger.info(f"Success: Account {account_id} | {symbol} {side} {investor_qty} | Order ID: {order.get('id')}")
                
                # Persist to DB
                try:
                    async with get_db() as conn:
                        await conn.execute(
                            """INSERT INTO trades 
                                (id, master_trade_id, user_id, account_id, symbol, side, quantity, price, status, exchange_order_id, created_at) 
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                            (
                                f"INV-{secrets.token_hex(4)}",
                                master_trade_id,
                                user_id,
                                account_id,
                                symbol,
                                side,
                                investor_qty,
                                order.get('average', order.get('price')),
                                'filled',
                                order.get('id'),
                                datetime.now().isoformat()
                            )
                        )
                        await conn.commit()
                except Exception as e:
                    system_logger.error(f"Failed to persist trade to DB: {e}")
                
                # Broadcast success
                try:
                    await broadcast_event("investor_execution_update", {
                        "position_id": position_id,
                        "account_id": account_id,
                        "status": "filled",
                        "price": order.get('average', order.get('price')),
                        "qty": investor_qty,
                        "order_id": order.get('id')
                    })
                    
                    # Immediate balance refresh for this account
                    new_balance = await self.fetch_balance(exchange_id, api_key, api_secret)
                    if new_balance > 0:
                        async with get_db() as conn:
                            await conn.execute("UPDATE accounts SET balance = ? WHERE id = ?", (new_balance, account_id))
                            await conn.commit()
                        await broadcast_event("balance_update", {account_id: new_balance}, user_id=user_id)
                except Exception as e:
                    system_logger.error(f"Failed to process post-trade updates: {e}")
                
                return {"status": "filled", "order_id": order.get('id')}
                
            except ccxt.NetworkError as e:
                trades_logger.error(f"Network Error (Account {account_id}, Attempt {attempt}): {e}")
                if attempt == self.retry_limit:
                    await self._notify_trade_failure(position_id, account_id, f"Network error: {str(e)}")
                    return {"status": "failed", "reason": f"Network error: {str(e)}"}
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
                
            except ccxt.ExchangeError as e:
                trades_logger.error(f"Exchange Error (Account {account_id}): {e}")
                await self._notify_trade_failure(position_id, account_id, f"Exchange error: {str(e)}")
                return {"status": "failed", "reason": f"Exchange error: {str(e)}"}
                
            except Exception as e:
                trades_logger.error(f"Trade Error (Account {account_id}, Attempt {attempt}): {e}")
                if attempt == self.retry_limit:
                    await self._notify_trade_failure(position_id, account_id, str(e))
                    return {"status": "failed", "reason": str(e)}
                await asyncio.sleep(2 ** attempt)
                
            finally:
                if exchange:
                    try:
                        await exchange.close()
                    except:
                        pass
        
        return {"status": "failed", "reason": "Max retries exceeded"}
    
    async def _notify_trade_failure(self, position_id: str, account_id: str, reason: str):
        """Helper to broadcast trade failure."""
        try:
            await broadcast_event("investor_execution_update", {
                "position_id": position_id,
                "account_id": account_id,
                "status": "failed",
                "reason": reason
            })
        except Exception as e:
            system_logger.error(f"Failed to broadcast failure: {e}")
    
    def _calculate_quantity(self, investor: Dict[str, Any], master_qty: float) -> float:
        """Calculate investor quantity based on lot size settings."""
        if not investor or master_qty is None:
            return 0.0
        
        mode = investor.get('lot_size_mode', 'fixed')
        value = investor.get('lot_size', 0.01)
        
        try:
            if mode == 'percentage':
                # lot_size is a multiplier of master qty (e.g., 50 means 50%)
                return master_qty * (float(value) / 100.0)
            else:
                # Fixed lot
                return float(value)
        except (TypeError, ValueError):
            return 0.01  # Default fallback

# Global engine instance
engine = TradeEngine()
