import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/models/trade_models.dart';

import 'package:crypto_sync/theme/app_colors.dart';

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
            const SectionHeader(title: 'Investor Execution Details'),
            const SizedBox(height: 16),
            _buildInvestorExecutions(context, Map<String, dynamic>.from(pos['investors'] as Map? ?? {})),
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
          if (pos['master_status'] != 'closed') ...[
            const SizedBox(height: 32),
            GradientButton(
              label: pos['master_status'] == 'closing' ? 'Closing...' : 'Close Position',
              onPressed: pos['master_status'] == 'closing' ? null : () => _showCloseConfirmation(context, pos, syncProvider),
              startColor: AppColors.danger,
              endColor: AppColors.danger.withOpacity(0.8),
              icon: pos['master_status'] == 'closing' ? null : Icons.close,
            ),
          ],
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  void _showCloseConfirmation(BuildContext context, Map<String, dynamic> pos, SyncProvider syncProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Close Position?'),
        content: Text('This will execute a market ${pos['side'] == 'buy' ? 'sell' : 'buy'} order on your master account and mirror it to all active investors.\n\nAre you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await syncProvider.closePosition(pos);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Close command sent to protocol')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to close: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Execute Close'),
          ),
        ],
      ),
    );
  }

  int _calculateSyncProgress(Map<String, dynamic> pos) {
    final investorsData = pos['investors'] ?? {};
    final investors = Map<String, dynamic>.from(investorsData is Map ? investorsData : {});
    if (investors.isEmpty) return 0;
    final filled = investors.values.where((s) => s['status'] == 'filled').length;
    return (filled / investors.length * 100).toInt();
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

  Widget _buildInvestorExecutions(BuildContext context, Map<String, dynamic> investors) {
    if (investors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No investor updates yet', style: TextStyle(color: Theme.of(context).disabledColor)),
        ),
      );
    }

    return Column(
      children: investors.entries.map((entry) {
        final investorId = entry.key;
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
                        data['exchange'] ?? investorId,
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


