#!/usr/bin/env python3
"""
Crypto Sync Backend Startup Script
==================================
This script starts the Crypto Sync backend server with proper configuration.

Usage:
    python start.py              # Start in production mode
    python start.py --dev        # Start in development mode with auto-reload
    python start.py --host 0.0.0.0 --port 8080  # Custom host/port
"""

import argparse
import os
import sys
import uvicorn
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

def check_environment():
    """Check if all required environment variables are set."""
    # Check for .env file and load it
    env_file = backend_dir / ".env"
    if env_file.exists():
        print(f"Loading environment from {env_file}")
        from dotenv import load_dotenv
        load_dotenv(env_file)
    
    # Check for persistent keys
    secret_key_file = backend_dir / "core" / ".secret_key"
    encryption_key_file = backend_dir / "core" / ".encryption_key"
    
    if not secret_key_file.exists():
        print("⚠️  WARNING: No persistent SECRET_KEY found. A new one will be generated.")
        print("   For production, set the SECRET_KEY environment variable.")
    
    if not encryption_key_file.exists():
        print("⚠️  WARNING: No persistent ENCRYPTION_KEY found. A new one will be generated.")
        print("   For production, set the ENCRYPTION_KEY environment variable.")
    
    # Check database
    db_file = backend_dir / "crypto_sync.db"
    if not db_file.exists():
        print("📦 Database not found. It will be created on first run.")
    else:
        print(f"✅ Database found: {db_file}")

def main():
    parser = argparse.ArgumentParser(description="Crypto Sync Backend Server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind to (default: 8000)")
    parser.add_argument("--dev", action="store_true", help="Run in development mode with auto-reload")
    parser.add_argument("--workers", type=int, default=1, help="Number of worker processes (production only)")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🚀 Crypto Sync Backend Server")
    print("=" * 60)
    
    # Check environment
    check_environment()
    
    print(f"\n📡 Server Configuration:")
    print(f"   Host: {args.host}")
    print(f"   Port: {args.port}")
    print(f"   Mode: {'Development' if args.dev else 'Production'}")
    
    if args.dev:
        print(f"\n🔄 Starting in DEVELOPMENT mode with auto-reload...")
        uvicorn.run(
            "main:app",
            host=args.host,
            port=args.port,
            reload=True,
            reload_excludes=["*.log", "*.db", "*.db-wal", "*.db-shm", "logs/*"],
            log_level="debug"
        )
    else:
        print(f"\n🚀 Starting in PRODUCTION mode...")
        print(f"   Workers: {args.workers}")
        
        if args.workers > 1:
            # Multi-worker mode (requires gunicorn)
            try:
                import gunicorn
                os.system(f"gunicorn main:app -w {args.workers} -k uvicorn.workers.UvicornWorker -b {args.host}:{args.port}")
            except ImportError:
                print("⚠️  Gunicorn not installed. Running with single worker.")
                uvicorn.run(
                    "main:app",
                    host=args.host,
                    port=args.port,
                    log_level="info"
                )
        else:
            uvicorn.run(
                "main:app",
                host=args.host,
                port=args.port,
                log_level="info"
            )

if __name__ == "__main__":
    main()
