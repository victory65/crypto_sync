import aiosqlite
import os
import asyncio
from contextlib import asynccontextmanager

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "crypto_sync.db")

@asynccontextmanager
async def get_db():
    """
    Context manager for database connections to prevent 'threads can only be started once' errors.
    """
    conn = await aiosqlite.connect(DB_PATH, timeout=20.0)
    try:
        conn.row_factory = aiosqlite.Row
        await conn.execute("PRAGMA journal_mode=WAL;")
        yield conn
    finally:
        await conn.close()

async def init_db():
    async with get_db() as conn:
        # Users Table
        await conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            hashed_password TEXT NOT NULL,
            name TEXT,
            phone TEXT,
            profile_pic TEXT,
            two_fa_enabled INTEGER DEFAULT 0,
            two_fa_secret TEXT,
            security_level TEXT DEFAULT 'Fair',
            plan TEXT DEFAULT 'free',
            plan_expiry REAL,
            created_at TEXT
        )
        ''')
        
        # Accounts Table
        await conn.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL, -- 'master' or 'investor'
            exchange TEXT NOT NULL,
            balance REAL DEFAULT 0.0,
            lot_size REAL DEFAULT 0.01,
            lot_size_mode TEXT DEFAULT 'fixed',
            trade_type TEXT DEFAULT 'spot',
            enabled INTEGER DEFAULT 1,
            encrypted_key TEXT,
            encrypted_secret TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        ''')
        
        # Trades Table (New for tracking positions and idempotency)
        await conn.execute('''
        CREATE TABLE IF NOT EXISTS trades (
            id TEXT PRIMARY KEY,
            master_trade_id TEXT, -- ID from master account (if mirrored)
            user_id TEXT NOT NULL,
            account_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            side TEXT NOT NULL,
            quantity REAL NOT NULL,
            price REAL,
            status TEXT DEFAULT 'pending', -- 'pending', 'filled', 'cancelled', 'failed'
            exchange_order_id TEXT,
            execution_hash TEXT UNIQUE, -- For idempotency
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (account_id) REFERENCES accounts (id)
        )
        ''')
        
        # Notifications Table
        await conn.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            type TEXT, 
            message TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            is_read INTEGER DEFAULT 0,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        ''')
        
        # Active Sessions Table
        await conn.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            device_name TEXT,
            ip_address TEXT,
            location TEXT,
            login_time TEXT NOT NULL,
            token TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        ''')
        
        await conn.commit()

async def get_admin_stats():
    """
    Returns statistics for the admin dashboard.
    """
    async with get_db() as conn:
        async with conn.execute("SELECT COUNT(*) FROM users") as cursor:
            total_users = (await cursor.fetchone())[0]
        
        async with conn.execute("SELECT COUNT(*) FROM users WHERE plan = 'basic'") as cursor:
            basic_subscribers = (await cursor.fetchone())[0]
            
        async with conn.execute("SELECT COUNT(*) FROM users WHERE plan = 'pro'") as cursor:
            pro_subscribers = (await cursor.fetchone())[0]
            
    return {
        "total_users": total_users,
        "basic_subscribers": basic_subscribers,
        "pro_subscribers": pro_subscribers
    }

if __name__ == "__main__":
    asyncio.run(init_db())
    print("Database initialized successfully.")
