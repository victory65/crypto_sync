import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sync_status_pill.dart';
import '../../data/mock_data.dart';

class AccountsOverviewScreen extends StatelessWidget {
  const AccountsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SyncStatusPill(status: 'Active'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Master Account'),
            const SizedBox(height: 16),
            _buildMasterAccount(context),
            const SizedBox(height: 32),
            SectionHeader(
              title: 'Mirroring Slaves (${MockData.slaveAccounts.length})',
              actionLabel: 'Add New',
              onAction: () => context.push('/accounts/add'),
            ),
            const SizedBox(height: 16),
            _buildSlaveAccounts(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterAccount(BuildContext context) {
    final master = MockData.masterAccount;
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.primary.withOpacity(0.05),
      border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      child: Row(
        children: [
          ExchangeAvatar(exchangeName: master.exchangeName, logo: master.exchangeLogo, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  master.exchangeName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Connected as Master',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const StatusBadge(label: 'MASTER', color: AppColors.primary),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.05, end: 0);
  }

  Widget _buildSlaveAccounts(BuildContext context) {
    return Column(
      children: MockData.slaveAccounts.map((slave) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            onTap: () => context.push('/accounts/${slave.id}'),
            padding: const EdgeInsets.all(16),
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
                        '\$${slave.balance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: slave.syncStatus.name.toUpperCase(),
                      color: _getStatusColor(slave.syncStatus),
                      small: true,
                    ),
                    const SizedBox(height: 4),
                    Switch.adaptive(
                      value: slave.syncEnabled,
                      onChanged: (val) {},
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList().animate(interval: 50.ms).fadeIn().slideY(begin: 0.05, end: 0),
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.active:
        return AppColors.success;
      case SyncStatus.delayed:
        return AppColors.warning;
      case SyncStatus.paused:
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }
}
