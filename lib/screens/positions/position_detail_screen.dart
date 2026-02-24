import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../models/trade_models.dart';

import '../../theme/app_colors.dart';

class PositionDetailScreen extends StatelessWidget {
  final String positionId;

  const PositionDetailScreen({super.key, required this.positionId});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    
    // Find live position
    final Map<String, dynamic>? pos = syncProvider.currentPositions[positionId] != null 
        ? Map<String, dynamic>.from(syncProvider.currentPositions[positionId] as Map) 
        : null;
    
    if (pos == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Position Details')),
        body: const Center(child: Text('Position no longer active')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pos['symbol']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMasterHeader(context, pos, syncProvider),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Slave Execution Details'),
            const SizedBox(height: 16),
            _buildSlaveExecutions(context, Map<String, dynamic>.from(pos['slaves'] as Map? ?? {})),
          ],
        ),
      ),
    );
  }



  Widget _buildMasterHeader(BuildContext context, Map<String, dynamic> pos, SyncProvider syncProvider) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label: (pos['side'] as String).toUpperCase(),
                    color: pos['side'] == 'buy' ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Entry: \$${pos['entryPrice']}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              PnlText(pnl: pos['pnl'] ?? 0.0, pnlPercent: pos['pnlPercent'] ?? 0.0),
            ],
          ),
          const SizedBox(height: 24),
          const AppDivider(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, 'Quantity', '${pos['master_size'] ?? pos['masterSize'] ?? '0'}'),
              _buildStatItem(context, 'Current Price', '${syncProvider.currencySymbol}${pos['currentPrice'] ?? '0'}'),
              _buildStatItem(context, 'Sync Progress', '${_calculateSyncProgress(pos)}%'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  int _calculateSyncProgress(Map<String, dynamic> pos) {
    final slaves = pos['slaves'] as Map<String, dynamic>? ?? {};
    if (slaves.isEmpty) return 0;
    final filled = slaves.values.where((s) => s['status'] == 'filled').length;
    return (filled / slaves.length * 100).toInt();
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSlaveExecutions(BuildContext context, Map<String, dynamic> slaves) {
    if (slaves.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No slave updates yet', style: TextStyle(color: Theme.of(context).disabledColor)),
        ),
      );
    }

    return Column(
      children: slaves.entries.map((entry) {
        final slaveId = entry.key;
        final data = entry.value;
        final status = data['status'] as String;
        final attempt = data['attempt'] ?? 1;

        Color statusColor;
        switch (status) {
          case 'filled':
            statusColor = AppColors.success;
            break;
          case 'retrying':
            statusColor = AppColors.warning;
            break;
          case 'failed':
            statusColor = AppColors.danger;
            break;
          default:
            statusColor = AppColors.textMuted;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['exchange'] ?? slaveId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${data['size'] ?? 'Auto'} | Attempt: $attempt',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: status.toUpperCase(),
                      color: statusColor,
                      small: true,
                    ).animate(target: status == 'retrying' ? 1 : 0).shimmer(),
                    if (data['reason'] != null) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        child: Text(
                          data['reason']!,
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
