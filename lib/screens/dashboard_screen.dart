import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sync_status_pill.dart';
// Removed redundant mock_data.dart import
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../providers/subscription_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final activePositions = syncProvider.currentPositions.values.toList();
    final logs = syncProvider.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SyncStatusPill(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: syncProvider.isOnline ? () => context.push('/trade') : null,
        label: Text(syncProvider.isOnline ? 'Manual Trade' : 'Offline'),
        icon: Icon(syncProvider.isOnline ? Icons.add_chart : Icons.cloud_off),
        backgroundColor: syncProvider.isOnline ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5),
      ),
      body: Column(
        children: [
          if (subProvider.isExpired)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppColors.danger.withOpacity(0.9),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Sync paused – subscription expired.',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await syncProvider.syncSubscriptionState(subProvider);
                return Future.delayed(const Duration(seconds: 1));
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPortfolioOverview(context, syncProvider, subProvider),
                    const SizedBox(height: 32),
                    const SectionHeader(
                      title: 'Live Protocol Feed',
                    ),
                    const SizedBox(height: 16),
                    _buildLiveLogs(context, logs),
                    const SizedBox(height: 32),
                    SectionHeader(
                      title: 'Connected Accounts',
                      actionLabel: 'View All',
                      onActionTap: () => context.go('/accounts'),
                    ),
                    const SizedBox(height: 16),
                    _buildAccountsPreview(context, syncProvider),
                    const SizedBox(height: 32),
                    SectionHeader(
                      title: 'Active Positions',
                      actionLabel: 'View All',
                      onActionTap: () => context.go('/positions'),
                    ),
                    const SizedBox(height: 16),
                    _buildActivePositions(context, activePositions.take(3).map((item) => Map<String, dynamic>.from(item as Map)).toList()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioOverview(BuildContext context, SyncProvider syncProvider, SubscriptionProvider subProvider) {
    final double masterBalance = syncProvider.balances['master']?.toDouble() ?? 0.0;
    final double slavesBalance = syncProvider.balances['slaves_total']?.toDouble() ?? 0.0;
    final totalBalance = masterBalance + slavesBalance;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Sparkline Decoration
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Opacity(
              opacity: 0.1,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: SizedBox(
                  height: 60,
                  child: CustomPaint(
                    painter: _SparklinePainter(color: AppColors.success),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'TOTAL COMBINED BALANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAnimatedPulseStatus(syncProvider.status, subProvider),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onLongPress: subProvider.isAdmin ? () => _showAdminDebugMenu(context, subProvider) : null,
                  behavior: HitTestBehavior.translucent,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              syncProvider.currencySymbol,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 24,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalBalance.toStringAsFixed(2).split('.')[0],
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    fontSize: 42,
                                  ),
                            ),
                            Text(
                              '.${totalBalance.toStringAsFixed(2).split('.')[1]}',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                                    fontSize: 24,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.trending_up, color: AppColors.success, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${syncProvider.portfolioChangePercent >= 0 ? '+' : ''}${syncProvider.portfolioChangePercent.toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(onPlay: (p) => subProvider.isAdmin ? p.repeat(reverse: true) : p.stop()).custom(
                   builder: (context, value, child) {
                     if (!subProvider.isAdmin) return child;
                     return child.animate().shimmer(
                        duration: 5.seconds,
                        color: AppColors.primary.withOpacity(0.1),
                     );
                   }
                ),
                const SizedBox(height: 24),
                const AppDivider(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceMetric(
                        context,
                        'MASTER',
                        '${syncProvider.currencySymbol}${masterBalance.toStringAsFixed(2)}',
                        AppColors.primary,
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                    Expanded(
                      child: _buildBalanceMetric(
                        context,
                        'SLAVES',
                        '${syncProvider.currencySymbol}${slavesBalance.toStringAsFixed(2)}',
                        AppColors.success,
                        Icons.group_work_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildAnimatedPulseStatus(SyncStatus status, SubscriptionProvider subProvider) {
    final isConnected = status == SyncStatus.connected;
    final isExpired = subProvider.isExpired;
    final color = (isConnected && !isExpired) ? AppColors.success : (isExpired ? AppColors.warning : AppColors.textMuted.withOpacity(0.5));
    final label = (isConnected && !isExpired) 
      ? 'LIVE SYNC'
      : (isExpired ? 'SYNC PAUSED: EXPIRED' : 'SYNC PAUSED');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnected)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ).animate(onPlay: (p) => p.repeat()).custom(
              duration: 1000.ms,
              builder: (context, value, child) => Opacity(
                opacity: 0.3 + (value * 0.7),
                child: child,
              ),
            ).scale(
              begin: const Offset(1, 1),
              end: const Offset(1.2, 1.2),
              curve: Curves.easeInOut,
            )
          else
            Icon(Icons.pause_circle_filled_outlined, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ).animate(onPlay: (p) => isConnected ? p.repeat(reverse: true) : p.stop()).shimmer(
            duration: 2.seconds,
            color: color.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceMetric(BuildContext context, String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLogs(BuildContext context, List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Waiting for system events...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5)),
          ),
        ),
      );
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: logs.length,
        separatorBuilder: (context, index) => Divider(height: 12, color: Theme.of(context).dividerColor.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final log = logs[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[${log['timestamp'].toString().substring(11, 16)}]',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                  fontSize: 10,
                  fontFamily: 'Courier',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log['message'],
                  style: TextStyle(
                    color: log['isError'] == true 
                      ? AppColors.danger 
                      : (log['isSuccess'] == true ? AppColors.success : Theme.of(context).textTheme.bodyMedium?.color),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountsPreview(BuildContext context, SyncProvider syncProvider) {
    final master = syncProvider.accounts.firstWhere(
      (a) => a is Map && (a['type'] == 'master' || a['id'] == 'master'),
      orElse: () => null,
    );
    final slaves = syncProvider.accounts.where((a) {
      if (a is! Map) return false;
      final type = a['type']?.toString().toLowerCase();
      final id = a['id']?.toString().toLowerCase();
      return type == 'slave' || (type == null && id != 'master');
    }).take(2).toList();

    if (master == null && slaves.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.account_balance_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text('No accounts connected'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/accounts'),
                child: const Text('Connect Exchange'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (master != null) ...[
          _buildAccountCard(context, master as Map<String, dynamic>, syncProvider, isMaster: true),
          const SizedBox(height: 12),
        ],
        ...slaves.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildAccountCard(context, s as Map<String, dynamic>, syncProvider),
        )),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildAccountCard(BuildContext context, Map<String, dynamic> account, SyncProvider syncProvider, {bool isMaster = false}) {
    final accountId = account['id'];
    final exchangeName = account['exchange']?.toString() ?? 'Exchange';
    final accountName = account['name']?.toString() ?? exchangeName;
    final dynamic rawBal = syncProvider.balances[accountId] ?? account['balance'];
    final double balance = (rawBal is num)
        ? rawBal.toDouble()
        : (double.tryParse(rawBal?.toString() ?? '0') ?? 0.0);
    
    final lotSize = account['lot_size'] ?? '0.01';
    final lotMode = account['lot_size_mode'] == 'percentage' ? '%' : 'L';
    final bool enabled = account['enabled'] ?? false;
    final bool isError = account['sync_status']?.toString().toLowerCase() == 'error';
    final Color statusColor = isMaster 
        ? AppColors.primary 
        : (isError ? AppColors.danger : (enabled ? AppColors.success : AppColors.textMuted));

    return AppCard(
      onTap: () => context.push(isMaster ? '/accounts' : '/accounts/$accountId'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: Border.all(
        color: statusColor.withOpacity(0.2),
        width: 1,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ExchangeAvatar(
                exchangeName: exchangeName,
                logo: exchangeName[0].toUpperCase(),
                size: 42,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    border: Border.all(
                      color: Theme.of(context).cardTheme.color ?? Colors.black,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        accountName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: !enabled && !isMaster ? AppColors.textSecondary : null,
                            ),
                      ),
                    ),
                    if (isMaster) ...[
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: 'MASTER', 
                        color: AppColors.primary, 
                        small: true, 
                        glow: true,
                      ),
                    ] else if (isError) ...[
                      const SizedBox(width: 8),
                      StatusBadge(label: 'ERROR', color: AppColors.danger, small: true),
                    ] else if (!enabled) ...[
                      const SizedBox(width: 8),
                      StatusBadge(label: 'PAUSED', color: AppColors.syncPaused, small: true),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$lotSize$lotMode',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('·', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                    Flexible(
                      child: Text(
                        '${syncProvider.currencySymbol}${balance.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: isError ? AppColors.danger : (enabled || isMaster ? AppColors.success : AppColors.textMuted),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMaster)
            Switch.adaptive(
              value: enabled,
              onChanged: (val) => syncProvider.toggleAccountSync(accountId),
              activeColor: AppColors.success,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          else
            Icon(Icons.chevron_right, color: AppColors.primary.withOpacity(0.5)),
        ],
      ),
    );
  }


  Color _slaveStatusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'delayed': return Colors.amber;
      case 'error': return AppColors.danger;
      default: return AppColors.success;
    }
  }

  Widget _buildActivePositions(BuildContext context, List<Map<String, dynamic>> positions) {
    if (positions.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.query_stats, size: 48, color: AppColors.textMuted.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text('No active master trades detected'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: positions.where((p) => p is Map).map((pos) {
        final slaves = (pos as Map)['slaves'] as Map<String, dynamic>? ?? {};
        final syncedCount = slaves.values.where((s) => s['status'] == 'filled').length;
        final totalCount = slaves.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            onTap: () => context.push('/positions/${pos['id']}'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pos['symbol'],
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: (pos['side'] as String).toUpperCase(),
                            color: pos['side'] == 'buy'
                                ? AppColors.success
                                : AppColors.danger,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mirroring to $syncedCount/$totalCount Slaves',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.sync, color: AppColors.primary, size: 16).animate(
                  onPlay: (controller) => controller.repeat(),
                ).rotate(duration: 2.seconds),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAdminDebugMenu(BuildContext context, SubscriptionProvider subProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    'ADMIN DEBUG: TIER TESTING',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Switch between tiers to verify slave limits and UI behavior.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 24),
              _buildDebugTierItem(context, 'Trial (FREE)', 'Limit: 1 Slave', SubscriptionPlan.free, subProvider),
              const SizedBox(height: 12),
              _buildDebugTierItem(context, 'Basic TIER', 'Limit: 5 Slaves', SubscriptionPlan.basic, subProvider),
              const SizedBox(height: 12),
              _buildDebugTierItem(context, 'Professional', 'Limit: 100+ Slaves', SubscriptionPlan.pro, subProvider),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              _buildDebugActionItem(context, 'Toggle Expired Status', 
                subProvider.isExpired ? 'Currently: EXPIRED' : 'Currently: ACTIVE', 
                subProvider.isExpired ? Icons.check_circle : Icons.error_outline,
                subProvider.isExpired ? AppColors.success : AppColors.danger,
                () => subProvider.toggleExpiredOverride()
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugActionItem(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        context.read<SyncProvider>().addCustomLog('Admin', 'Debug action executed: $title', isSuccess: true);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEBUG: $title executed')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugTierItem(BuildContext context, String title, String subtitle, SubscriptionPlan plan, SubscriptionProvider subProvider) {
    final isSelected = subProvider.plan == plan;
    return GestureDetector(
      onTap: () {
        subProvider.setPlanOverride(plan);
        context.read<SyncProvider>().addCustomLog('Admin', 'Tier override: ${plan.name.toUpperCase()}', isSuccess: true);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEBUG: Plan switched to ${plan.name.toUpperCase()}')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? AppColors.primary : Colors.white24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.2, size.height * 0.4, size.width * 0.4, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.6, size.height * 0.8, size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
