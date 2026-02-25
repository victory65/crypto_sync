import 'package:flutter/material.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _codeSent = false;
  bool _isLoading = false;

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulation
    setState(() {
      _codeSent = true;
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent to your email')),
      );
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.danger),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_codeSent) ...[
              const Text('To change your password, we first need to verify it\'s you. We will send a 6-digit code to your email.'),
              const SizedBox(height: 32),
              _buildLabel('Current Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: _isLoading ? 'Sending...' : 'Send Verification Code',
                onPressed: _isLoading ? null : _sendCode,
              ),
            ] else ...[
              const Text('Enter the code sent to your email and your new password.'),
              const SizedBox(height: 32),
              _buildLabel('Verification Code'),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.numbers)),
              ),
              const SizedBox(height: 24),
              _buildLabel('New Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 24),
              _buildLabel('Confirm New Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset)),
              ),
              const SizedBox(height: 48),
              GradientButton(
                label: _isLoading ? 'Updating...' : 'Update Password',
                onPressed: _isLoading ? null : _updatePassword,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
  }
}

