import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../data/mock_data.dart';

class TradePreviewSyncScreen extends StatelessWidget {
  const TradePreviewSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTradeHeader(context),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Syncing to 5 Slaves'),
            const SizedBox(height: 16),
            _buildSlaveList(context),
            const SizedBox(height: 32),
            _buildWarningCard(),
            const SizedBox(height: 48),
            GradientButton(
              label: 'Confirm & Execute Sync',
              onPressed: () => context.pushReplacement('/trade/execution'),
              startColor: AppColors.primary,
              endColor: AppColors.primaryDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeHeader(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MASTER TRADE', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.textMuted)),
                  Text('BTC/USDT', style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const StatusBadge(label: 'MARKET BUY', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 20),
          const AppDivider(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLargeStat(context, 'Total Size', '0.50 BTC'),
              _buildLargeStat(context, 'Est. Master Cost', '\$21,450'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildSlaveList(BuildContext context) {
    return Column(
      children: MockData.slaveAccounts.map((slave) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 16),
              const SizedBox(width: 12),
              Text(slave.exchangeName, style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                'Size: ${slave.lotSizeMode == LotSizeMode.fixed ? slave.defaultLotSize : '${slave.defaultLotSize}%'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _buildWarningCard() {
    return AppCard(
      color: AppColors.danger.withOpacity(0.05),
      border: Border.all(color: AppColors.danger.withOpacity(0.2)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Trade execution is near-instant. Ensure your slave API keys have sufficient permissions.',
              style: TextStyle(color: AppColors.danger.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
