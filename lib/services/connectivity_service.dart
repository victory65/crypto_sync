import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService with ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  ConnectivityService() {
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final List<ConnectivityResult> result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connectivity: $e');
      }
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // We consider the app "online" if there's any result other than .none
    final bool hasConnection = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    
    if (_isOnline != hasConnection) {
      // Debounce the change slightly to prevent flickering during rapid state transitions
      Future.delayed(const Duration(milliseconds: 500), () {
        // Re-check after delay to ensure the state is stable
        Connectivity().checkConnectivity().then((currentResults) {
          final bool stableHasConnection = currentResults.isNotEmpty && !currentResults.contains(ConnectivityResult.none);
          if (_isOnline != stableHasConnection) {
            _isOnline = stableHasConnection;
            notifyListeners();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
