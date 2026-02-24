# Crypto Sync API Reference

The Crypto Sync backend is built with FastAPI and provides endpoints for authentication, account management, and real-time trade simulations.

## 🔑 Authentication

### Signup
*   **Endpoint**: `POST /auth/signup`
*   **Body**: `{"email": "user@example.com", "password": "secure_password"}`
*   **Returns**: `{"access_token": "...", "token_type": "bearer", "user_id": "...", "name": "...", "email": "...", "is_admin": false}`

### Login
*   **Endpoint**: `POST /auth/login`
*   **Body**: `{"email": "admin@crypto.sync", "password": "admin123"}`
*   **Returns**: `{"access_token": "...", "token_type": "bearer", "user_id": "...", "name": "...", "email": "...", "is_admin": true}` (Note: Admin login returns `is_admin: true`)

### Password Recovery
*   **Endpoint**: `POST /auth/forgot-password`
*   **Body**: `{"email": "user@example.com"}`
*   **Endpoint**: `POST /auth/reset-password`
*   **Body**: `{"token": "uuid_token", "new_password": "..."}`

### Get Accounts & Subscription
*   **Endpoint**: `GET /accounts/{user_id}`
*   **Returns**: List of accounts AND user subscription details (plan, expiry, is_expired).

### Add Account
*   **Endpoint**: `POST /accounts/{user_id}/add`
*   **Body**: 
    ```json
    {
      "name": "My Master",
      "exchange": "binance",
      "api_key": "your_key",
      "api_secret": "your_secret",
      "type": "slave",
      "lot_size": 0.01,
      "lot_size_mode": "fixed",
      "trade_type": "spot"
    }
    ```
*   **Returns**: New account object.

### Update Account
*   **Endpoint**: `POST /accounts/{user_id}/update/{account_id}`
*   **Body**: Same as Add Account (all fields optional).
*   **Returns**: Updated account object.
*   **Enforcement**: Returns `403 Forbidden` if plan limits (Free/Basic) are reached.

### Delete Account (Slave)
*   **Endpoint**: `DELETE /accounts/{user_id}/delete/{account_id}`
*   **Returns**: `200 OK` on success.

## 💳 Subscription Plans

| Tier | Limits | Price |
| :--- | :--- | :--- |
| **Free** | 1 Master, 1 Slave | 7-Day Trial only |
| **Basic** | 1 Master, 5 Slaves | $19 / month |
| **Pro** | 1 Master, 10+ Slaves | $49 / month + $5/extra |

## 🛰️ Real-Time Sync (WebSockets)

### WebSocket Handshake
*   **URL (Local)**: `ws://localhost:8000/ws/user/{user_id}?token={JWT_TOKEN}`
*   **URL (Production)**: `wss://your-tunnel-id.trycloudflare.com/ws/user/{user_id}?token={JWT_TOKEN}`
*   **Protocol**: JSON-based event stream.
*   **Mobile Processing**: Payloads are processed asynchronously using Flutter Isolates (`compute()`) to ensure zero-lag UI updates even during high-traffic bursts.

### Incoming Event Types (Server -> Client)
*   **`sync_status_update`**: Engine heartbeat and status updates.
*   **`balance_update`**: Real-time balance changes for Master/Slave accounts.
*   **`position_update`**: Creation, update, or deletion of trade positions.
*   **`slave_execution_update`**: Progress of a specific slave account mirroring a trade.
*   **`system_log`**: Log messages for the **Live Protocol Feed** (populated automatically and persisted via Hive). Includes special event markers:
    - `DETECTED`: Master trade opening
    - `CLOSED`: Master trade liquidation
    - `MIRROR`: Account toggle ACTIVATED/PAUSED

## 🧪 Simulation Endpoints

These endpoints are used to test the real-time responsiveness of the mobile app.

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| **POST** | `/simulate/trade?user_id={id}` | Triggers a mock trade mirroring sequence. |
| **POST** | `/simulate/balance_change?user_id={id}` | Updates account balances for the connected user. |
| **POST** | `/simulate/retry` | Triggers a simulated execution failure and subsequent retry. |

## 📦 Data Models

### Account Object
```json
{
  "id": "master_123",
  "name": "Binance Master",
  "type": "master",
  "exchange": "binance",
  "balance": 1250.50
}
```

### Position Object
```json
{
  "id": "pos_btc_1",
  "symbol": "BTC/USDT",
  "side": "buy",
  "master_size": 0.5,
  "entryPrice": 42000.0,
  "pnl": 120.0
}
```
