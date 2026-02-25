import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/providers/settings_provider.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/core/api_config.dart';

class Verify2FALoginScreen extends StatefulWidget {
  final String tempToken;
  final String userId;

  const Verify2FALoginScreen({
    super.key,
    required this.tempToken,
    required this.userId,
  });

  @override
  State<Verify2FALoginScreen> createState() => _Verify2FALoginScreenState();
}

class _Verify2FALoginScreenState extends State<Verify2FALoginScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleVerify() async {
    if (_otpController.text.length < 6) return;

    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login/verify-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'temp_token': widget.tempToken,
          'code': _otpController.text,
          'device': 'Mobile Device', // In production, get actual device info
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final name = data['name'];
        final email = data['email'];
        final phone = data['phone'];
        final isAdmin = data['is_admin'] ?? false;

        if (mounted) {
          final syncProvider = context.read<SyncProvider>();
          final settingsProvider = context.read<SettingsProvider>();
          
          await settingsProvider.setTwoFactorEnabled(true);
          
          await syncProvider.connect(
            widget.userId, 
            token, 
            subProvider: context.read<SubscriptionProvider>(),
            userName: name,
            userEmail: email,
            userPhone: phone,
            isAdmin: isAdmin,
          );
          
          if (mounted) context.go('/');
        }
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Invalid code';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.danger),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2FA Verification')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Enter Verification Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enter the 6-digit code from your authenticator app to authorize this login.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _otpController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
                onChanged: (val) {
                  if (val.length == 6) _handleVerify();
                },
              ),
              const SizedBox(height: 48),
              GradientButton(
                label: _isLoading ? 'Verifying...' : 'Verify & Login',
                onPressed: _isLoading ? null : _handleVerify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

