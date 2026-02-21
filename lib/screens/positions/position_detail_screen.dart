import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../data/mock_data.dart';

class PositionDetailScreen extends StatelessWidget {
  final String positionId;

  const PositionDetailScreen({super.key, required this.positionId});

  @override
  Widget build(BuildContext context) {
    final pos = MockData.positions.firstWhere(
      (p) => p.id == positionId,
      orElse: () => MockData.positions.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(pos.assetPair),
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
            _buildMasterHeader(context, pos),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Slave Execution Details'),
            const SizedBox(height: 16),
            _buildSlaveExecutions(context, pos),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterHeader(BuildContext context, Position pos) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border, width: 1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label: pos.side == TradeSide.buy ? 'LONG' : 'SHORT',
                    color: pos.side == TradeSide.buy ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Entry: \$${pos.entryPrice}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              PnlText(pnl: pos.pnl, pnlPercent: pos.pnlPercent),
            ],
          ),
          const SizedBox(height: 24),
          const AppDivider(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, 'Quantity', '${pos.masterSize}'),
              _buildStatItem(context, 'Current Price', '\$${pos.currentPrice}'),
              _buildStatItem(context, 'Sync Rate', '${(pos.syncedSlaves / pos.totalSlaves * 100).toInt()}%'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
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

  Widget _buildSlaveExecutions(BuildContext context, Position pos) {
    return Column(
      children: pos.slavePositions.map((slavePos) {
        Color statusColor;
        switch (slavePos.status) {
          case ExecutionStatus.filled:
            statusColor = AppColors.success;
            break;
          case ExecutionStatus.partial:
            statusColor = AppColors.warning;
            break;
          case ExecutionStatus.rejected:
          case ExecutionStatus.apiError:
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
                        slavePos.exchangeName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${slavePos.lotSizeUsed}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: slavePos.status.name.toUpperCase(),
                      color: statusColor,
                      small: true,
                    ),
                    if (slavePos.errorReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        slavePos.errorReason!,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList().animate(interval: 50.ms).fadeIn().slideY(begin: 0.1, end: 0),
    );
  }
}
