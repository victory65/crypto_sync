# 👑 Crypto Sync: Creator's Handbook

As the creator of Crypto Sync, this guide gives you the "keys to the kingdom." It explains how to manage the backend, run simulations, and understand the internal security mechanics that keep the system running.

## 🛠️ Backend Architecture (Under the Hood)

The backend is built with **FastAPI** for high performance and **WebSockets** for real-time state streaming.

### Core Directory Map
*   `backend/main.py`: The "Brain." Contains all API endpoints and the mock database logic.
*   `backend/core/security.py`: The "Vault." Handles JWT tokens, password hashing (Bcrypt), and API key encryption (AES-256).
*   `backend/engine/trade_engine.py`: The "Engine." Orchestrates trade mirroring and the retry logic.
*   `backend/core/websocket.py`: The "Broadcaster." Manages live connections to mobile apps.

---

## 📦 Frontend Model Architecture

To ensure production stability, the frontend uses a dedicated model layer.
*   `lib/models/trade_models.dart`: Contains `Position`, `TradeSide`, `OrderType`, and `ExecutionStatus`.
*   `lib/models/account_models.dart`: Contains `SlaveAccount`, `MasterAccount`, and `AccountSyncStatus`.
*   `lib/widgets/common_widgets.dart`: Contains the `StatusBadge` which now supports `textColor` and `icon` for premium branding.

---

## 🎮 Admin & Simulation Control

You can manually trigger system events to test the app's responsiveness without making real trades.

### 1. The Simulation Dashboard (Auto-Generated)
The backend provides a built-in interactive documentation page.
*   **Access**: Start the backend and go to `http://localhost:8000/docs` in your browser.
*   **Action**: You can click on any "POST" endpoint (like `/simulate/trade`) and click "Try it out" to trigger events instantly.

### 2. Manual Simulation via Terminal (CURL)
If you prefer the command line, use these "God Mode" commands:

```powershell
# 💰 Trigger a Balance Change (Updates all Dashboard totals)
curl -X POST "http://localhost:8000/simulate/balance_change?user_id={your_id}"

# 🔄 Trigger a Trade Mirror (Watch the Positions & Live Protocol Feed)
curl -X POST "http://localhost:8000/simulate/trade?user_id={your_id}"

# ⚠️ Trigger a Trade Failure (Watch the "RETRYING" shimmers in the app)
curl -X POST "http://localhost:8000/simulate/retry?user_id={your_id}"
```

> [!TIP]
> Use **Cloudflare Tunnels** for the most stable remote testing:
> `cloudflared tunnel --url http://localhost:8000`
> 
> **502 Bad Gateway?** If your app can't reach the backend, ensure your Python process is running and the tunnel terminal window is still open. Cloudflare handles Windows localhost more reliably than older SSH-based tools.

---

## 🔐 Security & "Production" Readiness

### Where are the Keys?
In the current version, the system uses a **Mock In-Memory DB** (`USERS_DB` in `main.py`).
*   **To See Users**: Look at the `USERS_DB` variable in `main.py`.
*   **To Reset**: Restarting the backend clears the mock DB.

### Environment Variables
For a production deployment, you should set these environment variables to keep secrets out of the code:
*   `SECRET_KEY`: Used for signing JWT login tokens.
*   `ENCRYPTION_KEY`: A 32-byte base64 key used for AES-256 API key protection.

### 💳 Monetization & Access Control

The platform implements a **Hard-Enforced Subscription Model**:
*   **Server-Side Validation**: Account addition is validated against the user's active tier (Free, Basic, Pro). Attempts to exceed limits return a `403 Forbidden` response.
*   **Frontend Intercept**: The Flutter app dynamically adjusts the UI, disabling "Add Account" flows and displaying upgrade modals when tier limits are reached.
*   **Service Expiry**: Live sync is automatically suspended upon subscription expiry, marked by a system-wide `AccountSyncStatus.paused` state.

### JIT Decryption Logic
If you look at `backend/core/security.py`, you'll see `decrypt_api_key()`. This is called **only** in the `TradeEngine`. The decrypted key exists only for milliseconds in RAM and is never written to a file or sent to the app.

### 4. Managing Subscriptions & Tiers
Subscription tiers and limits are enforced in `backend/main.py`.
*   **Plan Definitions**:
    *   `free`: 1 Master, 1 Slave, 7-day trial.
    *   `basic`: 1 Master, 5 Slaves (**$19/mo**).
    *   `pro`: 1 Master, 10 Slaves (scaled pricing).
*   **To Override a User's Plan**: Locate the `subscription` object in `USERS_DB` and change `"plan": "free"` to `"plan": "pro"`.
*   **To Test Expiry**: Locate the `expiry` field (epoch timestamp) and set it to a past date.
*   **Session Isolation**: To protect user privacy, the `SyncProvider` explicitly calls `clearLogs()` during both the `connect()` (login/signup) and `disconnect()` flows. This wipes all local **Hive** records and transient state, ensuring that a shared device never leaks trade data between different user accounts.

### 🔘 Professional Account Controls
The Accounts system is now more robust:
*   **Editable Master**: In `accounts_overview_screen.dart`, the Master account card features a settings icon that allows users to re-invoke the `AddAccountScreen` in "edit mode" to update API keys and secrets.
*   **Lot Sizing Logic**: Slaves now support two mirroring modes:
    - **Fixed**: A constant value stored in the `lot_size` field.
    - **Percentage**: Calculates the order size as a percentage of the slave's live balance in `trade_engine.py`.
*   **Membership UI**: The Dashboard's portfolio card calls `_buildAnimatedPulseStatus`, which now evaluates the `SubscriptionProvider` state to display **"ACTIVATED: PRO"** or other relevant tier labels.

---

## 🚀 Production Release Checklist

Before you launch "Crypto Sync" to real users:
1.  **[ ] Environment Variables**: Replace the default `SECRET_KEY` and `ENCRYPTION_KEY` in `backend/core/security.py`.
2.  **[ ] Database Integration**: Swap the mock `USERS_DB` for a real PostgreSQL or MongoDB database.
3.  **[ ] Exchange Keys**: Ensure you have valid API keys for the exchanges you want to support via CCXT.
4.  **[ ] App Signing**: Compile the Flutter app for Release mode (`flutter build apk --release`).
5.  **[ ] Biometric Permissions**: Ensure the `local_auth` permissions are correctly set in `AndroidManifest.xml` and `Info.plist`.

---

## 📈 How to Extend the Project

### Adding a New Exchange
1.  Go to `backend/engine/trade_engine.py`.
2.  The engine uses the **CCXT** library. To add an exchange, simply integrate its ID (e.g., `bitget`, `kraken`) into the mirroring loop.

### Customizing the Mirroring Logic
The mirroring ratio is currently hardcoded for simulation. To make it dynamic:
1.  Update the `Account` model to include a `mirror_ratio`.
2.  Modify the `TradeEngine.mirror_trade()` method to multiply the master size by that ratio.

### Customizing the Visual Brand
1.  **Sparklines**: Locate `_SparklinePainter` in `dashboard_screen.dart`. You can modify the `quadraticBezierTo` coordinates to change the shape of the background decoration.
2.  **Animations**: All micro-animations are managed via `flutter_animate`. Adjust durations and curves (e.g., `Curves.easeOutCubic`) to refine the "premium" feel.
3.  **Currency & Crypto Symbols**: To change the global currency symbol, update the `_currencySymbol` field in `lib/providers/sync_provider.dart`. It supports both fiat ($, ₦, €) and crypto (BTC, ETH, USDT) symbols.
4.  **Production Readiness**: Remember that `MockData` is now purely for design-time previews and should never be used for real app logic. All logic should flow through `SyncProvider` using the new model layer.
5.  **Offline Protection Overlay**: The global guard is managed by `OfflineOverlay` in `lib/widgets/offline_overlay.dart`. You can adjust the blur intensity (`sigmaX/Y`), background opacity, or animation durations in this file to match your brand's specific "emergency" look.

---

## 🧪 Testing the Backend

You can run automated checks on your security logic:
1.  Ensure you have `pytest` installed: `pip install pytest`.
2.  Run `pytest` in the root directory to verify that encryption and authentication are working as expected.

**Happy Building, Creator!** 🚀✌️
