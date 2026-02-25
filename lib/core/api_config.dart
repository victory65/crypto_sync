class ApiConfig {
  // --- CONFIGURATION ---
  // Set this to true when you are ready to deploy to your server
  // (Using TRUE for remote deployment as requested)
  static const bool isProduction = true; 
  
  // Set this to true if you are using a PHYSICAL DEVICE on your Wi-Fi
  static const bool useLocalNetwork = false;

  // Development Settings (Emulator)
  static const String devHost = "10.0.2.2"; 
  static const String devPort = "8000";

  // Local Network Settings (For Physical Devices)
  static const String localNetworkHost = "192.168.1.5"; 

  // Production Settings (Replace prodHost with your Public IP or Tunnel URL)
  // For example: "8.tcp.ngrok.io" or "your-app.herokuapp.com"
  static const String prodHost = "agreements-course-mumbai-harvey.trycloudflare.com"; 
  static const String prodPort = "443"; // Standard HTTPS port
  static const String prodProtocol = "https"; 
  static const String prodWsProtocol = "wss"; 

  // --- AUTOMATED URL GENERATION ---
  static String get host {
    if (isProduction) return prodHost;
    return useLocalNetwork ? localNetworkHost : devHost;
  }
  static String get port => isProduction ? prodPort : devPort;
  static String get protocol => isProduction ? prodProtocol : "http";
  static String get wsProtocol => isProduction ? prodWsProtocol : "ws";
  
  static String get baseUrl {
    if (isProduction && (prodPort == "443" || prodPort == "")) {
      return "$protocol://$host";
    }
    return "$protocol://$host:$port";
  }

  static String get wsUrl {
    if (isProduction && (prodPort == "443" || prodPort == "")) {
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
