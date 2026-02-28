class ApiConfig {
  // --- CONNECTIVITY MODE ---
  // Option 1: LOCAL TCP (Default for Emulator)
  // Option 2: LOCAL NETWORK (For Physical Devices on same Wi-Fi)
  // Option 3: TUNNEL (ngrok, cloudflare, etc. for Remote Testing)
  
  static const bool useTunnel = false; // Set to FALSE for direct hotspot
  static const bool useLocalNetwork = false; // Set to TRUE for hotspot IP
  
  // Tunnel Settings (example: "your-tunnel.ngrok.io")
  static const String tunnelHost = "pound-gdp-thomson-viewpicture.trycloudflare.com"; 

  // Local Network Host (Your PC's IP on the Phone's Hotspot)
  static const String localNetworkHost = "10.54.206.191"; 
  // Emulator/Localhost Settings
  static const String localhostHost = "127.0.0.1"; 
  static const String localPort = "8000";

  // --- AUTOMATED URL GENERATION ---
  static String get host {
    if (useTunnel) return tunnelHost;
    return useLocalNetwork ? localNetworkHost : localhostHost;
  }
  
  static String get port => useTunnel ? "443" : localPort;
  static String get protocol => useTunnel ? "https" : "http";
  static String get wsProtocol => useTunnel ? "wss" : "ws";
  
  static String get baseUrl {
    if (useTunnel) {
      return "$protocol://$host";
    }
    return "$protocol://$host:$port";
  }

  static String get wsUrl {
    if (useTunnel) {
      return "$wsProtocol://$host/ws/user";
    }
    return "$wsProtocol://$host:$port/ws/user";
  }


  // Auth Endpoints
  static String get loginUrl => "$baseUrl/auth/login";
  static String get signupUrl => "$baseUrl/auth/signup";
  static String get forgotPasswordUrl => "$baseUrl/auth/forgot-password";
  static String get resetPasswordUrl => "$baseUrl/auth/reset-password";
  
  // Account Endpoints
  static String getAccountsUrl(String userId) => "$baseUrl/accounts/$userId";
}
