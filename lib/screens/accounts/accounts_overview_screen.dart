import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/widgets/sync_status_pill.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';
import 'package:crypto_sync/screens/accounts/add_account_screen.dart';

class AccountsOverviewScreen extends StatelessWidget {
  const AccountsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    context.watch<SubscriptionProvider>();

    final master = syncProvider.accounts.cast<Map?>().firstWhere(
          (a) => a != null && a['type'] == 'master',
          orElse: () => null,
        );

    final investors = syncProvider.accounts.where((a) {
      if (a is! Map) return false;
      final type = a['type']?.toString().toLowerCase();
      return type == 'investor';
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: SyncStatusPill(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => syncProvider.fetchAccounts(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // ── MASTER SECTION ───────────────────────────────────────
            _label(context, 'MASTER ACCOUNT'),
            const SizedBox(height: 10),

            if (master == null)
              _AddButton(
                label: 'Add Master Account',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const AddAccountScreen(accountType: 'master'))),
              )
            else
              _MasterTile(
                master: Map<String, dynamic>.from(master),
                syncProvider: syncProvider,
              ),

            const SizedBox(height: 32),

            // ── INVESTORS SECTION ───────────────────────────────────────
            Row(
              children: [
                Expanded(child: _label(context, 'INVESTOR ACCOUNTS')),
                if (master != null)
                  TextButton.icon(
                    onPressed: () => context.push('/accounts/add'),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // If no master, show locked investor prompt
            if (master == null)
              _LockedTile(
                message: 'Set up a Master Account first before adding investors.',
              )
            else if (investors.isEmpty && !syncProvider.isFetchingAccounts)
              _AddButton(
                label: 'Add Investor Account',
                onTap: () => context.push('/accounts/add'),
              )
            else if (syncProvider.isFetchingAccounts && investors.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else
              ...investors.asMap().entries.map((e) {
                final idx = e.key;
                final investor = Map<String, dynamic>.from(e.value as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InvestorTile(
                    investor: investor,
                    syncProvider: syncProvider,
                    index: idx,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ADD BUTTON — large centered + button shown when no account exists
// ─────────────────────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: AppColors.primary.withOpacity(0.1),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
        begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

// ─────────────────────────────────────────────────────────────────
// LOCKED TILE — investor section locked until master is set
// ─────────────────────────────────────────────────────────────────
class _LockedTile extends StatelessWidget {
  final String message;
  const _LockedTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.textMuted.withOpacity(0.06),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// MASTER TILE — shown once master is configured
// ─────────────────────────────────────────────────────────────────
class _MasterTile extends StatelessWidget {
  final Map<String, dynamic> master;
  final SyncProvider syncProvider;

  const _MasterTile({required this.master, required this.syncProvider});

  @override
  Widget build(BuildContext context) {
    final masterId = master['id'];
    final exchangeName = master['exchange']?.toString() ?? 'Exchange';
    final accountName = master['name']?.toString() ?? exchangeName;
    final String tradeType = master['trade_type']?.toString().toUpperCase() ?? 'SPOT';

    return AppCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ExchangeAvatar(
                exchangeName: exchangeName,
                logo: exchangeName[0].toUpperCase(),
                size: 44,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
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
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const StatusBadge(
                        label: 'MASTER',
                        color: AppColors.primary,
                        small: true,
                        glow: true),
                  ],
                ),
                const SizedBox(height: 5),
                StatusBadge(
                    label: tradeType,
                    color: AppColors.primary.withOpacity(0.8),
                    small: true),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded,
                    size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddAccountScreen(accountId: masterId))),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () => context.push('/trade'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Text('Trade'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────
// INVESTOR TILE — shown for each configured investor account
// ─────────────────────────────────────────────────────────────────
class _InvestorTile extends StatelessWidget {
  final Map<String, dynamic> investor;
  final SyncProvider syncProvider;
  final int index;

  const _InvestorTile({
    required this.investor,
    required this.syncProvider,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final investorId = investor['id'];
    final exchangeName = investor['exchange']?.toString() ?? 'Exchange';
    final accountName = investor['name']?.toString() ?? exchangeName;
    final dynamic rawBal = syncProvider.balances[investorId] ?? investor['balance'];
    final double balance = (rawBal is num)
        ? rawBal.toDouble()
        : (double.tryParse(rawBal?.toString() ?? '0') ?? 0.0);
    final lotSize = investor['lot_size'] ?? '0.01';
    final lotMode = investor['lot_size_mode'] == 'percentage' ? '%' : 'L';
    final bool enabled = investor['enabled'] == 1 || investor['enabled'] == true;
    final bool isError = investor['sync_status']?.toString().toLowerCase() == 'error';
    final Color statusColor = isError 
        ? AppColors.danger 
        : (enabled ? AppColors.success : AppColors.textMuted);
    final bool isMaster = investor['type'] == 'master'; // Added for the color logic, though this tile is for investors

    return AppCard(
      onTap: () => context.push('/accounts/$investorId'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + status dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              ExchangeAvatar(
                  exchangeName: exchangeName,
                  logo: exchangeName[0].toUpperCase(),
                  size: 40),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    border: Border.all(
                        color: Theme.of(context).cardTheme.color ?? Colors.black,
                        width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Account info
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
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: !enabled ? AppColors.textSecondary : null,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isError) ...[
                      const SizedBox(width: 6),
                      StatusBadge(label: 'ERROR', color: AppColors.danger, small: true),
                    ] else if (!enabled) ...[
                      const SizedBox(width: 6),
                      StatusBadge(label: 'PAUSED', color: AppColors.syncPaused, small: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('·',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                    // Balance — flexible to prevent overflow
                    Flexible(
                      child: Text(
                        NumberFormat.currency(symbol: syncProvider.currencySymbol, decimalDigits: 2).format(balance),
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

          // Edit + Toggle
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Switch.adaptive(
                value: enabled,
                onChanged: (_) => syncProvider.toggleAccountSync(investorId),
                activeColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => AddAccountScreen(accountId: investorId)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'EDIT',
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'delayed': return Colors.amber;
      case 'error': return AppColors.danger;
      default: return AppColors.success;
    }
  }
}


