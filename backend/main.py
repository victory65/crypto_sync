from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import asyncio
import secrets
import uvicorn
from datetime import datetime, timedelta, timezone

from core.security import decode_access_token, verify_password, create_access_token, get_password_hash, encrypt_api_key, decrypt_api_key
from core.websocket import manager, broadcast_event
from core.logger import system_logger, auth_logger
from engine.trade_engine import engine
from core.database import get_db_connection, init_db
import pyotp
import contextlib
import qrcode
import io
import base64

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
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

# --- WebSocket Endpoint ---

@app.websocket("/ws/user/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str, token: Optional[str] = None):
    # Authenticate
    if not token or not decode_access_token(token):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        auth_logger.warning(f"WebSocket connection rejected for user {user_id}: Invalid Token")
        return

    await manager.connect(user_id, websocket)
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

# --- REST Endpoints (Auth & Simulation) ---

# --- Database Helpers ---

def get_user_by_email(email: str):
    conn = get_db_connection()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    conn.close()
    return dict(user) if user else None

def get_user_by_id(user_id: str):
    conn = get_db_connection()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    return dict(user) if user else None

def get_user_accounts(user_id: str):
    conn = get_db_connection()
    rows = conn.execute("SELECT * FROM accounts WHERE user_id = ?", (user_id,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

def log_login_attempt(user_id: str, ip: str, device: str, status: str):
    conn = get_db_connection()
    conn.execute(
        "INSERT INTO login_history (user_id, timestamp, ip_address, device_name, status) VALUES (?, ?, ?, ?, ?)",
        (user_id, datetime.now().isoformat(), ip, device, status)
    )
    conn.commit()
    conn.close()

def create_session(user_id: str, device: str, ip: str, token: str):
    session_id = f"sess_{secrets.token_hex(8)}"
    conn = get_db_connection()
    conn.execute(
        "INSERT INTO sessions (id, user_id, device_name, ip_address, login_time, token) VALUES (?, ?, ?, ?, ?, ?)",
        (session_id, user_id, device, ip, datetime.now().isoformat(), token)
    )
    conn.commit()
    conn.close()
    return session_id

# Remove Mock storage
# USERS_DB = {}

@app.post("/auth/signup")
async def signup(data: dict):
    email = data.get("email")
    password = data.get("password")
    name = data.get("name", "New User")
    phone = data.get("phone")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password required")
    
    is_admin = email == "admin@crypto.sync" and password == "admin123"
        
    # Check if email exists
    if get_user_by_email(email):
        raise HTTPException(status_code=400, detail="Email already registered")
        
    # Create user
    user_id = f"user_{secrets.token_hex(4)}"
    hashed_password = get_password_hash(password)
    expiry = (datetime.now(timezone.utc) + timedelta(days=7)).timestamp()
    
    conn = get_db_connection()
    conn.execute(
        "INSERT INTO users (id, email, hashed_password, name, phone, plan, plan_expiry, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (user_id, email, hashed_password, name, phone, "free", expiry, datetime.now().isoformat())
    )
    conn.commit()
    conn.close()
    
    auth_logger.info(f"New user registered: {email} (ID: {user_id})")
    token = create_access_token({"sub": email, "user_id": user_id})
    
    # Log session
    create_session(user_id, "Mobile Device (Sign up)", "Unknown", token)
    log_login_attempt(user_id, "Unknown", "Mobile Device", "success")

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

RESET_TOKENS = {} # Stores {token: {"email": email, "expires": timestamp}}

@app.post("/auth/login")
async def login(data: dict):
    email = data.get("email")
    password = data.get("password")
    device = data.get("device", "Unknown Device")
    ip = data.get("ip", "Unknown IP")
    
    user = get_user_by_email(email)
    
    if user and verify_password(password, user["hashed_password"]):
        user_id = user["id"]
        
        # Check if 2FA is enabled
        if user["two_fa_enabled"]:
            auth_logger.info(f"2FA required for: {email}")
            # Generate a temporary token for verification
            temp_token = secrets.token_urlsafe(32)
            # Store temp token with user_id and email (expires in 5 mins)
            # In a real app, use Redis or DB. Here we use dict for simplicity.
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
        
        # Log session and history
        create_session(user_id, device, ip, token)
        log_login_attempt(user_id, ip, device, "success")
        
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
            "two_fa_enabled": bool(user["two_fa_enabled"])
        }
    
    if user:
        log_login_attempt(user["id"], ip, device, "failed")
        
    auth_logger.warning(f"Failed login attempt: {email}")
    raise HTTPException(status_code=401, detail="Invalid credentials")

PENDING_2FA = {} # Stores {temp_token: {"user_id": uid, "email": email, "expires": ts}}

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
        if temp_token in PENDING_2FA: del PENDING_2FA[temp_token]
        raise HTTPException(status_code=400, detail="Expired or invalid session")
        
    user_id = pending["user_id"]
    email = pending["email"]
    user = get_user_by_id(user_id)
    
    if not user or not user["two_fa_secret"]:
        raise HTTPException(status_code=400, detail="User security error")
        
    totp = pyotp.TOTP(user["two_fa_secret"])
    if totp.verify(code):
        # Verification successful
        token = create_access_token({"sub": email, "user_id": user_id})
        del PENDING_2FA[temp_token]
        
        create_session(user_id, device, ip, token)
        log_login_attempt(user_id, ip, device, "success")
        
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
        log_login_attempt(user_id, ip, device, "failed_2fa")
        raise HTTPException(status_code=401, detail="Invalid 2FA code")

@app.post("/auth/forgot-password")
async def forgot_password(data: dict):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")
    
    user = get_user_by_email(email)
    if not user:
        return {"status": "success", "message": "Instructions sent if account exists"}

    token = secrets.token_urlsafe(32)
    # Simulation: Store in RESET_TOKENS (could be in DB, but this works for now)
    expiry = asyncio.get_event_loop().time() + 3600
    RESET_TOKENS[token] = {"email": email, "expires": expiry}
    
    auth_logger.info(f"\n--- [OUTGOING EMAIL SIMULATION] ---\nTo: {email}\nSubject: Password Reset Request\nContent: token: {token}\n----------------------------------")
    
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
    
    conn = get_db_connection()
    conn.execute("UPDATE users SET hashed_password = ? WHERE email = ?", (hashed_password, email))
    conn.commit()
    conn.close()
            
    del RESET_TOKENS[token]
    auth_logger.info(f"Password successfully reset for user: {email}")
    return {"status": "success", "message": "Your password has been reset successfully."}

# --- 2FA & Security ---

@app.post("/auth/2fa/setup")
async def setup_2fa(user_id: str):
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    provisioning_url = totp.provisioning_uri(name=user["email"], issuer_name="Crypto Sync")
    
    # Generate QR Code
    img = qrcode.make(provisioning_url)
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG')
    qr_base64 = base64.b64encode(img_byte_arr.getvalue()).decode()
    
    return {"secret": secret, "qr_code": qr_base64}

@app.post("/auth/2fa/enable")
async def enable_2fa(user_id: str, data: dict):
    secret = data.get("secret")
    code = data.get("code")
    
    totp = pyotp.TOTP(secret)
    if totp.verify(code):
        conn = get_db_connection()
        conn.execute(
            "UPDATE users SET two_fa_enabled = 1, two_fa_secret = ?, security_level = 'Secured' WHERE id = ?",
            (secret, user_id)
        )
        conn.commit()
        conn.close()
        return {"status": "success"}
    else:
        raise HTTPException(status_code=400, detail="Invalid verification code")
    

@app.post("/auth/2fa/disable")
async def disable_2fa(user_id: str):
    conn = get_db_connection()
    conn.execute(
        "UPDATE users SET two_fa_enabled = 0, two_fa_secret = NULL, security_level = 'Fair' WHERE id = ?",
        (user_id,)
    )
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/auth/sessions/{user_id}")
async def get_sessions(user_id: str):
    conn = get_db_connection()
    sessions = conn.execute("SELECT * FROM sessions WHERE user_id = ?", (user_id,)).fetchall()
    conn.close()
    return {"sessions": [dict(s) for s in sessions]}

@app.post("/auth/sessions/logout")
async def logout_session(session_id: str):
    conn = get_db_connection()
    conn.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/auth/logs/{user_id}")
async def get_logs(user_id: str):
    conn = get_db_connection()
    logs = conn.execute("SELECT * FROM login_history WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50", (user_id,)).fetchall()
    conn.close()
    return {"logs": [dict(l) for l in logs]}

# --- Profile Management ---

@app.post("/auth/profile/update")
async def update_profile(user_id: str, data: dict):
    name = data.get("name")
    phone = data.get("phone")
    email = data.get("email")
    profile_pic = data.get("profile_pic")
    
    conn = get_db_connection()
    if name: conn.execute("UPDATE users SET name = ? WHERE id = ?", (name, user_id))
    if phone: conn.execute("UPDATE users SET phone = ? WHERE id = ?", (phone, user_id))
    if profile_pic: conn.execute("UPDATE users SET profile_pic = ? WHERE id = ?", (profile_pic, user_id))
    if email:
        # Check if email is available
        existing = conn.execute("SELECT id FROM users WHERE email = ? AND id != ?", (email, user_id)).fetchone()
        if existing:
            conn.close()
            raise HTTPException(status_code=400, detail="Email already in use")
        conn.execute("UPDATE users SET email = ? WHERE id = ?", (email, user_id))
    
    conn.commit()
    conn.close()
    return {"status": "success"}

# --- Notifications ---

@app.get("/notifications/{user_id}")
async def get_notifications(user_id: str):
    conn = get_db_connection()
    rows = conn.execute("SELECT * FROM notifications WHERE user_id = ? ORDER BY timestamp DESC", (user_id,)).fetchall()
    conn.close()
    return {"notifications": [dict(r) for r in rows]}

@app.post("/bot/notify")
async def bot_notify(data: dict):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email required")
    
    conn = get_db_connection()
    conn.execute("INSERT INTO bot_waitlist (email, timestamp) VALUES (?, ?)", (email, datetime.now().isoformat()))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/accounts/{user_id}")
async def get_accounts(user_id: str):
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    accounts = get_user_accounts(user_id)
    expiry = user["plan_expiry"]
    is_expired = datetime.now(timezone.utc).timestamp() > expiry
    
    return {
        "accounts": accounts,
        "subscription": {
            "plan": user["plan"],
            "expiry": expiry,
            "is_expired": is_expired
        }
    }

@app.post("/accounts/{user_id}/add")
async def add_account(user_id: str, data: dict):
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    plan = user["plan"]
    accounts = get_user_accounts(user_id)
    investors = [a for a in accounts if a["type"] == "investor"]
    
    limit = 1
    if plan == "basic": limit = 5
    elif plan == "pro": limit = 100
    
    if len(investors) >= limit and plan == "free":
        raise HTTPException(status_code=403, detail="Free plan limit reached (1 investor)")
    
    acc_type = data.get("type", "investor")
    is_master = acc_type == "master"
    
    new_account = {
        "id": f"master_{user_id}_{secrets.token_hex(2)}" if is_master else f"acc_{secrets.token_hex(4)}",
        "user_id": user_id,
        "name": data.get("name", "New Account"),
        "type": acc_type,
        "exchange": data.get("exchange", "binance"),
        "balance": 0.0,
        "lot_size": 0.0 if is_master else data.get("lot_size", 0.01),
        "lot_size_mode": "fixed" if is_master else data.get("lot_size_mode", "fixed"),
        "trade_type": data.get("trade_type", "spot"), # 'spot', 'futures', 'both'
        "enabled": 1,
        "encrypted_key": encrypt_api_key(data.get("api_key", "mock_key")),
        "encrypted_secret": encrypt_api_key(data.get("api_secret", "mock_secret"))
    }
    
    # Fetch initial balance
    api_key = data.get("api_key", "mock_key")
    api_secret = data.get("api_secret", "mock_secret")
    new_account["balance"] = await engine.fetch_balance(new_account["exchange"], api_key, api_secret)
    
    conn = get_db_connection()
    if is_master:
        # Replace existing master
        conn.execute("DELETE FROM accounts WHERE user_id = ? AND type = 'master'", (user_id,))
        
    conn.execute(
        "INSERT INTO accounts (id, user_id, name, type, exchange, balance, lot_size, lot_size_mode, trade_type, enabled, encrypted_key, encrypted_secret) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (new_account["id"], user_id, new_account["name"], new_account["type"], new_account["exchange"], new_account["balance"], new_account["lot_size"], new_account["lot_size_mode"], new_account["trade_type"], new_account["enabled"], new_account["encrypted_key"], new_account["encrypted_secret"])
    )
    conn.commit()
    conn.close()
    
    return {"status": "success", "account": new_account}

@app.post("/accounts/{user_id}/update/{account_id}")
async def update_account(user_id: str, account_id: str, data: dict):
    conn = get_db_connection()
    acc = conn.execute("SELECT * FROM accounts WHERE id = ? AND user_id = ?", (account_id, user_id)).fetchone()
    if not acc:
        conn.close()
        raise HTTPException(status_code=404, detail="Account not found")
    
    acc = dict(acc)
    is_master = acc["type"] == "master"
    
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
    if "trade_type" in data:
        updates.append("trade_type = ?")
        params.append(data["trade_type"])
    if "api_key" in data and data["api_key"]:
        updates.append("encrypted_key = ?")
        params.append(encrypt_api_key(data["api_key"]))
    if "api_secret" in data and data["api_secret"]:
        updates.append("encrypted_secret = ?")
        params.append(encrypt_api_key(data["api_secret"]))
        
    if updates:
        query = f"UPDATE accounts SET {', '.join(updates)} WHERE id = ? AND user_id = ?"
        params.extend([account_id, user_id])
        conn.execute(query, params)
        conn.commit()
        
        # Broadcast the update
        await broadcast_event("account_update", {
            "account_id": account_id,
            **data
        }, user_id=user_id)
    
    conn.close()
    return {"status": "success"}

@app.post("/accounts/{user_id}/toggle/{account_id}")
async def toggle_account(user_id: str, account_id: str):
    conn = get_db_connection()
    acc = conn.execute("SELECT enabled FROM accounts WHERE id = ? AND user_id = ?", (account_id, user_id)).fetchone()
    if not acc:
        conn.close()
        raise HTTPException(status_code=404, detail="Account not found")
    
    new_status = 0 if acc["enabled"] else 1
    conn.execute("UPDATE accounts SET enabled = ? WHERE id = ? AND user_id = ?", (new_status, account_id, user_id))
    conn.commit()
    conn.close()
    return {"status": "success", "enabled": bool(new_status)}

@app.delete("/accounts/{user_id}/{account_id}")
async def delete_account(user_id: str, account_id: str):
    conn = get_db_connection()
    conn.execute("DELETE FROM accounts WHERE id = ? AND user_id = ?", (account_id, user_id))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/trade/price")
async def get_asset_price(user_id: str, symbol: str):
    # In production, this would fetch from a ticker. 
    # For now, we return 0.0 instead of a 'random' fake balance if no real source is available.
    return {"symbol": symbol, "price": 0.0}

@app.get("/health")
async def health_check():
    await broadcast_event("sync_status_update", {"status": "inactive", "message": "Engine Stopped"})
    system_logger.info("Trade Engine stopped.")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
