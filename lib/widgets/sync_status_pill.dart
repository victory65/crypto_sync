import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SyncStatusPill extends StatelessWidget {
  final String status;

  const SyncStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Active':
        color = AppColors.syncActive;
        break;
      case 'Delayed':
        color = AppColors.syncDelayed;
        break;
      case 'Paused':
        color = AppColors.syncPaused;
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
