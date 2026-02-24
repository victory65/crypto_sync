import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../core/api_config.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import '../../models/trade_models.dart';

class ManualTradeSetupScreen extends StatefulWidget {
  const ManualTradeSetupScreen({super.key});

  @override
  State<ManualTradeSetupScreen> createState() => _ManualTradeSetupScreenState();
}

class _ManualTradeSetupScreenState extends State<ManualTradeSetupScreen> {
  final _assetPairs = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'BNB/USDT', 'XRP/USDT', 'ADA/USDT'];
  late String _selectedPair;
  TradeSide _side = TradeSide.buy;
  OrderType _orderType = OrderType.market;
  bool _syncSlaves = true;
  final _sizeController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedPair = _assetPairs[0];
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _handleExecuteSync() async {
    final syncProvider = context.read<SyncProvider>();
    final userId = syncProvider.lastUserId ?? 'user_123';

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/simulate/trade?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final positionId = data['position_id'];

        if (mounted) {
          context.push('/trade/execution', extra: positionId);
        }
      } else {
        throw Exception('Failed to initiate sync');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Trade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSideSelector(),
            const SizedBox(height: 32),
            _buildPairSelector(),
            const SizedBox(height: 24),
            _buildOrderTypeSelector(),
            const SizedBox(height: 24),
            if (_orderType == OrderType.limit) ...[
              _buildInputField('Limit Price', '0.00', _priceController, Icons.attach_money),
              const SizedBox(height: 24),
            ],
            _buildInputField('Trade Size', '0.50', _sizeController, Icons.shopping_basket_outlined),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Sync Slaves'),
            const SizedBox(height: 16),
            _buildSlaveSyncOptions(),
            const SizedBox(height: 48),
            GradientButton(
              label: _isLoading ? 'EXCUTING...' : 'Execute Sync',
              onPressed: _isLoading ? null : _handleExecuteSync,
              startColor: _side == TradeSide.buy ? AppColors.success : AppColors.danger,
              endColor: _side == TradeSide.buy ? AppColors.success.withOpacity(0.8) : AppColors.danger.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SideTab(
              label: 'BUY / LONG',
              isSelected: _side == TradeSide.buy,
              color: AppColors.success,
              onTap: () => setState(() => _side = TradeSide.buy),
            ),
          ),
          Expanded(
            child: _SideTab(
              label: 'SELL / SHORT',
              isSelected: _side == TradeSide.sell,
              color: AppColors.danger,
              onTap: () => setState(() => _side = TradeSide.sell),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trading Pair', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPair,
          dropdownColor: Theme.of(context).cardTheme.color,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.currency_bitcoin),
          ),
          items: _assetPairs.map((pair) {
            return DropdownMenuItem(value: pair, child: Text(pair));
          }).toList(),
          onChanged: (val) => setState(() => _selectedPair = val!),
        ),
      ],
    );
  }

  Widget _buildOrderTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Type', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildChip('Market', _orderType == OrderType.market, () => setState(() => _orderType = OrderType.market)),
            const SizedBox(width: 12),
            _buildChip('Limit', _orderType == OrderType.limit, () => setState(() => _orderType = OrderType.limit)),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
        ),
      ],
    );
  }

  Widget _buildSlaveSyncOptions() {
    final syncProvider = context.watch<SyncProvider>();
    final activeSlavesCount = syncProvider.accounts.where((a) {
      if (a is! Map) return false;
      final type = a['type']?.toString().toLowerCase();
      final id = a['id']?.toString().toLowerCase();
      final isMaster = type == 'master' || id == 'master';
      return !isMaster && a['enabled'] == true;
    }).length;

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mirror to All Active Slaves', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  activeSlavesCount == 0 
                      ? 'No active slave accounts connected' 
                      : '$activeSlavesCount account${activeSlavesCount == 1 ? "" : "s"} selected', 
                  style: TextStyle(
                    fontSize: 12, 
                    color: activeSlavesCount == 0 ? AppColors.danger.withOpacity(0.8) : AppColors.textSecondary
                  )
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _syncSlaves && activeSlavesCount > 0, 
            onChanged: activeSlavesCount > 0 ? (val) => setState(() => _syncSlaves = val) : null,
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SideTab({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
