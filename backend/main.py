from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import asyncio
import secrets
import uvicorn
from datetime import datetime, timedelta, timezone
import ccxt.async_support as ccxt

from core.security import decode_access_token, verify_password, create_access_token, get_password_hash, encrypt_api_key, decrypt_api_key
from core.websocket import manager, broadcast_event
from core.logger import system_logger, auth_logger, trades_logger
from engine.trade_engine import engine
from core.database import get_db, init_db
import pyotp
import contextlib
import qrcode
import io
import base64

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    await engine.start()
    yield
    # Shutdown
    await engine.stop()

app = FastAPI(title="Crypto Sync Production Backend", lifespan=lifespan)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Supported exchanges
SUPPORTED_EXCHANGES = [
    'binance', 'binanceus', 'bybit', 'bitget', 'okx', 'gateio', 'gate', 'mexc',
    'kraken', 'phemex', 'deribit', 'bitmex', 'coinbase', 'kucoin'
]

def validate_exchange(exchange_id: str) -> bool:
    """Validate if exchange is supported."""
    if not exchange_id:
        return False
    return exchange_id.lower() in SUPPORTED_EXCHANGES

# --- WebSocket Endpoint ---

@app.websocket("/ws/user/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str, token: Optional[str] = None):
    # Authenticate
    if not token or not decode_access_token(token):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        auth_logger.warning(f"WebSocket connection rejected for user {user_id}: Invalid Token")
        return

    await manager.connect(user_id, websocket)
    # Refresh balances on connection
    asyncio.create_task(engine.sync_user_balances(user_id))
    try:
        while True:
            # Maintain connection and listen for heartbeats
            data = await websocket.receive_text()
            if data == "ping":
                system_logger.debug(f"Heartbeat: Ping from {user_id}")
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception as e:
        system_logger.error(f"WebSocket error for {user_id}: {e}")
        manager.disconnect(user_id, websocket)

# --- Database Helpers (Async) ---

async def get_user_by_email(email: str):
    async with get_db() as conn:
        async with conn.execute("SELECT * FROM users WHERE email = ?", (email,)) as cursor:
            user = await cursor.fetchone()
            return dict(user) if user else None

async def get_user_by_id(user_id: str):
    async with get_db() as conn:
        async with conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)) as cursor:
            user = await cursor.fetchone()
            return dict(user) if user else None

async def get_user_accounts(user_id: str):
    async with get_db() as conn:
        async with conn.execute("SELECT * FROM accounts WHERE user_id = ?", (user_id,)) as cursor:
            rows = await cursor.fetchall()
            return [dict(r) for r in rows]

async def create_session(user_id: str, device: str, ip: str, token: str):
    session_id = f"sess_{secrets.token_hex(8)}"
    async with get_db() as conn:
        await conn.execute(
            "INSERT INTO sessions (id, user_id, device_name, ip_address, login_time, token) VALUES (?, ?, ?, ?, ?, ?)",
            (session_id, user_id, device, ip, datetime.now().isoformat(), token)
        )
        await conn.commit()
    return session_id

# --- Auth Endpoints ---

@app.post("/auth/signup")
async def signup(data: dict):
    email = data.get("email")
    password = data.get("password")
    name = data.get("name", "New User")
    phone = data.get("phone")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password required")
    
    if len(password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    
    is_admin = email == "admin@crypto.sync" and password == "admin123"
        
    # Check if email exists
    if await get_user_by_email(email):
        raise HTTPException(status_code=400, detail="Email already registered")
        
    # Create user
    user_id = f"user_{secrets.token_hex(4)}"
    hashed_password = get_password_hash(password)
    # Production: Free tier is 3 days
    expiry = (datetime.now(timezone.utc) + timedelta(days=3)).timestamp()
    
    async with get_db() as conn:
        await conn.execute(
            "INSERT INTO users (id, email, hashed_password, name, phone, plan, plan_expiry, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (user_id, email, hashed_password, name, phone, "free", expiry, datetime.now().isoformat())
        )
        await conn.commit()
    
    auth_logger.info(f"New user registered: {email} (ID: {user_id})")
    token = create_access_token({"sub": email, "user_id": user_id})
    
    # Log session
    await create_session(user_id, "Mobile Device (Sign up)", "Unknown", token)

    return {
        "access_token": token, 
        "token_type": "bearer", 
        "user_id": user_id,
        "name": name,
        "email": email,
        "phone": phone,
        "profile_pic": None,
        "is_admin": is_admin
    }

RESET_TOKENS = {}

@app.post("/auth/login")
async def login(data: dict):
    email = data.get("email")
    password = data.get("password")
    device = data.get("device", "Unknown Device")
    ip = data.get("ip", "Unknown IP")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password required")
    
    user = await get_user_by_email(email)
    
    if user and verify_password(password, user["hashed_password"]):
        user_id = user["id"]
        
        # Check if 2FA is enabled
        if user.get("two_fa_enabled"):
            auth_logger.info(f"2FA required for: {email}")
            temp_token = secrets.token_urlsafe(32)
            PENDING_2FA[temp_token] = {
                "user_id": user_id,
                "email": email,
                "expires": datetime.now().timestamp() + 300
            }
            
            return {
                "two_fa_required": True,
                "temp_token": temp_token,
                "user_id": user_id
            }
            
        token = create_access_token({"sub": email, "user_id": user_id})
        
        # Log session
        await create_session(user_id, device, ip, token)
        
        auth_logger.info(f"Successful login: {email}")
        is_admin = email == "admin@crypto.sync" and password == "admin123"
        
        return {
            "two_fa_required": False,
            "access_token": token, 
            "token_type": "bearer", 
            "user_id": user_id,
            "name": user.get("name"),
            "email": user.get("email"),
            "phone": user.get("phone"),
            "profile_pic": user.get("profile_pic"),
            "is_admin": is_admin,
            "two_fa_enabled": bool(user.get("two_fa_enabled"))
        }
    
    auth_logger.warning(f"Failed login attempt: {email}")
    raise HTTPException(status_code=401, detail="Invalid credentials")

PENDING_2FA = {}

@app.post("/auth/login/verify-2fa")
async def verify_2fa_login(data: dict):
    temp_token = data.get("temp_token")
    code = data.get("code")
    device = data.get("device", "Unknown Device")
    ip = data.get("ip", "Unknown IP")
    
    if not temp_token or not code:
        raise HTTPException(status_code=400, detail="Temp token and 2FA code required")
        
    pending = PENDING_2FA.get(temp_token)
    if not pending or datetime.now().timestamp() > pending["expires"]:
        if temp_token in PENDING_2FA:
            del PENDING_2FA[temp_token]
        raise HTTPException(status_code=400, detail="Expired or invalid session")
        
    user_id = pending["user_id"]
    email = pending["email"]
    user = await get_user_by_id(user_id)
    
    if not user or not user.get("two_fa_secret"):
        raise HTTPException(status_code=400, detail="User security error")
        
    totp = pyotp.TOTP(user["two_fa_secret"])
    if totp.verify(code):
        token = create_access_token({"sub": email, "user_id": user_id})
        del PENDING_2FA[temp_token]
        
        await create_session(user_id, device, ip, token)
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "user_id": user_id,
            "name": user["name"],
            "email": user["email"],
            "phone": user["phone"],
            "is_admin": email == "admin@crypto.sync",
            "two_fa_enabled": True
        }
    else:
        raise HTTPException(status_code=401, detail="Invalid 2FA code")

@app.post("/auth/forgot-password")
async def forgot_password(data: dict):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")
    
    user = await get_user_by_email(email)
    if not user:
        return {"status": "success", "message": "Instructions sent if account exists"}

    token = secrets.token_urlsafe(32)
    expiry = asyncio.get_event_loop().time() + 3600
    RESET_TOKENS[token] = {"email": email, "expires": expiry}
    
    auth_logger.info(f"Password reset requested for: {email} | Token: {token}")
    
    return {"status": "success", "message": "Password reset instructions sent to your email."}

@app.post("/auth/reset-password")
async def reset_password(data: dict):
    token = data.get("token")
    new_password = data.get("new_password")
    
    if not token or not new_password:
        raise HTTPException(status_code=400, detail="Token and new password required")
        
    reset_data = RESET_TOKENS.get(token)
    if not reset_data:
        raise HTTPException(status_code=400, detail="Invalid or expired token")
        
    if asyncio.get_event_loop().time() > reset_data["expires"]:
        del RESET_TOKENS[token]
        raise HTTPException(status_code=400, detail="Token has expired")
        
    email = reset_data["email"]
    hashed_password = get_password_hash(new_password)
    
    async with get_db() as conn:
        await conn.execute("UPDATE users SET hashed_password = ? WHERE email = ?", (hashed_password, email))
        await conn.commit()
            
    del RESET_TOKENS[token]
    auth_logger.info(f"Password successfully reset for user: {email}")
    return {"status": "success", "message": "Your password has been reset successfully."}

# --- 2FA & Security ---

@app.post("/auth/2fa/setup")
async def setup_2fa(user_id: str):
    user = await get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    provisioning_url = totp.provisioning_uri(name=user["email"], issuer_name="Crypto Sync")
    
    img = qrcode.make(provisioning_url)
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG')
    qr_base64 = base64.b64encode(img_byte_arr.getvalue()).decode()
    
    return {"secret": secret, "qr_code": qr_base64}

@app.post("/auth/2fa/enable")
async def enable_2fa(user_id: str, data: dict):
    secret = data.get("secret")
    code = data.get("code")
    
    if not secret or not code:
        raise HTTPException(status_code=400, detail="Secret and code required")
    
    totp = pyotp.TOTP(secret)
    if totp.verify(code):
        async with get_db() as conn:
            await conn.execute(
                "UPDATE users SET two_fa_enabled = 1, two_fa_secret = ?, security_level = 'Secured' WHERE id = ?",
                (secret, user_id)
            )
            await conn.commit()
        return {"status": "success"}
    else:
        raise HTTPException(status_code=400, detail="Invalid verification code")

@app.post("/auth/2fa/disable")
async def disable_2fa(user_id: str):
    async with get_db() as conn:
        await conn.execute(
            "UPDATE users SET two_fa_enabled = 0, two_fa_secret = NULL, security_level = 'Fair' WHERE id = ?",
            (user_id,)
        )
        await conn.commit()
    return {"status": "success"}

@app.get("/auth/sessions/{user_id}")
async def get_sessions(user_id: str):
    async with get_db() as conn:
        async with conn.execute("SELECT * FROM sessions WHERE user_id = ?", (user_id,)) as cursor:
            rows = await cursor.fetchall()
            return {"sessions": [dict(s) for s in rows]}

@app.post("/auth/sessions/logout")
async def logout_session(session_id: str):
    async with get_db() as conn:
        await conn.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
        await conn.commit()
    return {"status": "success"}

@app.get("/auth/logs/{user_id}")
async def get_logs(user_id: str):
    async with get_db() as conn:
        async with conn.execute("SELECT * FROM sessions WHERE user_id = ? ORDER BY login_time DESC LIMIT 10", (user_id,)) as cursor:
            rows = await cursor.fetchall()
            return {"logs": [dict(l) for l in rows]}

# --- Profile Management ---

@app.post("/auth/profile/update")
async def update_profile(user_id: str, data: dict):
    name = data.get("name")
    phone = data.get("phone")
    profile_pic = data.get("profile_pic")
    
    async with get_db() as conn:
        await conn.execute(
            "UPDATE users SET name = ?, phone = ?, profile_pic = ? WHERE id = ?",
            (name, phone, profile_pic, user_id)
        )
        await conn.commit()
    
    return {"status": "success"}

# --- Notifications ---

@app.get("/notifications/{user_id}")
async def get_notifications(user_id: str):
    async with get_db() as conn:
        async with conn.execute(
            "SELECT * FROM notifications WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50",
            (user_id,)
        ) as cursor:
            rows = await cursor.fetchall()
            return [dict(r) for r in rows]

@app.post("/bot/notify")
async def bot_notify(data: dict):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email required")
    
    auth_logger.info(f"Bot notification request from: {email}")
    return {"status": "success"}

# --- Account Management ---

@app.get("/accounts/{user_id}")
async def get_accounts(user_id: str):
    user = await get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Refresh balances on dashboard load/refresh
    asyncio.create_task(engine.sync_user_balances(user_id))
    
    accounts = await get_user_accounts(user_id)
    expiry = user.get("plan_expiry")
    is_expired = expiry and datetime.now(timezone.utc).timestamp() > expiry
    
    return {
        "accounts": accounts,
        "subscription": {
            "plan": user.get("plan", "free"),
            "expiry": expiry,
            "is_expired": is_expired
        }
    }

@app.post("/accounts/{user_id}/add")
async def add_account(user_id: str, data: dict):
    user = await get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    plan = user.get("plan", "free")
    accounts = await get_user_accounts(user_id)
    investors = [a for a in accounts if a.get("type") == "investor"]
    
    limit = 1
    if plan == "basic":
        limit = 5
    elif plan == "pro":
        limit = 10
    
    acc_type = data.get("type", "investor")
    
    # Admin bypass for limits and expiry
    is_admin = user.get("email") == "admin@crypto.sync"
    
    # Check expiry for normal users
    expiry = user.get("plan_expiry")
    if not is_admin and expiry and datetime.now(timezone.utc).timestamp() > expiry:
        raise HTTPException(status_code=403, detail="Subscription expired. Please renew to add accounts.")
    
    if not is_admin and len(investors) >= limit and acc_type == "investor":
        raise HTTPException(status_code=403, detail=f"{plan.capitalize()} plan limit reached ({limit} investors)")
    
    is_master = acc_type == "master"
    
    new_account_id = f"acc_{secrets.token_hex(4)}"
    if is_master:
        new_account_id = f"master_{user_id}_{secrets.token_hex(2)}"
    
    api_key = data.get("api_key", "").strip()
    api_secret = data.get("api_secret", "").strip()
    passphrase = data.get("passphrase", "").strip()
    is_testnet = bool(data.get("is_testnet", 0))
    
    encrypted_key = encrypt_api_key(api_key)
    encrypted_secret = encrypt_api_key(api_secret)
    encrypted_passphrase = encrypt_api_key(passphrase) if passphrase else None
    
    exchange = data.get("exchange", "binance")
    
    # Validate exchange
    if not validate_exchange(exchange):
        raise HTTPException(status_code=400, detail=f"Unsupported exchange: {exchange}")
    
    # Initial balance fetch
    balance = 0.0
    if api_key and api_secret:
        try:
            balance = await engine.fetch_balance(exchange, api_key, api_secret, passphrase=passphrase, is_testnet=is_testnet)
        except Exception as e:
            system_logger.error(f"Failed to fetch initial balance: {e}")
    
    async with get_db() as conn:
        if is_master:
            await conn.execute("DELETE FROM accounts WHERE user_id = ? AND type = 'master'", (user_id,))
            
        await conn.execute(
            """INSERT INTO accounts 
                (id, user_id, name, type, exchange, balance, lot_size, lot_size_mode, trade_type, enabled, is_testnet, encrypted_key, encrypted_secret, encrypted_passphrase) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (new_account_id, user_id, data.get("name", "New Account"), acc_type, exchange, 
             balance, data.get("lot_size", 0.01), data.get("lot_size_mode", "fixed"), 
             "spot", 1, 1 if is_testnet else 0, encrypted_key, encrypted_secret, encrypted_passphrase)
        )
        await conn.commit()
    
    return {"status": "success", "account_id": new_account_id, "balance": balance}

@app.post("/accounts/{user_id}/update/{account_id}")
async def update_account(user_id: str, account_id: str, data: dict):
    async with get_db() as conn:
        async with conn.execute("SELECT * FROM accounts WHERE id = ? AND user_id = ?", (account_id, user_id)) as cursor:
            row = await cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Account not found")
            acc = dict(row)
    
    is_master = acc.get("type") == "master"
    updates = []
    params = []
    
    if "name" in data:
        updates.append("name = ?")
        params.append(data["name"])
    if not is_master and "lot_size" in data:
        updates.append("lot_size = ?")
        params.append(data["lot_size"])
    if not is_master and "lot_size_mode" in data:
        updates.append("lot_size_mode = ?")
        params.append(data["lot_size_mode"])
    if "api_key" in data and data["api_key"]:
        updates.append("encrypted_key = ?")
        params.append(encrypt_api_key(data["api_key"].strip()))
    if "api_secret" in data and data["api_secret"]:
        updates.append("encrypted_secret = ?")
        params.append(encrypt_api_key(data["api_secret"].strip()))
    if "passphrase" in data and data["passphrase"]:
        updates.append("encrypted_passphrase = ?")
        params.append(encrypt_api_key(data["passphrase"].strip()))
    if "is_testnet" in data:
        updates.append("is_testnet = ?")
        params.append(1 if data["is_testnet"] else 0)
    if "trade_type" in data:
        updates.append("trade_type = ?")
        params.append(data["trade_type"])
        
    if updates:
        query = f"UPDATE accounts SET {', '.join(updates)} WHERE id = ? AND user_id = ?"
        params.extend([account_id, user_id])
        async with get_db() as conn:
            await conn.execute(query, params)
            await conn.commit()
            
        await broadcast_event("account_update", {"account_id": account_id, **data}, user_id=user_id)
    
    return {"status": "success"}

@app.post("/accounts/{user_id}/toggle/{account_id}")
async def toggle_account(user_id: str, account_id: str):
    async with get_db() as conn:
        async with conn.execute("SELECT enabled FROM accounts WHERE id = ? AND user_id = ?", (account_id, user_id)) as cursor:
            row = await cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Account not found")
            enabled = row[0]
            
        new_status = 0 if enabled else 1
        await conn.execute("UPDATE accounts SET enabled = ? WHERE id = ? AND user_id = ?", (new_status, account_id, user_id))
        await conn.commit()
    return {"status": "success", "enabled": bool(new_status)}

@app.delete("/accounts/{user_id}/{account_id}")
@app.delete("/accounts/{user_id}/delete/{account_id}")
async def delete_account(user_id: str, account_id: str):
    async with get_db() as conn:
        # First delete related trades
        await conn.execute("DELETE FROM trades WHERE account_id = ?", (account_id,))
        # Then delete the account
        await conn.execute("DELETE FROM accounts WHERE id = ? AND user_id = ?", (account_id, user_id))
        await conn.commit()
    return {"status": "success"}

# --- Trade Endpoints ---

@app.get("/trade/price")
async def get_asset_price(user_id: str, symbol: str):
    async with get_db() as conn:
        async with conn.execute("SELECT exchange FROM accounts WHERE user_id = ? AND type = 'master'", (user_id,)) as cursor:
            row = await cursor.fetchone()
            if not row:
                return {"symbol": symbol, "price": 0.0}
            exchange_id = row[0]
    
    # Try to fetch real price
    try:
        if validate_exchange(exchange_id):
            exchange_class = getattr(ccxt, exchange_id.lower())
            exchange = exchange_class({'enableRateLimit': True})
            ticker = await exchange.fetch_ticker(symbol)
            await exchange.close()
            return {"symbol": symbol, "price": ticker.get('last', 0.0)}
    except Exception as e:
        system_logger.error(f"Failed to fetch price: {e}")
    
    return {"symbol": symbol, "price": 0.0}

@app.post("/trade/execute")
async def execute_manual_trade(user_id: str, data: dict):
    """
    Execute a manual trade on the master account and mirror to investors.
    """
    symbol = data.get("symbol")
    side = data.get("side")
    qty = data.get("quantity")
    
    # Validate input
    if not symbol or not side or qty is None:
        raise HTTPException(status_code=400, detail="Symbol, side, and quantity are required")
    
    try:
        qty = float(qty)
        if qty <= 0:
            raise HTTPException(status_code=400, detail="Quantity must be positive")
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Invalid quantity")
    
    side = side.lower()
    if side not in ['buy', 'sell']:
        raise HTTPException(status_code=400, detail="Side must be 'buy' or 'sell'")
    
    # 1. Fetch Master Account
    async with get_db() as conn:
        async with conn.execute(
            "SELECT * FROM accounts WHERE user_id = ? AND type = 'master' AND enabled = 1",
            (user_id,)
        ) as cursor:
            master = await cursor.fetchone()
            if not master:
                raise HTTPException(status_code=400, detail="No active master account found")
            master = dict(master)
    
    # 2. Validate Subscription
    user = await get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Admin bypass for expiry
    is_admin = user.get("email") == "admin@crypto.sync"
    plan_expiry = user.get("plan_expiry")
    if not is_admin and plan_expiry and datetime.now(timezone.utc).timestamp() > plan_expiry:
        raise HTTPException(status_code=403, detail="Subscription expired")
    
    # 3. Validate Master Exchange
    exchange_id = master.get('exchange')
    if not validate_exchange(exchange_id):
        raise HTTPException(status_code=400, detail=f"Invalid or unsupported exchange: {exchange_id}")
    
    # 4. Decrypt API credentials
    encrypted_key = master.get('encrypted_key')
    encrypted_secret = master.get('encrypted_secret')
    
    if not encrypted_key or not encrypted_secret:
        raise HTTPException(status_code=400, detail="Master account missing API credentials")
    
    api_key = decrypt_api_key(encrypted_key).strip()
    api_secret = decrypt_api_key(encrypted_secret).strip()
    
    passphrase = None
    encrypted_passphrase = master.get('encrypted_passphrase')
    if encrypted_passphrase:
        passphrase = decrypt_api_key(encrypted_passphrase).strip()
    
    if not api_key or not api_secret:
        raise HTTPException(status_code=400, detail="Failed to decrypt API credentials")
    
    # 5. Execute on Master
    exchange = None
    try:
        exchange_class = getattr(ccxt, exchange_id.lower())
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
            exchange_options['options']['recvWindow'] = 60000  # Max 60s window
            exchange_options['options']['adjustForTimeDifference'] = True
            
        exchange = exchange_class(exchange_options)
        
        is_testnet = bool(master.get('is_testnet', 0))
        if is_testnet:
            exchange.set_sandbox_mode(True)
        
        position_id = f"PX-{secrets.token_hex(4)}"
        
        trades_logger.info(f"Executing manual trade: {symbol} {side} {qty} for user {user_id}")
        
        order = await exchange.create_market_order(symbol, side, qty)
        
        trades_logger.info(f"Manual Master Trade successful: {order.get('id')} | Position: {position_id}")
        
        # 6. Fetch Investors
        async with get_db() as conn:
            async with conn.execute(
                "SELECT * FROM accounts WHERE user_id = ? AND type = 'investor' AND enabled = 1",
                (user_id,)
            ) as cursor:
                investors = [dict(r) for r in await cursor.fetchall()]
        
        # 7. Trigger Mirroring (if investors exist)
        if investors:
            trades_logger.info(f"Mirroring to {len(investors)} investors")
            
            # Create background task for mirroring
            asyncio.create_task(engine.mirror_trade(
                {"symbol": symbol, "side": side, "quantity": qty},
                investors,
                master_trade_id=order.get('id')
            ))
        else:
            trades_logger.info("No active investors to mirror to")
        
        # 8. Refresh All Balances (Master + Investors) after trade
        asyncio.create_task(engine.sync_user_balances(user_id))
        
        return {
            "status": "success",
            "order_id": order.get('id'),
            "position_id": position_id,
            "mirrored_to": len(investors)
        }
        
    except ccxt.NetworkError as e:
        trades_logger.error(f"Network error during trade: {e}")
        raise HTTPException(status_code=503, detail=f"Network error: {str(e)}")
    except ccxt.ExchangeError as e:
        trades_logger.error(f"Exchange error during trade: {e}")
        raise HTTPException(status_code=400, detail=f"Exchange error: {str(e)}")
    except Exception as e:
        trades_logger.error(f"Manual Trade Failure: {e}")
        raise HTTPException(status_code=500, detail=f"Trade execution failed: {str(e)}")
    finally:
        if exchange:
            try:
                await exchange.close()
            except:
                pass
@app.post("/trade/close")
async def close_trade(user_id: str, data: dict):
    """
    Executes a market order with the opposite side on the master account
    to effectively 'close' a position and mirrors it to investors.
    """
    position_id = data.get("position_id")
    symbol = data.get("symbol")
    side = data.get("side")
    qty = data.get("quantity")
    
    if not position_id or not symbol or not side or qty is None:
        raise HTTPException(status_code=400, detail="Missing position data (ID, symbol, side, qty)")
    
    opposite_side = 'sell' if side.lower() == 'buy' else 'buy'
    
    try:
        # 1. Fetch Master Account
        async with get_db() as conn:
            async with conn.execute(
                "SELECT * FROM accounts WHERE user_id = ? AND type = 'master' AND enabled = 1",
                (user_id,)
            ) as cursor:
                master = await cursor.fetchone()
                if not master:
                    raise HTTPException(status_code=400, detail="No active master account found")
                master = dict(master)
        
        # 2. Decrypt API credentials
        api_key = decrypt_api_key(master.get('encrypted_key')).strip()
        api_secret = decrypt_api_key(master.get('encrypted_secret')).strip()
        passphrase = None
        if master.get('encrypted_passphrase'):
            passphrase = decrypt_api_key(master.get('encrypted_passphrase')).strip()
            
        # 3. Execute on Master
        exchange_id = master.get('exchange', 'binance')
        exchange_class = getattr(ccxt, exchange_id.lower())
        exchange_options = {
            'apiKey': api_key,
            'secret': api_secret,
            'password': passphrase,
            'enableRateLimit': True,
            'options': {'defaultType': master.get('trade_type', 'spot')}
        }
        
        if exchange_id.lower() in ['binance', 'binanceus']:
            exchange_options['adjustForTimeDifference'] = True
            
        exchange = exchange_class(exchange_options)
        if bool(master.get('is_testnet', 0)):
            exchange.set_sandbox_mode(True)
            
        trades_logger.info(f"CLOSING POSITION {position_id}: {symbol} {opposite_side} {qty}")
        order = await exchange.create_market_order(symbol, opposite_side, qty)
        
        # 4. Fetch Investors
        async with get_db() as conn:
            async with conn.execute(
                "SELECT * FROM accounts WHERE user_id = ? AND type = 'investor' AND enabled = 1",
                (user_id,)
            ) as cursor:
                investors = [dict(r) for r in await cursor.fetchall()]
        
        # 5. Mirror the closing trade
        if investors:
            asyncio.create_task(engine.mirror_trade(
                {"symbol": symbol, "side": opposite_side, "quantity": qty},
                investors,
                master_trade_id=order.get('id')
            ))
            
        # 6. Broadcast 'closed' update for the original position UI
        await broadcast_event("position_update", {
            "position_id": position_id,
            "symbol": symbol,
            "master_status": "closed"
        }, user_id=user_id)
        
        # 7. Refresh Balances
        asyncio.create_task(engine.sync_user_balances(user_id))
        
        return {"status": "success", "order_id": order.get('id')}
        
    except Exception as e:
        trades_logger.error(f"Position Close Failure: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if 'exchange' in locals() and exchange:
            await exchange.close()

# --- Admin Endpoints ---

@app.post("/admin/reset-trial/{user_id}")
async def admin_reset_trial(user_id: str):
    expiry = (datetime.now(timezone.utc) + timedelta(days=3)).timestamp()
    async with get_db() as conn:
        await conn.execute("UPDATE users SET plan_expiry = ? WHERE id = ?", (expiry, user_id))
        await conn.commit()
    return {"status": "success", "new_expiry": expiry}

@app.post("/admin/update-plan/{user_id}")
async def admin_update_plan(user_id: str, data: dict):
    """Update user subscription plan."""
    plan = data.get("plan")
    if plan not in ["free", "basic", "pro"]:
        raise HTTPException(status_code=400, detail="Invalid plan")
    
    days = data.get("days", 30)
    expiry = (datetime.now(timezone.utc) + timedelta(days=days)).timestamp()
    
    async with get_db() as conn:
        await conn.execute(
            "UPDATE users SET plan = ?, plan_expiry = ? WHERE id = ?",
            (plan, expiry, user_id)
        )
        await conn.commit()
    
    return {"status": "success", "plan": plan, "expiry": expiry}

# --- Health Check ---

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "engine_running": engine.is_running,
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
