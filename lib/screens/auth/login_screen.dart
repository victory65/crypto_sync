import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sync_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';
import '../../core/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoBiometric();
    });
  }

  Future<void> _checkAutoBiometric() async {
    final settings = context.read<SettingsProvider>();
    if (settings.isBiometricEnabled) {
      _handleBiometricLogin();
    }
  }

  Future<void> _handleBiometricLogin() async {
    final success = await _biometricService.authenticate();
    if (success && mounted) {
      // For demo, we just use the admin credentials
      _emailController.text = 'admin@crypto.sync';
      _passwordController.text = 'admin123';
      _handleLogin();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    debugPrint('Login process started for: ${_emailController.text}');
    
    try {
      debugPrint('Sending request to: ${ApiConfig.loginUrl}');
      // In production, use the actual backend URL from environment
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('Response received: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final userId = data['user_id'];
        final name = data['name'];
        final email = data['email'];
        final isAdmin = data['is_admin'] ?? false;

        // Initialize Real-Time Sync
        if (mounted) {
          debugPrint('Login successful. Initializing sync for user: $userId');
          final syncProvider = context.read<SyncProvider>();
          await syncProvider.connect(
            userId, 
            token, 
            subProvider: context.read<SubscriptionProvider>(),
            userName: name,
            userEmail: email,
            isAdmin: isAdmin,
          );
          syncProvider.addCustomLog('Auth', 'Login successful: ${_emailController.text}', isSuccess: true);
          debugPrint('Sync initialized. Navigating to home.');
          if (mounted) context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid credentials. Try admin@crypto.sync / admin123')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Login failed with error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Error: $e\nTarget: ${ApiConfig.loginUrl}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Retry', onPressed: _handleLogin),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Login to manage your mirroring accounts',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 48),
              Text(
                'Email Address',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'admin@crypto.sync',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              Text(
                'Password',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'admin123',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading 
                          ? const SizedBox(
                              height: 20, 
                              width: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            )
                          : const Text('Login'),
                    ),
                  ),
                  if (context.watch<SettingsProvider>().isBiometricEnabled) ...[
                    const SizedBox(width: 16),
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.fingerprint, color: AppColors.primary),
                        onPressed: _handleBiometricLogin,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Don\'t have an account? ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
