import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/models/account_models.dart';
import 'package:crypto_sync/models/trade_models.dart';

class InvestorDetailScreen extends StatefulWidget {
  final String investorId;

  const InvestorDetailScreen({super.key, required this.investorId});

  @override
  State<InvestorDetailScreen> createState() => _InvestorDetailScreenState();
}

class _InvestorDetailScreenState extends State<InvestorDetailScreen> {
  final _lotSizeController = TextEditingController();
  LotSizeMode _selectedLotSizeMode = LotSizeMode.fixed;
  TradeType _selectedTradeType = TradeType.spot;
  bool _isLoading = false;
  bool _isDataLoaded = false;

  @override
  void dispose() {
    _lotSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final account = syncProvider.accounts.cast<Map?>().firstWhere(
      (a) => a != null && a['id'] == widget.investorId,
      orElse: () => null,
    );

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Details')),
        body: const Center(child: Text('Account not found')),
      );
    }

    final investor = Map<String, dynamic>.from(account as Map);
    
    if (!_isDataLoaded) {
      _lotSizeController.text = (investor['lot_size'] ?? 0.01).toString();
      _selectedLotSizeMode = investor['lot_size_mode'] == 'percentage' ? LotSizeMode.percentage : LotSizeMode.fixed;
      final tt = investor['trade_type']?.toString().toLowerCase();
      if (tt == 'futures') {
        _selectedTradeType = TradeType.futures;
      } else if (tt == 'both') {
        _selectedTradeType = TradeType.both;
      } else {
        _selectedTradeType = TradeType.spot;
      }
      _isDataLoaded = true;
    }

    final dynamic rawBalance = syncProvider.balances[widget.investorId] ?? investor['balance'];
    final double balance = (rawBalance is num) ? rawBalance.toDouble() : (double.tryParse(rawBalance?.toString() ?? '0') ?? 0.0);
    final String exchangeName = investor['exchange']?.toString() ?? 'Exchange';

    return Scaffold(
      appBar: AppBar(
        title: Text('${exchangeName[0].toUpperCase()}${exchangeName.substring(1)} Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => syncProvider.fetchAccounts(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExchangeAvatar(
                  exchangeName: exchangeName, 
                  logo: exchangeName[0].toUpperCase(), 
                  size: 64
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        investor['name'] ?? exchangeName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      StatusBadge(
                        label: 'CONNECTED', 
                        color: AppColors.success,
                        small: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildBalanceCard(context, exchangeName, balance, syncProvider.currencySymbol),
            const SizedBox(height: 32),
            _buildSettingsList(context, investor, syncProvider),
            const SizedBox(height: 32),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Save Settings',
              onPressed: _isLoading ? null : () => _handleSave(syncProvider),
            ),
            const SizedBox(height: 40),
            _buildDangerZone(context, widget.investorId, syncProvider),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(SyncProvider syncProvider) async {
    setState(() => _isLoading = true);
    final success = await syncProvider.updateAccount(
      accountId: widget.investorId,
      lotSize: double.tryParse(_lotSizeController.text),
      lotSizeMode: _selectedLotSizeMode == LotSizeMode.percentage ? 'percentage' : 'fixed',
      tradeType: _selectedTradeType.name,
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    }
  }

  Widget _buildBalanceCard(BuildContext context, String exchange, double balance, String currency) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primary.withOpacity(0.05),
      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Balance', style: TextStyle(color: AppColors.primary.withOpacity(0.7), fontWeight: FontWeight.w600)),
              StatusBadge(label: exchange.toUpperCase(), color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currency${balance.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, Map<String, dynamic> investor, SyncProvider syncProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Enable Mirroring', style: TextStyle(fontWeight: FontWeight.bold)),
                  Switch.adaptive(
                    value: investor['enabled'] == 1 || investor['enabled'] == true,
                    onChanged: (val) => syncProvider.toggleAccountSync(widget.investorId),
                    activeColor: AppColors.success,
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text('Trade Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TradeType>(
                    segments: const [
                      ButtonSegment(value: TradeType.spot, label: Text('Spot'), icon: Icon(Icons.show_chart)),
                      ButtonSegment(value: TradeType.futures, label: Text('Futures'), icon: Icon(Icons.bolt)),
                      ButtonSegment(value: TradeType.both, label: Text('Both'), icon: Icon(Icons.all_inclusive)),
                    ],
                    selected: {_selectedTradeType},
                    onSelectionChanged: (Set<TradeType> selection) {
                      setState(() => _selectedTradeType = selection.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Lot Sizing', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'This size is used for every mirrored trade.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _lotSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        hintText: '0.01',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        suffixText: _selectedLotSizeMode == LotSizeMode.percentage ? '%' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: SegmentedButton<LotSizeMode>(
                      segments: const [
                        ButtonSegment(value: LotSizeMode.fixed, label: Text('FIXED'), icon: Icon(Icons.attach_money, size: 16)),
                        ButtonSegment(value: LotSizeMode.percentage, label: Text('% BAL'), icon: Icon(Icons.percent, size: 16)),
                      ],
                      selected: {_selectedLotSizeMode},
                      onSelectionChanged: (Set<LotSizeMode> selection) {
                        setState(() => _selectedLotSizeMode = selection.first);
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _selectedLotSizeMode == LotSizeMode.percentage 
                  ? 'Trade size will be a percentage of your current wallet balance.'
                  : 'Trade size will be a fixed amount for every mirrored trade.',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile.adaptive(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSettingItem(String title, String value, {required VoidCallback onTap}) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, String accountId, SyncProvider syncProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danger Zone',
          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Remove Account'),
                content: const Text('Are you sure you want to remove this account? This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => context.pop(true), 
                    child: const Text('Remove', style: TextStyle(color: AppColors.danger))
                  ),
                ],
              ),
            );

            if (confirm == true) {
              final success = await syncProvider.removeAccount(accountId);
              if (success && context.mounted) {
                context.pop();
              }
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          child: const Text('Remove Exchange Account'),
        ),
      ],
    );
  }
}


