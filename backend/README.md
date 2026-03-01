# Crypto Sync Backend

Production-ready backend for the Crypto Sync trade mirroring platform.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and set your secure keys
# IMPORTANT: Change SECRET_KEY and ENCRYPTION_KEY for production!
```

### 3. Start the Server

```bash
# Development mode (with auto-reload)
python start.py --dev

# Production mode
python start.py

# Custom host/port
python start.py --host 0.0.0.0 --port 8080
```

## 📁 Project Structure

```
backend/
├── main.py              # FastAPI application & API endpoints
├── start.py             # Startup script
├── requirements.txt     # Python dependencies
├── .env.example         # Environment configuration template
├── crypto_sync.db       # SQLite database (auto-created)
├── core/                # Core modules
│   ├── database.py      # Database connection & models
│   ├── security.py      # Encryption, JWT, password hashing
│   ├── websocket.py     # WebSocket connection manager
│   └── logger.py        # Logging utilities
└── engine/              # Trade execution engine
    └── trade_engine.py  # CCXT-based trade mirroring
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | JWT signing key | Auto-generated |
| `ENCRYPTION_KEY` | API key encryption | Auto-generated |
| `HOST` | Server bind address | 0.0.0.0 |
| `PORT` | Server port | 8000 |
| `LOG_LEVEL` | Logging level | INFO |

### Generating Secure Keys

```bash
# Generate SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate ENCRYPTION_KEY
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

## 📡 API Endpoints

### Authentication
- `POST /auth/signup` - User registration
- `POST /auth/login` - User login
- `POST /auth/forgot-password` - Password reset request
- `POST /auth/reset-password` - Password reset
- `POST /auth/2fa/setup` - Setup 2FA
- `POST /auth/2fa/enable` - Enable 2FA
- `POST /auth/2fa/disable` - Disable 2FA

### Accounts
- `GET /accounts/{user_id}` - List user accounts
- `POST /accounts/{user_id}/add` - Add new account
- `POST /accounts/{user_id}/update/{account_id}` - Update account
- `POST /accounts/{user_id}/toggle/{account_id}` - Enable/disable account
- `DELETE /accounts/{user_id}/{account_id}` - Delete account

### Trading
- `GET /trade/price?user_id={id}&symbol={symbol}` - Get asset price
- `POST /trade/execute` - Execute manual trade

### WebSocket
- `/ws/user/{user_id}?token={jwt}` - Real-time updates

## 🔒 Security Features

- ✅ JWT-based authentication
- ✅ AES-256 API key encryption
- ✅ Bcrypt password hashing
- ✅ 2FA support (TOTP)
- ✅ Rate limiting via CCXT
- ✅ Input validation
- ✅ SQL injection protection

## 🐛 Troubleshooting

### "Failed to initiate sync" Error

This error typically occurs when:
1. Master account has invalid API credentials
2. Exchange is not supported
3. Network connectivity issues

**Solution:**
- Verify API keys are correct
- Check exchange is in supported list
- Check server logs for detailed error

### Database Locked Error

**Solution:**
- The backend now uses WAL mode for better concurrency
- Connection pooling is enabled by default

### Token Validation Fails After Restart

**Solution:**
- Set persistent `SECRET_KEY` in `.env` file
- Keys are auto-generated on first run if not set

## 📊 Monitoring

### Health Check
```bash
curl http://localhost:8000/health
```

### Admin Stats
```bash
curl http://localhost:8000/admin/stats
```

## 🚀 Deployment

### Using Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["python", "start.py"]
```

### Using Gunicorn (Production)

```bash
python start.py --workers 4
```

## 📝 Logs

Logs are stored in:
- `logs/system.log` - System events
- `logs/trades.log` - Trade execution logs
- `logs/auth.log` - Authentication events

## 🔧 Supported Exchanges

- Binance
- Bybit
- Bitget
- OKX
- Gate.io
- MEXC
- Kraken
- Phemex
- Deribit
- BitMEX
- Coinbase
- KuCoin

## 📄 License

Private - For Crypto Sync use only.
