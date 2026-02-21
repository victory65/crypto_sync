import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sync_status_pill.dart';
import '../data/mock_data.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SyncStatusPill(status: 'Active'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trade'),
        label: const Text('Manual Trade'),
        icon: const Icon(Icons.add_chart),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPortfolioOverview(context),
            const SizedBox(height: 32),
            const SectionHeader(
              title: 'Mirroring Status',
              actionLabel: 'View All',
            ),
            const SizedBox(height: 16),
            _buildMirroringToggles(context),
            const SizedBox(height: 32),
            const SectionHeader(
              title: 'Active Positions',
              actionLabel: 'Details',
            ),
            const SizedBox(height: 16),
            _buildActivePositions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioOverview(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border, width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Combined Balance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${MockData.totalCombinedBalance.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: AppColors.success, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${MockData.portfolioChange24h}%',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AppDivider(),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildBalanceSmallItem(
                context,
                'Master Wallet',
                '\$${MockData.masterBalance.toStringAsFixed(2)}',
                AppColors.primary,
              ),
              const Spacer(),
              _buildBalanceSmallItem(
                context,
                'Slave Wallets',
                '\$${MockData.slavesBalance.toStringAsFixed(2)}',
                AppColors.success,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBalanceSmallItem(
      BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildMirroringToggles(BuildContext context) {
    return Column(
      children: MockData.slaveAccounts.take(3).map((slave) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ExchangeAvatar(exchangeName: slave.exchangeName, logo: slave.exchangeLogo),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slave.exchangeName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        slave.tradeType == TradeType.futures ? 'Futures' : 'Spot',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: slave.syncEnabled,
                  onChanged: (val) {},
                ),
              ],
            ),
          ),
        );
      }).toList().animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0),
    );
  }

  Widget _buildActivePositions(BuildContext context) {
    return Column(
      children: MockData.positions.map((pos) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            onTap: () {},
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pos.assetPair,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: pos.side == TradeSide.buy ? 'BUY' : 'SELL',
                            color: pos.side == TradeSide.buy
                                ? AppColors.success
                                : AppColors.danger,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mirroring to ${pos.syncedSlaves}/${pos.totalSlaves} Slaves',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PnlText(pnl: pos.pnl, pnlPercent: pos.pnlPercent),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      }).toList().animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }
}
