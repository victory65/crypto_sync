# 🚀 Crypto Sync

**High-Fidelity Real-Time Crypto Mirroring Platform**

Crypto Sync is a production-grade trade mirroring system that allows users to synchronize trades across multiple exchange accounts with zero latency. It features a robust FastAPI backend and a premium, theme-aware Flutter mobile application.

## ✨ Core Features

*   🌍 **Real-Time Synchronization**: Instant state propagation via WebSockets with **Instant Reconnection** logic.
*   👑 **Professional Account Management**: Support for **Spot, Futures, and Both** execution modes with mandatory investor lot sizing.
*   🔐 **Advanced Security**: AES-256 JIT encryption for API keys and **Full 2FA Implementation** (TOTP/OTP).
*   📈 **Membership Awareness**: Real-time display of active subscription tier with enforceable limits on investor accounts.
*   👤 **Dynamic User Profiles**: Real-time identification, profile picture persistence, and cloud sync across logins.
*   🛡️ **Security Center**: Specialized module for 2FA management, login history, and **Session Isolation**.
*   ⚙️ **Intelligent Trade Engine**: Concurrent multi-account execution with optimized SQLite **WAL Mode** for zero-latency database writes.
*   🚫 **Offline Protection**: Automatic app-wide disablement with instant recovery when network connectivity is restored.

## 📚 Project Documentation

Detailed documentation is available in the `docs/` directory:

*   📘 **[Architectural Decisions](docs/ARCHITECTURAL_DECISIONS.md)**: Deep dive into the system design, security protocols, and tech stack.
*   📖 **[Feature Walkthrough](docs/WALKTHROUGH.md)**: User guide for all major app features and UI components.
*   🔌 **[API Reference](docs/API_DOCUMENTATION.md)**: Comprehensive guide to the FastAPI backend and WebSocket event structures.

## 🛠️ Quick Start

### 1. Backend Setup
```bash
cd backend
pip install -r requirements.txt
python main.py
```

### 2. Frontend Setup
```bash
flutter pub get
flutter run
```

### 3. Physical Device Testing
To connect your app on a physical phone:
- **USB Cable**: Use `adb reverse tcp:8000 tcp:8000` and `localhostHost = "127.0.0.1"`.
- **Hotspot**: Use your phone's hotspot and update `localNetworkHost` with your PC's wireless IP.
- **Tunnel**: Use `cloudflared tunnel --url http://localhost:8000` and update `tunnelHost` in `lib/core/api_config.dart`.

---

## 📈 Project Status: **v1.0 Release-Ready**
- [x] **Auth & 2FA**: Real JWT Login/Register with full TOTP 2FA flow.
- [x] **Profiles**: Dynamic user data and profile picture persistence.
- [x] **Bot Nexus**: Premium "Coming Soon" interface with futuristic design.
- [x] **Security**: AES-256 JIT Encryption + session management + login logs.
- [x] **Mirroring**: WebSocket-based trade detection with support for Spot/Futures/Both modes.
- [x] **Stability**: Connectivity monitoring and SQLite WAL optimization.

---
*Built with ❤️ for professional traders.*

