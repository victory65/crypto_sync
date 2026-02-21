import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      context.go('/login');
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
            Container(
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
                ),
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
}
