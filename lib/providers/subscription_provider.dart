import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_sync/providers/sync_provider.dart';

enum SubscriptionPlan { free, basic, pro }

class SubscriptionProvider with ChangeNotifier {
  SubscriptionPlan _plan = SubscriptionPlan.free;
  DateTime? _expiry;
  bool _isExpired = false;
  bool _isAdmin = false; 
  bool _isDebugOverride = false;

  SubscriptionPlan get plan => _plan;
  DateTime? get expiry => _expiry;
  bool get isExpired => _isExpired;
  bool get isAdmin => _isAdmin;

  void setPlanOverride(SubscriptionPlan newPlan) {
    if (!_isAdmin) return; // Secure check
    _plan = newPlan;
    _isExpired = false; 
    _isDebugOverride = true; // Block backend updates during testing
    notifyListeners();
  }

  void setIsAdmin(bool value) {
    _isAdmin = value;
    notifyListeners();
  }

  void toggleExpiredOverride() {
    _isExpired = !_isExpired;
    _isDebugOverride = true;
    notifyListeners();
  }

  void updateSubscription({
    required String planStr,
    required double expiryTimestamp,
    required bool isExpired,
  }) {
    if (_isDebugOverride) return; // Prevent overwriting debug settings
    
    switch (planStr.toLowerCase()) {
      case 'basic':
        _plan = SubscriptionPlan.basic;
        break;
      case 'pro':
        _plan = SubscriptionPlan.pro;
        break;
      default:
        _plan = SubscriptionPlan.free;
    }
    _expiry = DateTime.fromMillisecondsSinceEpoch((expiryTimestamp * 1000).toInt());
    _isExpired = isExpired;
    notifyListeners();
  }

  int get investorLimit {
    switch (_plan) {
      case SubscriptionPlan.free:
        return 1;
      case SubscriptionPlan.basic:
        return 5;
      case SubscriptionPlan.pro:
        return 10; // Updated to 10 as per latest documentation
    }
  }

  String get planName {
    return _plan.name.toUpperCase();
  }
}

