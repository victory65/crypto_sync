import sqlite3
import os
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "crypto_sync.db")

def get_db_connection():
    conn = sqlite3.connect(DB_PATH, timeout=20.0)
    conn.row_factory = sqlite3.Row
    # Enable WAL mode for better concurrency
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Users Table
    cursor.execute('''
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
    
    # Migration: Add profile_pic if missing (for existing databases)
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN profile_pic TEXT")
    except sqlite3.OperationalError:
        pass # Already exists
    
    # Accounts Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'master' or 'investor'
        exchange TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        lot_size REAL DEFAULT 0.01,
        lot_size_mode TEXT DEFAULT 'fixed',
        trade_type TEXT DEFAULT 'spot', -- 'spot', 'futures', or 'both'
        enabled INTEGER DEFAULT 1,
        encrypted_key TEXT,
        encrypted_secret TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
    )
    ''')
    
    # Notifications Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        type TEXT, -- 'app_update', 'trade_alert'
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
    )
    ''')
    
    # Active Sessions Table
    cursor.execute('''
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
    
    # Login History Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS login_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        ip_address TEXT,
        device_name TEXT,
        status TEXT, -- 'success', 'failed'
        FOREIGN KEY (user_id) REFERENCES users (id)
    )
    ''')
    
    # Bot Waitlist Table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS bot_waitlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        timestamp TEXT NOT NULL
    )
    ''')

    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully.")

