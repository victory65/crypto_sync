import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../data/mock_data.dart';

class SlaveDetailScreen extends StatefulWidget {
  final String slaveId;

  const SlaveDetailScreen({super.key, required this.slaveId});

  @override
  State<SlaveDetailScreen> createState() => _SlaveDetailScreenState();
}

class _SlaveDetailScreenState extends State<SlaveDetailScreen> {
  late SlaveAccount _slave;

  @override
  void initState() {
    super.initState();
    _slave = MockData.slaveAccounts.firstWhere(
      (s) => s.id == widget.slaveId,
      orElse: () => MockData.slaveAccounts.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_slave.exchangeName} Settings'),
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
            _buildBalanceCard(context),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Mirroring Configuration'),
            const SizedBox(height: 16),
            _buildSettingsList(context),
            const SizedBox(height: 40),
            _buildDangerZone(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      child: Row(
        children: [
          ExchangeAvatar(exchangeName: _slave.exchangeName, logo: _slave.exchangeLogo, size: 56),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Wallet',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  '\$${_slave.balance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        _buildSettingToggle(
          'Enable Mirroring',
          'Automatically copy master trades',
          _slave.syncEnabled,
          (val) => setState(() => _slave = _slave.copyWith(syncEnabled: val)),
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          'Lot Size Mode',
          _slave.lotSizeMode == LotSizeMode.fixed ? 'Fixed Quantity' : 'Percentage of Balance',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          'Default Size',
          _slave.lotSizeMode == LotSizeMode.fixed 
              ? '${_slave.defaultLotSize} units' 
              : '${_slave.defaultLotSize}% of balance',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          'API Key Management',
          '•••• •••• •••• 52ef',
          onTap: () {},
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

  Widget _buildDangerZone(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danger Zone',
          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {},
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
