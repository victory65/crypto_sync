import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/providers/settings_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/core/api_config.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _isSettingUp = false;
  String? _qrCodeBase64;
  String? _secret;
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _startSetup() async {
    setState(() => _isLoading = true);
    final userId = context.read<SyncProvider>().lastUserId;
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/2fa/setup?user_id=$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _qrCodeBase64 = data['qr_code'];
          _secret = data['secret'];
          _isSettingUp = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndEnable() async {
    if (_otpController.text.length < 6) return;
    
    setState(() => _isLoading = true);
    final userId = context.read<SyncProvider>().lastUserId;
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/2fa/enable?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'secret': _secret,
          'code': _otpController.text,
        }),
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          context.read<SettingsProvider>().setTwoFactorEnabled(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2FA Enabled Successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Invalid verification code');
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
         );
         setState(() => _isLoading = false);
       }
    }
  }

  Future<void> _disable2FA() async {
    setState(() => _isLoading = true);
    final userId = context.read<SyncProvider>().lastUserId;
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/2fa/disable?user_id=$userId'),
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          context.read<SettingsProvider>().setTwoFactorEnabled(false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2FA Disabled Successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to disable 2FA');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Factor Authentication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: settings.isTwoFactorEnabled 
          ? _buildEnabledState() 
          : _isSettingUp ? _buildSetupState() : _buildDisabledState(),
      ),
    );
  }

  Widget _buildDisabledState() {
    return Column(
      children: [
        const Icon(Icons.vibration, size: 80, color: AppColors.textMuted),
        const SizedBox(height: 24),
        const Text(
          'Secure your account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '2FA adds an extra layer of security to your account by requiring a code from an authenticator app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 48),
        GradientButton(
          label: _isLoading ? 'Loading...' : 'Set Up 2FA',
          onPressed: _isLoading ? null : _startSetup,
        ),
      ],
    );
  }

  Widget _buildSetupState() {
    return Column(
      children: [
        const Text('Step 1: Scan this QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Image.memory(base64Decode(_qrCodeBase64!), width: 200, height: 200),
          ),
        const SizedBox(height: 24),
        if (_secret != null) ...[
          const Text('OR enter this code manually:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _secret!,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _secret!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Secret key copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        const Text('Step 2: Enter the 6-digit code from your app', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: '000000'),
        ),
        const SizedBox(height: 32),
        GradientButton(
          label: _isLoading ? 'Verifying...' : 'Verify & Enable',
          onPressed: _isLoading ? null : _verifyAndEnable,
        ),
      ],
    );
  }

  Widget _buildEnabledState() {
    return Column(
      children: [
        const Icon(Icons.verified_user, size: 80, color: AppColors.success),
        const SizedBox(height: 24),
        const Text('2FA is Active', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 48),
        const AppCard(
          padding: EdgeInsets.all(16),
          child: Text(
            'Keep your device secure. If you lose access to your authenticator app, you will need to contact support to recover your account.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _isLoading ? null : _disable2FA,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(_isLoading ? 'Processing...' : 'Disable 2FA'),
        ),
      ],
    );
  }
}

