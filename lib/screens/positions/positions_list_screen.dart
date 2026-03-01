import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/widgets/sync_status_pill.dart';
// Redundant mock_data import removed

import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/sync_provider.dart';

class PositionsListScreen extends StatelessWidget {
  const PositionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    
    final displayPositions = syncProvider.currentPositions.values
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Positions'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SyncStatusPill(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: displayPositions.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.query_stats, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('No active master trades detected', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Start a trade on your master account to see mirroring.', 
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  itemCount: displayPositions.length,
                  itemBuilder: (context, index) {
                final pos = displayPositions[index];
                
                // Calculate investor status
                final investors = Map<String, dynamic>.from(pos['investors'] ?? {});
                final syncedInvestors = investors.values.where((s) => s['status'] == 'filled').length;
                final totalInvestors = (pos['total_investors'] ?? pos['totalInvestors'] ?? (investors.isEmpty ? 0 : investors.length));
                final failedInvestors = investors.values.where((s) => s['status'] == 'failed').length;
                final isRetrying = investors.values.any((s) => s['status'] == 'retrying');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: AppCard(
                    onTap: () => context.push('/positions/${pos['id']}'),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      pos['symbol'],
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(
                                      label: (pos['side'] as String).toUpperCase(),
                                      color: pos['side'] == 'buy'
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                    if (isRetrying) ...[
                                      const SizedBox(width: 8),
                                      const StatusBadge(
                                        label: 'RETRYING',
                                        color: AppColors.warning,
                                      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Master Size: '),
                                    Text(
                                      '${pos['master_size'] ?? pos['masterSize'] ?? '0'} ${pos['symbol'].split('/')[0]}',
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            PnlText(
                              pnl: pos['pnl'] ?? 0.0, 
                              pnlPercent: pos['pnlPercent'] ?? 0.0
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const AppDivider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(context, 'Entry', (pos['entryPrice'] ?? 0.0).toStringAsFixed(2)),
                            _buildInfoItem(context, 'Current', (pos['currentPrice'] ?? 0.0).toStringAsFixed(2)),
                            _buildInfoItem(
                              context,
                              'Investors',
                              '$syncedInvestors/$totalInvestors',
                              trailing: Icon(
                                Icons.circle,
                                size: 8,
                                color: failedInvestors > 0
                                    ? AppColors.danger
                                    : (isRetrying ? AppColors.warning : AppColors.success),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms, duration: 400.ms).slideX(begin: 0.05, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ],
    );
  }
}


