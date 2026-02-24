import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/sync_provider.dart';

class BotNexusScreen extends StatelessWidget {
  const BotNexusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('BOT NEXUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Futuristic Background
          _buildFuturisticBackground(),
          
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ).animate(onPlay: (p) => p.repeat(reverse: true)).scale(
                          duration: 2.seconds,
                          begin: const Offset(1, 1),
                          end: const Offset(1.1, 1.1),
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 40),
                    const Text(
                      'COMING SOON',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 16),
                    Text(
                      'The Nexus is currently being calibrated for our exclusive trading bots. Check back soon for the official release.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.7),
                        fontSize: 14,
                        letterSpacing: 0.5,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
                    const SizedBox(height: 48),
                    GradientButton(
                      label: 'Notify Me',
                      onPressed: () {
                        // Logic to join waitlist/notification
                      },
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuturisticBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B0F1A),
            Color(0xFF111827),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Glowing Orbs
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowOrb(AppColors.primary.withOpacity(0.15), 300),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _buildGlowOrb(AppColors.info.withOpacity(0.1), 250),
          ),
          // Subtle Grid
          Opacity(
            opacity: 0.05,
            child: CustomPaint(
              painter: _GridPainter(),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
