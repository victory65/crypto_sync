import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';

class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final status = syncProvider.status;
    final engineStatus = syncProvider.engineStatus;

    Color color;
    String label;

    if (status == SyncStatus.connected) {
      color = AppColors.success;
      label = 'ONLINE';
    } else {
      color = AppColors.danger;
      label = 'OFFLINE';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusBadge(context, label, color),
        const SizedBox(width: 8),
        _buildSubscriptionBadge(context),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBadge(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final isExpired = subProvider.isExpired;
    final color = isExpired ? AppColors.danger : AppColors.success;
    final label = isExpired ? 'EXPIRED' : 'ACTIVATED: ${subProvider.planName}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

