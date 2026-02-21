import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sync_status_pill.dart';
import '../../data/mock_data.dart';

class PositionsListScreen extends StatelessWidget {
  const PositionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Positions'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SyncStatusPill(status: 'Active'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search pairs (e.g. BTC/USDT)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: MockData.positions.length,
              itemBuilder: (context, index) {
                final pos = MockData.positions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: AppCard(
                    onTap: () => context.push('/positions/${pos.id}'),
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
                                      pos.assetPair,
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(
                                      label: pos.side == TradeSide.buy ? 'LONG' : 'SHORT',
                                      color: pos.side == TradeSide.buy
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Master Size: '),
                                    Text(
                                      '${pos.masterSize} ${pos.assetPair.split('/')[0]}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            PnlText(pnl: pos.pnl, pnlPercent: pos.pnlPercent),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const AppDivider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(context, 'Entry', pos.entryPrice.toStringAsFixed(2)),
                            _buildInfoItem(context, 'Current', pos.currentPrice.toStringAsFixed(2)),
                            _buildInfoItem(
                              context,
                              'Slaves',
                              '${pos.syncedSlaves}/${pos.totalSlaves}',
                              trailing: Icon(
                                Icons.circle,
                                size: 8,
                                color: pos.failedSlaves > 0
                                    ? AppColors.danger
                                    : AppColors.success,
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
                    color: AppColors.textPrimary,
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
