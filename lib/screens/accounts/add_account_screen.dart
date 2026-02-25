import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/models/trade_models.dart';

class AddAccountScreen extends StatefulWidget {
  final String? accountId;
  final String? accountType;
  const AddAccountScreen({super.key, this.accountId, this.accountType});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _lotSizeController = TextEditingController();
  final _riskPercentController = TextEditingController();

  String? _selectedExchange;
  LotSizeMode _selectedLotSizeMode = LotSizeMode.fixed;
  String _selectedTradeTypeStr = 'spot';
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isActive = true;
  bool _obscureApiSecret = true;
  String _accountType = 'investor';

  // Field-level error messages
  String? _nameError;
  String? _exchangeError;
  String? _apiKeyError;
  String? _lotSizeError;

  static const _supportedExchanges = [
    'Binance', 'Bybit', 'Bitget', 'OKX',
    'Gate.io', 'MEXC', 'Kraken', 'Phemex',
    'Deribit', 'BitMEX', 'Coinbase', 'KuCoin'
  ];

  bool get _isMaster => _accountType == 'master';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.accountId != null;
    if (_isEditing) {
      _loadAccountData();
    } else {
      _accountType = widget.accountType ?? 'investor';
    }
  }

  void _loadAccountData() {
    final syncProvider = context.read<SyncProvider>();
    final account = syncProvider.accounts.cast<Map?>().firstWhere(
      (a) => a != null && a['id'] == widget.accountId,
      orElse: () => null,
    );

    if (account != null) {
      final data = Map<String, dynamic>.from(account as Map);
      _nameController.text = data['name'] ?? '';
      _selectedExchange = data['exchange'] != null
          ? _supportedExchanges.cast<String?>().firstWhere(
              (e) => e != null && e.toLowerCase() == data['exchange'].toString().toLowerCase(),
              orElse: () => _supportedExchanges.first)
          : null;
      _lotSizeController.text = (data['lot_size'] ?? '').toString();
      _riskPercentController.text = (data['risk_percent'] ?? '').toString();
      _selectedLotSizeMode = data['lot_size_mode'] == 'percentage' ? LotSizeMode.percentage : LotSizeMode.fixed;
      _selectedTradeTypeStr = data['trade_type'] ?? 'spot';
      _accountType = data['type'] ?? 'investor';
      _isActive = data['enabled'] ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _lotSizeController.dispose();
    _riskPercentController.dispose();
    super.dispose();
  }

  bool _validateFields() {
    bool valid = true;
    setState(() {
      _nameError = null;
      _exchangeError = null;
      _apiKeyError = null;
      _lotSizeError = null;
    });

    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Account name is required');
      valid = false;
    } else {
      // Duplicate name check (excluding self)
      final syncProvider = context.read<SyncProvider>();
      final duplicate = syncProvider.accounts.any((a) {
        if (a is! Map) return false;
        if (_isEditing && a['id'] == widget.accountId) return false;
        return a['name']?.toString().toLowerCase() ==
            _nameController.text.trim().toLowerCase();
      });
      if (duplicate) {
        setState(() => _nameError = 'An account with this name already exists');
        valid = false;
      }
    }

    if (_selectedExchange == null) {
      setState(() => _exchangeError = 'Please select an exchange');
      valid = false;
    }

    if (!_isEditing && _apiKeyController.text.trim().isEmpty) {
      setState(() => _apiKeyError = 'API key is required');
      valid = false;
    }

    if (!_isMaster && _lotSizeController.text.trim().isEmpty) {
      setState(() => _lotSizeError = 'Lot size is required');
      valid = false;
    }

    return valid;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? 'Edit Account'
        : (_isMaster ? 'Add Master Account' : 'Add Investor Account');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
          tooltip: 'Cancel',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Account Name ─────────────────────────────────────
              _fieldLabel('Account Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() => _nameError = null),
                decoration: InputDecoration(
                  hintText: _isMaster
                      ? 'Enter master account name'
                      : 'Enter investor account name',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  errorText: _nameError,
                ),
              ),

              const SizedBox(height: 24),

              // ── Exchange ─────────────────────────────────────────
              _fieldLabel('Broker / Exchange'),
              if (_exchangeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_exchangeError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
              const SizedBox(height: 10),
              _buildExchangeGrid(),

              const SizedBox(height: 28),

              // ── Account Type (Trade Type) ─────────────────────────
              _fieldLabel('Trade Execution Mode'),
              const SizedBox(height: 10),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'spot',
                          label: Text('Spot'),
                          icon: Icon(Icons.show_chart)),
                      ButtonSegment(
                          value: 'futures',
                          label: Text('Futures'),
                          icon: Icon(Icons.bolt)),
                      ButtonSegment(
                          value: 'both',
                          label: Text('Both'),
                          icon: Icon(Icons.all_inclusive)),
                    ],
                    selected: {_selectedTradeTypeStr},
                    onSelectionChanged: (s) =>
                        setState(() => _selectedTradeTypeStr = s.first),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── API Credentials ─────────────────────────────────
              _fieldLabel('API Key'),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                onChanged: (_) => setState(() => _apiKeyError = null),
                decoration: InputDecoration(
                  hintText: _isEditing
                      ? 'Enter API key (leave blank to keep current)'
                      : 'Enter API key',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  errorText: _apiKeyError,
                ),
              ),

              const SizedBox(height: 16),

              _fieldLabel('Secret Key'),
              const SizedBox(height: 8),
              TextField(
                controller: _apiSecretController,
                obscureText: _obscureApiSecret,
                decoration: InputDecoration(
                  hintText: _isEditing
                      ? 'Enter secret key (leave blank to keep current)'
                      : 'Enter secret key',
                  prefixIcon: const Icon(Icons.lock_person_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureApiSecret
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureApiSecret = !_obscureApiSecret),
                  ),
                ),
              ),

              const SizedBox(height: 28),



              // ── Lot Size (Investor ONLY) ───────────────────────
              if (!_isMaster) ...[
                _fieldLabel('Lot Size (Mandatory)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _lotSizeController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _lotSizeError = null),
                        decoration: InputDecoration(
                          hintText: 'e.g. 0.05',
                          suffixText: _selectedLotSizeMode == LotSizeMode.percentage ? '%' : null,
                          errorText: _lotSizeError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: SegmentedButton<LotSizeMode>(
                        segments: const [
                          ButtonSegment(
                              value: LotSizeMode.fixed,
                              label: Text('Fixed'),
                              icon: Icon(Icons.attach_money)),
                          ButtonSegment(
                              value: LotSizeMode.percentage,
                              label: Text('% Bal'),
                              icon: Icon(Icons.percent)),
                        ],
                        selected: {_selectedLotSizeMode},
                        onSelectionChanged: (s) =>
                            setState(() => _selectedLotSizeMode = s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],

              // ── Investor-only: Risk % + Active toggle ────────────────
              if (!_isMaster) ...[
                _fieldLabel('Risk Percentage (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _riskPercentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Enter risk %',
                    prefixIcon: Icon(Icons.shield_outlined),
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 24),

                // Active / Inactive toggle
                Row(
                  children: [
                    _fieldLabel('Mirror Active'),
                    const Spacer(),
                    Switch.adaptive(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],

              // ── Save + Cancel ─────────────────────────────────────
              GradientButton(
                label: _isLoading
                    ? 'Saving...'
                    : (_isEditing ? 'Save Changes' : 'Connect Account'),
                onPressed: _isLoading ? null : _handleSave,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _handleDelete(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: const Text('Remove Account'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );
  }

  Future<void> _handleSave() async {
    if (!_validateFields()) return;
    setState(() => _isLoading = true);

    final syncProvider = context.read<SyncProvider>();
    final double? lotSize = double.tryParse(_lotSizeController.text.trim());

    bool success;
    if (_isEditing) {
      success = await syncProvider.updateAccount(
        accountId: widget.accountId!,
        name: _nameController.text.trim(),
        apiKey: _apiKeyController.text.isNotEmpty
            ? _apiKeyController.text
            : null,
        apiSecret: _apiSecretController.text.isNotEmpty
            ? _apiSecretController.text
            : null,
        lotSize: lotSize,
        lotSizeMode:
            _selectedLotSizeMode == LotSizeMode.percentage ? 'percentage' : 'fixed',
        tradeType: _selectedTradeTypeStr,
      );
    } else {
      success = await syncProvider.addAccount(
        name: _nameController.text.trim(),
        exchange: _selectedExchange!.toLowerCase(),
        apiKey: _apiKeyController.text.trim(),
        apiSecret: _apiSecretController.text.trim(),
        lotSize: _isMaster ? 0.0 : (lotSize ?? 0.01),
        lotSizeMode:
            _selectedLotSizeMode == LotSizeMode.percentage ? 'percentage' : 'fixed',
        tradeType: _selectedTradeTypeStr,
        type: _accountType,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Account updated!' : 'Account connected!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please check your details and try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Account?'),
        content: const Text(
            'This will stop mirroring for this account. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<SyncProvider>().removeAccount(widget.accountId!);
      if (success && mounted) context.pop();
    }
  }

  Widget _buildExchangeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: _supportedExchanges.length,
      itemBuilder: (context, index) {
        final exchange = _supportedExchanges[index];
        final isSelected = _selectedExchange == exchange;

        return GestureDetector(
          onTap: () => setState(() {
            _selectedExchange = exchange;
            _exchangeError = null;
          }),
          child: AppCard(
            padding: EdgeInsets.zero,
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surface,
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExchangeAvatar(
                    exchangeName: exchange, logo: exchange[0], size: 32),
                const SizedBox(height: 8),
                Text(exchange,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : null)),
              ],
            ),
          ),
        );
      },
    );
  }
}


