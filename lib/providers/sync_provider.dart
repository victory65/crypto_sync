import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_sync/core/api_config.dart';

enum SyncStatus { connected, disconnected, connecting, error }

class SyncProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  SyncStatus _status = SyncStatus.disconnected;
  String? _lastError;
  SubscriptionProvider? _subProvider;
  
  // Real-time states
  List<dynamic> _accounts = [];
  Map<String, dynamic> _currentPositions = {};
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _balances = {};
  Map<String, dynamic> _accountMetadata = {}; // Store lot sizes etc.
  String _engineStatus = "inactive";
  double _portfolioChangePercent = 0.0;
  String _currencySymbol = '\$';
  bool _isFetchingAccounts = false;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userProfilePic;

  SyncStatus get status => _status;
  bool get isOnline => _status == SyncStatus.connected;
  String? get lastError => _lastError;
  List<dynamic> get accounts => _accounts;
  bool get isFetchingAccounts => _isFetchingAccounts;
  List<Map<String, dynamic>> get logs => _logs;
  Map<String, dynamic> get balances => _balances;
  Map<String, dynamic> get accountMetadata => _accountMetadata;
  String get engineStatus => _engineStatus;
  double get portfolioChangePercent => _portfolioChangePercent;
  String get currencySymbol => _currencySymbol;
  Map<String, dynamic> get currentPositions => _currentPositions;
  String? get lastUserId => _lastUserId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userProfilePic => _userProfilePic;

  // Configuration
  final String _baseUrl = ApiConfig.wsUrl; 
  String? _lastUserId;
  String? _lastToken;
  bool _isManuallyDisconnected = false;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  bool _isDisposed = false;
  bool _isConnecting = false;
  StreamSubscription? _connectivitySubscription;
  Timer? _healthCheckTimer;

  static const String _userIdKey = 'auth_user_id';
  static const String _tokenKey = 'auth_token';
  static const String _userNameKey = 'auth_user_name';
  static const String _userEmailKey = 'auth_user_email';
  static const String _userPhoneKey = 'auth_user_phone';
  static const String _userProfilePicKey = 'auth_user_profile_pic';
  static const String _isAdminKey = 'auth_is_admin';

  SubscriptionProvider? get subProvider => _subProvider;

  void setSubscriptionProvider(SubscriptionProvider provider) {
    _subProvider = provider;
  }

  Future<void> connect(String userId, String token, {SubscriptionProvider? subProvider, String? userName, String? userEmail, String? userPhone, String? userProfilePic, bool? isAdmin}) async {
    _lastUserId = userId;
    _lastToken = token;
    _userName = userName;
    _userEmail = userEmail;
    _userPhone = userPhone;
    _userProfilePic = userProfilePic;
    if (subProvider != null) _subProvider = subProvider;
    _isManuallyDisconnected = false;
    _reconnectAttempts = 0;
    
    // Persist session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_tokenKey, token);
    if (userName != null) await prefs.setString(_userNameKey, userName);
    if (userEmail != null) await prefs.setString(_userEmailKey, userEmail);
    if (userPhone != null) await prefs.setString(_userPhoneKey, userPhone);
    if (userProfilePic != null) await prefs.setString(_userProfilePicKey, userProfilePic);
    if (isAdmin != null) {
      await prefs.setBool(_isAdminKey, isAdmin);
      _subProvider?.setIsAdmin(isAdmin);
    }
    
    notifyListeners();
    
    // Clear old logs for the new user session
    await clearLogs();
    
    _loadBalancesFromCache();
    _initConnectivityListener();
    _establishConnection();
    fetchAccounts();
  }

  Future<bool> loadSession({SubscriptionProvider? subProvider}) async {
    if (subProvider != null) _subProvider = subProvider;
    final prefs = await SharedPreferences.getInstance();
    _lastUserId = prefs.getString(_userIdKey);
    _lastToken = prefs.getString(_tokenKey);
    
    if (_lastUserId != null && _lastToken != null) {
      _userName = prefs.getString(_userNameKey);
      _userEmail = prefs.getString(_userEmailKey);
      _userPhone = prefs.getString(_userPhoneKey);
      _userProfilePic = prefs.getString(_userProfilePicKey);
      _subProvider?.setIsAdmin(prefs.getBool(_isAdminKey) ?? false);
      _loadLogsFromCache();
      _loadBalancesFromCache();
      _initConnectivityListener();
      _establishConnection();
      fetchAccounts();
      notifyListeners();
      return true;
    }
    return false;
  }

  void _establishConnection() {
    if (_isManuallyDisconnected || _lastUserId == null || _lastToken == null || _isConnecting) {
      debugPrint('Connection attempt skipped: Manually disconnected, missing credentials, or already connecting.');
      return;
    }

    // Clean up any existing channel before starting a new one
    try {
      _channel?.sink.close(ws_status.goingAway);
    } catch (e) {
      debugPrint('Error closing existing channel: $e');
    }
    _channel = null;

    final wsUrl = "$_baseUrl/$_lastUserId?token=$_lastToken";
    _status = SyncStatus.connecting;
    _isConnecting = true;
    notifyListeners();

    if (_subProvider != null) syncSubscriptionState(_subProvider!);

    try {
      debugPrint('Establishing WebSocket connection to: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.ready.timeout(const Duration(seconds: 10)).then((_) {
        if (!_isManuallyDisconnected && _channel != null) {
          _status = SyncStatus.connected;
          _isConnecting = false;
          _reconnectAttempts = 0;
          _addLog('System', 'Connected to Protocol Feed', isSuccess: true);
          notifyListeners();
        }
      }).catchError((e) {
        debugPrint('Connection failed or timed out: $e');
        _isConnecting = false;
        _onError('Connection timeout/failure: $e');
      });

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnecting = false;
          _onDisconnected();
        },
        onError: (error) {
          _isConnecting = false;
          _onError(error);
        },
      );
      _startHeartbeat();
    } catch (e) {
      _isConnecting = false;
      _onError('Failed to initiate connection: $e');
    }
  }

  Future<void> disconnect() async {
    _isManuallyDisconnected = true;
    _heartbeatTimer?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    
    // Clear session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userProfilePicKey);
    await prefs.remove(_isAdminKey);
    _subProvider?.setIsAdmin(false);
    _lastUserId = null;
    _lastToken = null;
    _userName = null;
    _userEmail = null;
    _status = SyncStatus.disconnected;
    _accounts = [];
    _currentPositions = {};
    _balances = {};
    _accountMetadata = {};
    
    // Clear logs on logout for security
    await clearLogs();
    
    notifyListeners();
  }

  void _onDisconnected() {
    debugPrint('WebSocket Disconnected');
    _status = SyncStatus.disconnected;
    _isConnecting = false;
    _channel = null;
    _heartbeatTimer?.cancel();
    notifyListeners();
    _startHealthCheckLoop();
    _handleReconnect();
  }

  void _onError(dynamic error) {
    debugPrint('WebSocket Error: $error');
    _lastError = error.toString();
    _status = SyncStatus.error;
    _isConnecting = false;
    _channel = null;
    _heartbeatTimer?.cancel();
    notifyListeners();
    _startHealthCheckLoop();
    _handleReconnect();
  }

  void _handleReconnect() {
    if (_isManuallyDisconnected || _isConnecting) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 30));
    
    _addLog('System', 'Attempting reconnection in ${delay.inSeconds}s...', isError: true);
    
    Future.delayed(delay, () {
      if (!_isDisposed && !_isManuallyDisconnected && _status != SyncStatus.connected && !_isConnecting) {
        _establishConnection();
      }
    });
  }

  Future<void> fetchAccounts() async {
    if (_lastUserId == null || _isFetchingAccounts) return;
    
    _isFetchingAccounts = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getAccountsUrl(_lastUserId!)),
        headers: {'Authorization': 'Bearer $_lastToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body);
        final List<dynamic> accountList = data['accounts'] ?? [];
        _accounts = accountList.map((acc) {
          final map = Map<String, dynamic>.from(acc as Map);
          // Safely cast boolean fields from potential SQLite integers
          map['enabled'] = map['enabled'] == 1 || map['enabled'] == true;
          return map;
        }).toList();
        
        // Update subscription state from the same response
        if (_subProvider != null && data['subscription'] != null) {
          final sub = data['subscription'];
          _subProvider!.updateSubscription(
            planStr: sub['plan'],
            expiryTimestamp: sub['expiry'],
            isExpired: sub['is_expired'],
          );
        }
      } else {
        _addLog('System', 'Failed to fetch accounts: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _addLog('System', 'Error fetching data: Internet connection issue', isError: true);
    } finally {
      _isFetchingAccounts = false;
      notifyListeners();
    }
  }

  Future<bool> addAccount({
    required String name,
    required String exchange,
    required String apiKey,
    required String apiSecret,
    required double lotSize,
    required String lotSizeMode,
    required String tradeType,
    String type = 'investor',
  }) async {
    if (_lastUserId == null) return false;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/accounts/$_lastUserId/add"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_lastToken'
        },
        body: jsonEncode({
          'name': name,
          'exchange': exchange,
          'api_key': apiKey,
          'api_secret': apiSecret,
          'lot_size': lotSize,
          'lot_size_mode': lotSizeMode,
          'trade_type': tradeType,
          'type': type,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _addLog('Account', 'New account added: $name');
        await fetchAccounts();
        return true;
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Failed to add account';
        _addLog('Account', 'Error: $error', isError: true);
        return false;
      }
    } catch (e) {
      _addLog('Account', 'Secure connection error: Verify internet access', isError: true);
      return false;
    }
  }

  Future<bool> updateAccount({
    required String accountId,
    String? name,
    String? apiKey,
    String? apiSecret,
    double? lotSize,
    String? lotSizeMode,
    String? tradeType,
  }) async {
    if (_lastUserId == null) return false;

    try {
      final Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (apiKey != null) body['api_key'] = apiKey;
      if (apiSecret != null) body['api_secret'] = apiSecret;
      if (lotSize != null) body['lot_size'] = lotSize;
      if (lotSizeMode != null) body['lot_size_mode'] = lotSizeMode;
      if (tradeType != null) body['trade_type'] = tradeType;

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/accounts/$_lastUserId/update/$accountId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_lastToken'
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _addLog('Account', 'Account updated successfully');
        await fetchAccounts();
        return true;
      } else {
        _addLog('Account', 'Failed to update account', isError: true);
        return false;
      }
    } catch (e) {
      _addLog('Account', 'Update error: Secure connection issue', isError: true);
      return false;
    }
  }

  Future<void> toggleAccountSync(String accountId) async {
    if (_lastUserId == null) return;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/accounts/$_lastUserId/toggle/$accountId"),
        headers: {'Authorization': 'Bearer $_lastToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        for (var i = 0; i < _accounts.length; i++) {
          if (_accounts[i]['id'] == accountId) {
            final bool currentEnabled = _accounts[i]['enabled'] == 1 || _accounts[i]['enabled'] == true;
            _accounts[i]['enabled'] = !currentEnabled;
            final status = _accounts[i]['enabled'] ? 'ACTIVATED' : 'PAUSED';
            _addLog('Mirror', 'Mirroring for ${_accounts[i]['name'] ?? accountId} $status', isSuccess: _accounts[i]['enabled']);
            break;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _addLog('Account', 'Sync toggle failed: Secure connection issue', isError: true);
    }
  }

  Future<bool> removeAccount(String accountId) async {
    if (_lastUserId == null) return false;

    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/accounts/$_lastUserId/delete/$accountId"),
        headers: {'Authorization': 'Bearer $_lastToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _accounts.removeWhere((a) => (Map<String, dynamic>.from(a as Map))['id'] == accountId);
        _addLog('Account', 'Account removed successfully');
        notifyListeners();
        return true;
      } else {
        _addLog('Account', 'Failed to remove account', isError: true);
        return false;
      }
    } catch (e) {
      _addLog('Account', 'Connection error while removing account', isError: true);
      return false;
    }
  }

  Future<void> syncSubscriptionState(SubscriptionProvider subProvider) async {
    // This is now redundant with fetchAccounts but kept for compatibility
    await fetchAccounts();
  }

  Future<void> _handleMessage(String message) async {
    if (message == "pong") {
      debugPrint('Heartbeat: pong received');
      return;
    }
    
    _status = SyncStatus.connected;
    _isConnecting = false;
    try {
      final decoded = await compute(jsonDecode, message);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('Unexpected WebSocket message format: $message');
        return;
      }

      final event = decoded['event'];
      final payload = decoded['payload'];

      if (event == null || payload == null) return;

      switch (event) {
        case 'sync_status_update':
          _engineStatus = payload['status']?.toString() ?? "unknown";
          break;
        case 'balance_update':
          _updateBalances(Map<String, dynamic>.from(payload as Map));
          break;
        case 'position_update':
          _updatePositionState(Map<String, dynamic>.from(payload as Map));
          break;
        case 'investor_execution_update':
          _updateInvestorExecution(Map<String, dynamic>.from(payload as Map));
          break;
        case 'account_update':
          _updateAccountMetadata(Map<String, dynamic>.from(payload as Map));
          break;
        case 'system_log':
          _addLog('System', payload['message']?.toString() ?? '');
          break;
        case 'system_error':
          _addLog('System Error', payload['message']?.toString() ?? '', isError: true);
          _lastError = payload['message']?.toString();
          break;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _updateBalances(Map<String, dynamic> payload) {
    _balances = Map<String, dynamic>.from(payload);
    _persistBalances();
    _addLog('Sync', 'Balance update received');
  }

  void _persistBalances() {
    try {
      final box = Hive.box('protocol_logs'); // Reuse or create a new box if preferred
      box.put('cached_balances', _balances);
    } catch (e) {
      debugPrint('Error persisting balances: $e');
    }
  }

  void _loadBalancesFromCache() {
    try {
      final box = Hive.box('protocol_logs');
      final cached = box.get('cached_balances');
      if (cached != null) {
        _balances = Map<String, dynamic>.from(cached as Map);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached balances: $e');
    }
  }

  void _updateAccountMetadata(Map<String, dynamic> payload) {
    final accountId = payload['account_id'];
    _accountMetadata[accountId] = payload;
    _addLog('Account', 'Updated settings for $accountId');
  }

  void _updatePositionState(Map<String, dynamic> payload) {
    final posId = payload['position_id'];
    if (posId == null) return;

    if (!_currentPositions.containsKey(posId)) {
      _currentPositions[posId] = {
        "id": posId,
        "symbol": payload['symbol'] ?? "Unknown",
        "side": payload['side'] ?? "Unknown",
        "master_status": payload['master_status'] ?? "detected",
        "investors": {}
      };
      _addLog('Trade', 'DETECTED: Master ${payload['side']} ${payload['symbol']}', isSuccess: true);
    }
    
    // Check for status changes (filled, closed, etc.)
    final oldStatus = _currentPositions[posId]['master_status'];
    final newStatus = payload['master_status'];
    if (newStatus != null && oldStatus != newStatus) {
      _currentPositions[posId]['master_status'] = newStatus;
      String actionMessage = 'Position ${payload['symbol']} moved to $newStatus';
      if (newStatus.toString().toLowerCase() == 'closed') {
        actionMessage = 'CLOSED: Master position ${payload['symbol']} liquidated';
      }
      _addLog('Trade', actionMessage);
    }
  }

  void _updateInvestorExecution(Map<String, dynamic> payload) {
    final posId = payload['position_id'];
    final investorId = payload['investor_id'] ?? payload['account_id'];
    
    if (posId != null && _currentPositions.containsKey(posId)) {
      final investors = _currentPositions[posId]['investors'] as Map<String, dynamic>;
      final symbol = _currentPositions[posId]['symbol'];
      investors[investorId] = payload;
      
      final status = payload['status'].toString().toUpperCase();
      _addLog('Execution', '$status: Mirror on Investor $investorId for $symbol', 
        isSuccess: status == 'FILLED',
        isError: status == 'FAILED'
      );
    }
  }

  void addCustomLog(String title, String message, {bool isError = false, bool isSuccess = false}) {
    _addLog(title, message, isError: isError, isSuccess: isSuccess);
    notifyListeners();
  }

  Future<void> clearLogs() async {
    _logs = [];
    try {
      final box = Hive.box('protocol_logs');
      await box.clear();
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
    notifyListeners();
  }

  void _addLog(String title, String message, {bool isError = false, bool isSuccess = false}) {
    final log = {
      'timestamp': DateTime.now().toIso8601String(),
      'title': title,
      'message': message,
      'isError': isError,
      'isSuccess': isSuccess,
    };
    
    _logs.insert(0, log);
    if (_logs.length > 50) _logs.removeLast();
    
    // Persist to Hive
    _persistLogs();
  }

  void _persistLogs() {
    try {
      final box = Hive.box('protocol_logs');
      box.put('history', _logs);
    } catch (e) {
      debugPrint('Error persisting logs: $e');
    }
  }

  void _loadLogsFromCache() {
    try {
      final box = Hive.box('protocol_logs');
      final cached = box.get('history');
      if (cached != null) {
        _logs = (cached as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached logs: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _healthCheckTimer?.cancel(); // Stop health checks when connected
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_status == SyncStatus.connected) {
        _channel?.sink.add("ping");
      } else {
        timer.cancel();
      }
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      // Results is a List<ConnectivityResult> in connectivity_plus 6.x
      final hasNetwork = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (hasNetwork) {
        // Only trigger if we are currently disconnected/error and not already trying to connect
        if (_status != SyncStatus.connected && !_isConnecting && !_isManuallyDisconnected) {
          debugPrint('Network restored. Triggering immediate reconnection.');
          _addLog('System', 'Network restored. Reconnecting...');
          _reconnectAttempts = 0; // Reset attempts to connect immediately
          _establishConnection();
        }
      }
    });
  }

  void _startHealthCheckLoop() {
    if (_isManuallyDisconnected || _isDisposed || _status == SyncStatus.connected) return;
    
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_status == SyncStatus.connected || _isManuallyDisconnected || _isDisposed) {
        timer.cancel();
        return;
      }

      if (_isConnecting) return;

      try {
        // Ping a simple health or auth endpoint to see if server is back
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/health'),
        ).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200 && _status != SyncStatus.connected && !_isConnecting) {
          debugPrint('Proactive Health Check: Server is UP. Reconnecting...');
          _reconnectAttempts = 0;
          _establishConnection();
        }
      } catch (_) {
        // Server still unreachable, continue loop
      }
    });
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _healthCheckTimer?.cancel();
    disconnect();
    super.dispose();
  }
}


