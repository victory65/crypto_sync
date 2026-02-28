# 🚀 Crypto Sync Deployment Guide

This guide outlines the steps to move Crypto Sync from your local development environment to a live production server.

## 1. Backend Deployment (FastAPI)

### Step A: Hosted Server Setup
- **Recommended Platforms**: AWS EC2, DigitalOcean Droplet, Render, or Railway.
- **Environment**: Use Python 3.11+.

### Step B: Production Configuration
Do **not** use the default keys in `backend/core/security.py`. Set these environment variables on your server:
```bash
# Generate a unique 32-byte key for encryption
ENCRYPTION_KEY="your-persistent-base64-fernet-key"

# Generate a strong random string for JWT
SECRET_KEY="your-super-secret-jwt-signing-key"

# Allow your domain to connect (CORS)
# Update mainland.py middleware if necessary
```

### Step C: SSL/HTTPS (Critical)
- Use **Nginx** or **Traefik** as a reverse proxy.
- Secure your API and WebSockets with **Certbot (Let's Encrypt)**.
- **WebSocket Note**: Use `wss://` instead of `ws://` in production.

---

## 2. Frontend Deployment (Flutter)

### Step A: Connectivity Switch
Before building your app, ensure **[api_config.dart](file:///c:/Users/VICTORY/Desktop/crypto_sync/lib/core/api_config.dart)** is configured for your environment:
```dart
// For Tunnel (Production/Remote)
static const bool useTunnel = true;
static const String tunnelHost = "your-url.trycloudflare.com"; 

// For Hotspot/Local Wi-Fi
static const bool useTunnel = false;
static const bool useLocalNetwork = true;
static const String localNetworkHost = "10.x.x.x"; 
```

### Step B: Connection & Tunneling
If you encounter a **502 Bad Gateway** or **Connection Refused** in your Flutter logs, it means your tunnel is active but cannot reach your Python process.

1.  **Local Development Tunnel (e.g., Cloudflare)**:
    - **Command**: `cloudflared tunnel --url http://localhost:8000`
    - **Update App**: Set `useTunnel = true` and paste the generated `.trycloudflare.com` URL to `tunnelHost`.
    - **Firewall**: Ensure port 8000 is open in your OS firewall.

2.  **USB Bridge (ADB Reverse)**:
    - **Command**: `adb reverse tcp:8000 tcp:8000`
    - **Update App**: Set `useLocalNetwork = false` and `localhostHost = "127.0.0.1"`.

3.  **Verification**: 
    - Check the terminal output of the tunnel or bridge.
    - Once connected, you will see the green **"ONLINE"** pill on your mobile dashboard.

### Step B: Build for Release
Run the release build command for your target platform:
```bash
# Android
flutter build apk --release

### Step C: Android 13+ Navigation (Gestures)
Ensure your `android/app/src/main/AndroidManifest.xml` includes `android:enableOnBackInvokedCallback="true"` within the `<application>` tag to support modern gesture navigation without warnings.

# iOS
flutter build ios --release
```

---

## 3. Database Migration
The current system uses an in-memory `USERS_DB`.
- **Recommendation**: Integrate **PostgreSQL** or **MongoDB**.
- **Action**: Update `backend/main.py` endpoints to perform CRUD operations on your real database.
- **Local Persistence**: The mobile app uses **Hive** for log caching. Ensure `Hive.initFlutter()` is called in `main.dart` before `runApp()`.

## 4. Scaling the Engine
- For high-volume mirroring, consider moving the `TradeEngine` to a separate worker process using **Celery** or **RabbitMQ**.
- Ensure your server has enough RAM to handle thousands of concurrent WebSocket connections.

---
**Deployment Stage**: Current codebase is "Portable." All networking and security settings are centralized for easy migration.
