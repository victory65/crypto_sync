import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/sync_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _handleRouting();
  }

  Future<void> _handleRouting() async {
    // Keep minimum splash duration for brand visibility
    final delay = Future.delayed(const Duration(seconds: 3));
    
    final syncProvider = context.read<SyncProvider>();
    final subProvider = context.read<SubscriptionProvider>();
    final settings = context.read<SettingsProvider>();
    
    // Predetermin the route in the background
    final hasSession = await syncProvider.loadSession(subProvider: subProvider);
    
    await delay;

    if (!mounted) return;

    if (!hasSession) {
      context.go('/login');
    } else if (settings.isBiometricEnabled) {
      final success = await _biometricService.authenticate();
      if (success && mounted) {
        context.go('/');
      } else if (mounted) {
        // If biometric fails or cancelled, we still have to go to login or show lock
        // For simplicity during revert, we go to login to re-auth
        context.go('/login');
      }
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 24),
            Text(
              'CRYPTO SYNC',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.5, end: 0),
            const SizedBox(height: 8),
            Text(
              'Real-Time Trade Mirroring',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
            )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.sync,
        color: Colors.white,
        size: 60,
      ),
    )
        .animate()
        .scale(
          duration: 600.ms,
          curve: Curves.easeOutBack,
        )
        .rotate(
          duration: 1200.ms,
          begin: 0,
          end: 1,
          curve: Curves.easeInOutBack,
        );
  }
}
