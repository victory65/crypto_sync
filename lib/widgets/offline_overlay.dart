import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/services/connectivity_service.dart';

class OfflineOverlay extends StatelessWidget {
  final Widget child;

  const OfflineOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        return Stack(
          children: [
            child,
            if (!connectivity.isOnline)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.wifi_off_rounded,
                                color: Colors.redAccent,
                                size: 64,
                              ),
                            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds, curve: Curves.easeInOut)
                             .tint(color: Colors.red.withOpacity(0.5)),
                            const SizedBox(height: 32),
                            const Text(
                              'Connection Lost',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ).animate().fadeIn(delay: 200.ms).moveY(begin: 20, end: 0),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 48),
                              child: Text(
                                'Please check your internet connection. The app is disabled until connectivity is restored.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
                            const SizedBox(height: 48),
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                              strokeWidth: 2,
                            ).animate().fadeIn(delay: 600.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),
          ],
        );
      },
    );
  }
}

