# Crypto Sync Feature Walkthrough

Welcome to the Crypto Sync project! This guide provides a detailed look at the core features and how to interact with the system.

## 🛡️ Security & Access

### 🔐 Advanced Security Center
Access the **Security Center** from the Settings menu for comprehensive protection:
*   **Two-Factor Authentication (2FA)**: Fully implemented TOTP flow. Generate a QR code, link to Google Authenticator, and secure your login.
*   **Active Sessions**: View every device logged into your account and terminate unauthorized sessions instantly.
*   **Login History**: A detailed audit log of every successful and failed login attempt, including IP and device info.
*   **Biometric Lock**: Toggle hardware-backed (Fingerprint/FaceID) locking for immediate app protection.

### 🌓 Theme Customization
Crypto Sync features a bespoke **Dual-Theme System**:
*   **Dark Mode**: Optimized for low-light trading sessions.
*   **Light Mode (Milky Green)**: A custom off-white aesthetic with sage undertones, designed to rhyme perfectly with the app's green accents.
*   Settings are persisted automatically across sessions.

## 👤 Profile & Session Isolation

### 🆔 Dynamic User Profiles
The platform now dynamically captures and identifies users:
*   **Real-Time Identification**: Your name and email are populated immediately upon login/signup.
*   **Profile Picture Persistence**: Custom profile pictures are saved to the cloud and synced across all your devices.
*   **Global Awareness**: Profile data is synced across the Settings screen and authentication flows.

### 🧹 Session Isolation
To ensure maximum privacy on shared devices:
*   **Auto-Clear Protocol**: The "Live Protocol Feed" and all historical logs are explicitly wiped every time a user logs out or a new user logs in.
*   **Secure State Reset**: All transient account data, positions, and balances are cleared on disconnect, ensuring a clean slate for the next session.


## 📡 Real-Time Dashboard

The dashboard is the nerve center of the app, providing instant feedback on your entire trading operation:
*   **Dual Status Header**: High-visibility badges showing your server heartbeat (**ONLINE** / **OFFLINE**) and your membership state (**ACTIVE** / **EXPIRED**).
*   **Combined Balance**: Total value across your Master and all Investor wallets.
*   **Professional-Grade Accounts**:
    *   Editable Master account with full API Secret support.
    *   Mandatory Lot Sizing with dual modes (**Fixed** vs **Percentage of Balance**).
*   **Subscription Awareness**: Real-time display of active tier (FREE/BASIC/PRO) directly on the Dashboard.
*   **Live Mirroring HUD**: A specialized real-time monitor that appears automatically when a trade is detected on the master account.
*   **Live Protocol Feed**: A high-tech stream showing real-time system activities. Now features granular logging for trade detection, liquidations, and mirroring state toggles.
*   **Premium Portfolio Overview**: A redesigned high-fidelity card featuring glassmorphism, background sparklines in **Success Green**, and a state-aware **LIVE SYNC** indicator.
*   **Dynamic Currency Control**: The platform now supports real-time currency switching ($, BTC, USDT, etc.) across all balance displays, managed centrally via `SyncProvider`.
*   **Zero Mock Dependency**: All traces of `MockData` have been removed. The app is now 100% driver by backend events and live persistent state.
*   **State-Aware Synchronization**: The indicator intelligently switches to **SYNC PAUSED** when a disconnection is detected, ensuring no "ghost" pulses! 👻🛑
*   **Privacy First**: Connection logs are automatically obfuscated for enhanced security.
*   **Refined Previews**: Accounts and Positions show a clean 3-item preview with "View All" shortcuts and clickable detail cards.
*   **Automatic Offline Protection**: The app features a global connectivity listener. If internet connection is lost, a premium non-dismissible overlay appears immediately.
*   **Instant Reconnection**: Once connection is restored, the `SyncProvider` triggers an immediate handshake to resume trade mirroring without user intervention.
*   **Anti-Flicker Debounce**: Connectivity changes are debounced by 500ms for stability during network switching.

## 📊 Mirroring & Accounts

### Master-Investor Archetype
*   **Master Account**: Your primary execution wallet.
*   **Mirroring Investors**: Trading accounts that perfectly follow the Master's moves.
*   **Execution Modes**: Each investor can be set to **Spot**, **Futures**, or **Both** to match your trading strategy.
*   **Lot Sizing**: Define specific quantities or percentages for each investor to manage risk.

### Active Positions
View live trades in real-time. If an exchange error occurs, you will see a **"RETRYING"** status badge while our backend engine automatically attempts to fix the synchronization.

## 💳 Subscription & Tiers

The system features a multi-tier monetization engine:
### ⛓️ Account Mirroring Logic
The Accounts tab allows you to connect your primary (Master) and secondary (Investor) accounts.
*   **Editable Master**: You can now update your primary execution account's API credentials at any time.
*   **Mandatory Lot Sizing**: All investors must have a defined lot size using either **Fixed** (absolute amount) or **Percentage** (of balance) mode.
*   **Live Status**: The Dashboard and Accounts tab provide real-time updates on your connectivity and membership level (e.g., ACTIVATED: PRO).
*   **Free (7-Day Trial)**: Access the full system for 7 days with 1 investor account limit.
*   **Basic**: Standard mirroring for up to 5 investor accounts (**$19/mo**).
*   **Pro**: Professional grade with 10+ investors and intelligent per-investor scaling (**$49/mo**).
*   **Expiration Management**: If a subscription expires, the sync engine automatically pauses (`Sync paused` status), and a dashboard banner provides immediate feedback.

## 🚀 Bot Nexus (Coming Soon)
**Redesigned from the legacy P2P system**, the Bot Nexus is your future hub for premium trading automation:
*   **Futuristic UI**: A high-fidelity "Deep Space" interface with glowing auras and custom grid animations.
*   **Coming Soon**: Stay tuned for the release of exclusive, pre-configured trading bots that you can deploy with a single click.

## 🌐 Connectivity Setup (Important)

The app is designed to work in any environment. Edit **[api_config.dart](file:///c:/Users/VICTORY/Desktop/crypto_sync/lib/core/api_config.dart)** to switch:

1.  **Emulator**: Set `isProduction = false` and `useLocalNetwork = false`.
2.  **Physical Device (Local)**: Set `isProduction = false`, `useLocalNetwork = true`, and enter your computer's IP in `localNetworkHost`.
3.  **Deployment**: Set `isProduction = true` and enter your server URL in `prodHost`.

## 🛠️ Developer Simulation Tools

You can trigger real-time updates for demonstration purposes using the following endpoints (available while `backend/main.py` is running):

| Action | Endpoint (POST) |
| :--- | :--- |
| **Simulate Balance Fill** | `/simulate/balance_change?user_id={id}` |
| **Simulate New Trade** | `/simulate/trade?user_id={id}` |

### 🚨 Admin Debug Menu (Admin-Only)
For direct functional testing on authorized administrative devices:
1.  **Admin Check**: This menu is physically disabled and invisible for non-admin users.
2.  Navigate to the **Dashboard** as an admin (`admin@crypto.sync`).
2.  **Long-press** on the **Total Combined Balance** figures.
3.  **Tier Switching**: Select any tier (Trial, Basic, Professional) to instantly update investor limits and UI status.
4.  **Expire Toggle**: Toggle the "Expired Status" to verify the app's sync-pause behavior and warning overlays.
## 🔧 System Stability & Technical Resolution

The "Crypto Sync" environment has been rigorously tested and stabilized to ensure a smooth development and production experience.

### 1. Backend Performance & Security
- **Protobuf Optimization**: Resolved version conflicts between `ccxt` and `google.protobuf` to ensure zero-crash execution.
- **Import Sanity**: All backend modules use absolute imports for reliable deployment.
- **Cryptographic Guard**: Password hashing is handled via `bcrypt` (v4.0.1) for maximum security and cross-platform compatibility.

### 2. Frontend Resiliency
- **Framework Alignment**: The Flutter app is fully compliant with the latest Material 3 standards and utilizes `connectivity_plus` for live network monitoring.
- **Sync Logic**: The `SyncProvider` utilizes a robust WebSocket client that handles disconnections gracefully with automatic recovery.
- **Clean Architecture Transition**: Migrated from static `MockData` to a robust, model-driven architecture using `trade_models.dart` and `account_models.dart`.
- **Type Safety**: All compilation errors (Type Not Found, Syntax Mismatches) have been systematically resolved across the entire 15+ screen library.

### 3. Final Tunnel Verification
- **Current URL**: The app is configured via `lib/core/api_config.dart`. Update `prodHost` with your active Cloudflare Tunnel endpoint (e.g., `your-unique-id.trycloudflare.com`).
- **Verification**: When the backend is running and the tunnel is active, you will see a green **"ONLINE"** pill on your dashboard.
- **Mirroring Test**: Trigger a trade simulation and watch the **Live Execution Screen** pass real-time updates from `Binance` to your `Bybit` or `Bitget` investors.
| **Status Clarity** | Header Row | Clear visibility of both Connection (Online) and Sub status |
| **Protocol Feed** | Auth Events | Login successes appear in green in the feed |

Everything is now fully integrated, tested, and ready for deployment! 🚀🏆

