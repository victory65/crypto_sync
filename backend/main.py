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

app = FastAPI(title="Crypto Sync Production Backend")

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

# Mock storage for demo purposes
USERS_DB = {}

@app.post("/auth/signup")
async def signup(data: dict):
    email = data.get("email")
    password = data.get("password")
    name = data.get("name", "New User")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password required")
    
    is_admin = email == "admin@crypto.sync" and password == "admin123"
        
    # Check if email exists
    if any(u["email"] == email for u in USERS_DB.values()):
        raise HTTPException(status_code=400, detail="Email already registered")
        
    # Create user
    user_id = f"user_{secrets.token_hex(4)}"
    USERS_DB[user_id] = {
        "email": email,
        "name": name,
        "hashed_password": get_password_hash(password),
        "subscription": {
            "plan": "free",
            "expiry": (datetime.now(timezone.utc) + timedelta(days=7)).timestamp(),
            "is_active": True
        },
        "accounts": []
    }
    
    auth_logger.info(f"New user registered: {email} (ID: {user_id})")
    token = create_access_token({"sub": email, "user_id": user_id})
    return {
        "access_token": token, 
        "token_type": "bearer", 
        "user_id": user_id,
        "name": name,
        "email": email,
        "is_admin": is_admin
    }

RESET_TOKENS = {} # Stores {token: {"email": email, "expires": timestamp}}

@app.post("/auth/login")
async def login(data: dict):
    email = data.get("email")
    password = data.get("password")
    
    # Find user in mock DB
    user_id = None
    for uid, udata in USERS_DB.items():
        if udata["email"] == email:
            if verify_password(password, udata["hashed_password"]):
                user_id = uid
                break
    
    if user_id:
        user_data = USERS_DB[user_id]
        token = create_access_token({"sub": email, "user_id": user_id})
        auth_logger.info(f"Successful login: {email}")
        is_admin = email == "admin@crypto.sync" and password == "admin123"
        return {
            "access_token": token, 
            "token_type": "bearer", 
            "user_id": user_id,
            "name": user_data["name"],
            "email": user_data["email"],
            "is_admin": is_admin
        }
    
    auth_logger.warning(f"Failed login attempt: {email}")
    raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/auth/forgot-password")
async def forgot_password(data: dict):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")
    
    # Check if user exists
    user_exists = any(u["email"] == email for u in USERS_DB.values())
    if not user_exists:
        # In production, we return 200 anyway to prevent user enumeration
        return {"status": "success", "message": "Instructions sent if account exists"}

    # Generate secure reset token
    token = secrets.token_urlsafe(32)
    expiry = asyncio.get_event_loop().time() + 3600 # 1 hour
    RESET_TOKENS[token] = {"email": email, "expires": expiry}
    
    # Simulation: Log the "Email" content
    reset_link = f"http://app.cryptosync.io/reset-password?token={token}"
    auth_logger.info(f"\n--- [OUTGOING EMAIL SIMULATION] ---\nTo: {email}\nSubject: Password Reset Request\nContent: click here to reset: {reset_link}\n----------------------------------")
    
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
        
    # Update password
    email = reset_data["email"]
    for uid, udata in USERS_DB.items():
        if udata["email"] == email:
            udata["hashed_password"] = get_password_hash(new_password)
            break
            
    # Cleanup token
    del RESET_TOKENS[token]
    auth_logger.info(f"Password successfully reset for user: {email}")
    return {"status": "success", "message": "Your password has been reset successfully."}

@app.get("/accounts/{user_id}")
async def get_accounts(user_id: str):
    if user_id not in USERS_DB:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check subscription expiry
    user = USERS_DB[user_id]
    expiry = user["subscription"]["expiry"]
    is_expired = datetime.now(timezone.utc).timestamp() > expiry
    
    return {
        "accounts": user["accounts"],
        "subscription": {
            **user["subscription"],
            "is_expired": is_expired
        }
    }

@app.post("/accounts/{user_id}/add")
async def add_account(user_id: str, data: dict):
    user = USERS_DB.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    plan = user["subscription"]["plan"]
    slaves = [a for a in user["accounts"] if a["type"] == "slave"]
    
    limit = 1
    if plan == "basic": limit = 5
    elif plan == "pro": limit = 100 # Effectively unlimited, but pricing changes after 10
    
    if len(slaves) >= limit and plan == "free":
        raise HTTPException(status_code=403, detail="Free plan limit reached (1 slave)")
    
    if len(slaves) >= limit and plan == "basic":
        raise HTTPException(status_code=403, detail="Basic plan limit reached (5 slaves)")

    new_account = {
        "id": f"acc_{secrets.token_hex(3)}",
        "name": data.get("name", "New Account"),
        "type": data.get("type", "slave"), # Allow adding master if needed
        "exchange": data.get("exchange", "binance"),
        "balance": 0.0,
        "lot_size": data.get("lot_size", 0.01),
        "lot_size_mode": data.get("lot_size_mode", "fixed"),
        "trade_type": data.get("trade_type", "spot"),
        "enabled": True,
        "encrypted_key": encrypt_api_key(data.get("api_key", "mock_key")),
        "encrypted_secret": encrypt_api_key(data.get("api_secret", "mock_secret"))
    }
    
    # Fetch initial balance from exchange
    api_key = data.get("api_key", "mock_key")
    api_secret = data.get("api_secret", "mock_secret")
    new_account["balance"] = await engine.fetch_balance(new_account["exchange"], api_key, api_secret)
    
    # If adding master, remove old master
    if new_account["type"] == "master":
        user["accounts"] = [a for a in user["accounts"] if a["type"] != "master"]
        new_account["id"] = "master"

    user["accounts"].append(new_account)
    return {"status": "success", "account": new_account}

@app.post("/accounts/{user_id}/update/{account_id}")
async def update_account(user_id: str, account_id: str, data: dict):
    user = USERS_DB.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    for acc in user["accounts"]:
        if acc["id"] == account_id:
            if "name" in data: acc["name"] = data["name"]
            if "lot_size" in data: acc["lot_size"] = data["lot_size"]
            if "lot_size_mode" in data: acc["lot_size_mode"] = data["lot_size_mode"]
            if "trade_type" in data: acc["trade_type"] = data["trade_type"]
            if "api_key" in data and data["api_key"]: acc["encrypted_key"] = encrypt_api_key(data["api_key"])
            if "api_secret" in data and data["api_secret"]: acc["encrypted_secret"] = encrypt_api_key(data["api_secret"])
            
            # Broadcast the update
            await broadcast_event("account_update", {
                "account_id": account_id,
                **data
            }, user_id=user_id)
            
            return {"status": "success", "account": acc}
            
    raise HTTPException(status_code=404, detail="Account not found")

@app.post("/accounts/{user_id}/toggle/{account_id}")
async def toggle_account(user_id: str, account_id: str):
    user = USERS_DB.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    for acc in user["accounts"]:
        if acc["id"] == account_id:
            acc["enabled"] = not acc.get("enabled", False)
            return {"status": "success", "enabled": acc["enabled"]}
            
    raise HTTPException(status_code=404, detail="Account not found")

@app.post("/accounts/{user_id}/lot_size/{account_id}")
async def update_lot_size(user_id: str, account_id: str, lot_size: float):
    user = USERS_DB.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    for acc in user["accounts"]:
        if acc["id"] == account_id:
            acc["lot_size"] = lot_size
            # Broadcast the update
            await broadcast_event("account_update", {
                "account_id": account_id,
                "lot_size": lot_size
            }, user_id=user_id)
            return {"status": "success", "lot_size": lot_size}
            
    raise HTTPException(status_code=404, detail="Account not found")

@app.post("/simulate/balance_change")
async def simulate_balance(user_id: str):
    """
    Simulates a random balance change and broadcasts it via WebSocket.
    """
    import random
    user = USERS_DB.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Update master
    master = [a for a in user["accounts"] if a["type"] == "master"][0]
    master["balance"] += random.uniform(-100, 100)
    
    # Update one random slave
    slaves = [a for a in user["accounts"] if a["type"] == "slave"]
    target_slave = random.choice(slaves)
    target_slave["balance"] += random.uniform(-50, 50)
    
    # Calculate totals
    slaves_total = sum(s["balance"] for s in slaves)
    
    # Broadcast update
    payload = {
        "master": master["balance"],
        "slaves_total": slaves_total,
        target_slave["id"]: target_slave["balance"]
    }
    
    await broadcast_event("balance_update", payload, user_id=user_id)
    return {"status": "Balance update broadcasted", "new_balances": payload}

@app.post("/simulate/trade")
async def simulate_trade(user_id: str):
    master_trade = {
        "id": "T-" + str(int(asyncio.get_event_loop().time())),
        "symbol": "ETH/USDT",
        "side": "buy",
        "amount": 1.5,
        "price": 3450.0
    }
    
    user = USERS_DB.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check expiry
    if datetime.now(timezone.utc).timestamp() > user["subscription"]["expiry"]:
        await broadcast_event("execution_log", {
            "message": "Sync paused – subscription expired.",
            "type": "error"
        }, user_id=user_id)
        return {"status": "error", "message": "Subscription expired"}

    slaves = [a for a in user["accounts"] if a["type"] == "slave" and a.get("enabled")]
    
    if not engine.is_running:
        await engine.start()
        
    asyncio.create_task(engine.mirror_trade(master_trade, slaves))
    return {"status": "Trade mirroring sequence initiated", "position_id": master_trade["id"]}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "engine": "running" if engine.is_running else "stopped"}

async def balance_refresh_loop():
    """
    Periodically refreshes balances for all accounts of all users.
    """
    while True:
        try:
            for user_id, user_data in USERS_DB.items():
                balances = {}
                slaves_total = 0.0
                for acc in user_data["accounts"]:
                    # In production, we'd use saved keys. For demo, we just simulate.
                    new_bal = await engine.fetch_balance(acc["exchange"], "key", "secret")
                    acc["balance"] = new_bal
                    balances[acc["id"]] = new_bal
                    if acc["type"] == "slave":
                        slaves_total += new_bal
                
                # Add summary balances for Dashboard consumption
                balances["slaves_total"] = slaves_total
                
                # Broadcast update if user is connected
                if balances:
                    await broadcast_event("balance_update", balances, user_id=user_id)
            
            await asyncio.sleep(60) # Refresh every minute
        except Exception as e:
            system_logger.error(f"Error in balance refresh loop: {e}")
            await asyncio.sleep(10)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(balance_refresh_loop())

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
