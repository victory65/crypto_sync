import aiosqlite
import os
import asyncio
from contextlib import asynccontextmanager
from typing import Optional

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "crypto_sync.db")

# Connection pool settings
MAX_CONNECTIONS = 10
connection_pool: Optional[asyncio.Queue] = None
pool_initialized = False

async def init_connection_pool():
    """Initialize the connection pool."""
    global connection_pool, pool_initialized
    if pool_initialized:
        return
    
    connection_pool = asyncio.Queue(maxsize=MAX_CONNECTIONS)
    
    # Pre-create connections
    for _ in range(MAX_CONNECTIONS):
        conn = await aiosqlite.connect(DB_PATH, timeout=20.0)
        conn.row_factory = aiosqlite.Row
        await conn.execute("PRAGMA journal_mode=WAL;")
        await conn.execute("PRAGMA foreign_keys=ON;")
        await connection_pool.put(conn)
    
    pool_initialized = True
    print(f"Database connection pool initialized with {MAX_CONNECTIONS} connections")

async def close_connection_pool():
    """Close all connections in the pool."""
    global connection_pool, pool_initialized
    if not pool_initialized or not connection_pool:
        return
    
    while not connection_pool.empty():
        try:
            conn = connection_pool.get_nowait()
            await conn.close()
        except:
            pass
    
    pool_initialized = False
    print("Database connection pool closed")

@asynccontextmanager
async def get_db():
    """
    Context manager for database connections.
    Uses connection pooling if available, otherwise creates a new connection.
    """
    conn = None
    from_pool = False
    
    try:
        # Try to get from pool
        if pool_initialized and connection_pool:
            try:
                conn = await asyncio.wait_for(connection_pool.get(), timeout=5.0)
                from_pool = True
            except asyncio.TimeoutError:
                # Pool exhausted, create new connection
                conn = await aiosqlite.connect(DB_PATH, timeout=20.0)
                conn.row_factory = aiosqlite.Row
                await conn.execute("PRAGMA journal_mode=WAL;")
                await conn.execute("PRAGMA foreign_keys=ON;")
        else:
            # No pool, create new connection
            conn = await aiosqlite.connect(DB_PATH, timeout=20.0)
            conn.row_factory = aiosqlite.Row
            await conn.execute("PRAGMA journal_mode=WAL;")
            await conn.execute("PRAGMA foreign_keys=ON;")
        
        yield conn
        
    except Exception as e:
        if conn:
            try:
                await conn.rollback()
            except:
                pass
        raise e
    finally:
        if conn:
            if from_pool and connection_pool:
                # Return to pool
                try:
                    connection_pool.put_nowait(conn)
                except:
                    await conn.close()
            else:
                # Close standalone connection
                await conn.close()

async def init_db():
    """Initialize the database with all required tables."""
    # Initialize connection pool
    await init_connection_pool()
    
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
            type TEXT NOT NULL,
            exchange TEXT NOT NULL,
            balance REAL DEFAULT 0.0,
            lot_size REAL DEFAULT 0.01,
            lot_size_mode TEXT DEFAULT 'fixed',
            trade_type TEXT DEFAULT 'spot',
            enabled INTEGER DEFAULT 1,
            is_testnet INTEGER DEFAULT 0,
            encrypted_key TEXT,
            encrypted_secret TEXT,
            encrypted_passphrase TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
        ''')
        
        # Trades Table
        await conn.execute('''
        CREATE TABLE IF NOT EXISTS trades (
            id TEXT PRIMARY KEY,
            master_trade_id TEXT,
            user_id TEXT NOT NULL,
            account_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            side TEXT NOT NULL,
            quantity REAL NOT NULL,
            price REAL,
            status TEXT DEFAULT 'pending',
            exchange_order_id TEXT,
            execution_hash TEXT UNIQUE,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
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
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
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
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
        ''')
        
        # Create indexes for better performance
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id)')
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_accounts_type ON accounts(type)')
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_trades_user_id ON trades(user_id)')
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_trades_account_id ON trades(account_id)')
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_trades_master_trade_id ON trades(master_trade_id)')
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id)')
        await conn.execute('CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id)')
        
        # Migration: Add encrypted_passphrase if it doesn't exist
        try:
            await conn.execute("ALTER TABLE accounts ADD COLUMN encrypted_passphrase TEXT")
            print("Migration: Added encrypted_passphrase column to accounts table")
        except:
            pass # Already exists
            
        # Migration: Add is_testnet if it doesn't exist
        try:
            await conn.execute("ALTER TABLE accounts ADD COLUMN is_testnet INTEGER DEFAULT 0")
            print("Migration: Added is_testnet column to accounts table")
        except:
            pass # Already exists
            
        await conn.commit()
        
    print("Database initialized successfully.")

async def get_admin_stats():
    """Returns statistics for the admin dashboard."""
    async with get_db() as conn:
        async with conn.execute("SELECT COUNT(*) FROM users") as cursor:
            total_users = (await cursor.fetchone())[0]
        
        async with conn.execute("SELECT COUNT(*) FROM users WHERE plan = 'basic'") as cursor:
            basic_subscribers = (await cursor.fetchone())[0]
            
        async with conn.execute("SELECT COUNT(*) FROM users WHERE plan = 'pro'") as cursor:
            pro_subscribers = (await cursor.fetchone())[0]
        
        async with conn.execute("SELECT COUNT(*) FROM accounts WHERE type = 'master'") as cursor:
            master_accounts = (await cursor.fetchone())[0]
            
        async with conn.execute("SELECT COUNT(*) FROM accounts WHERE type = 'investor'") as cursor:
            investor_accounts = (await cursor.fetchone())[0]
            
    return {
        "total_users": total_users,
        "basic_subscribers": basic_subscribers,
        "pro_subscribers": pro_subscribers,
        "master_accounts": master_accounts,
        "investor_accounts": investor_accounts
    }

if __name__ == "__main__":
    asyncio.run(init_db())
