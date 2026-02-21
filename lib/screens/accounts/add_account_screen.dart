import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../data/mock_data.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  String? _selectedExchange;
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exchange'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Exchange', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildExchangeGrid(),
            const SizedBox(height: 32),
            const Text('API Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                hintText: 'API Key',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiSecretController,
              decoration: const InputDecoration(
                hintText: 'API Secret',
                prefixIcon: Icon(Icons.lock_person_outlined),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 48),
            GradientButton(
              label: 'Connect Account',
              onPressed: _selectedExchange == null ? null : () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: MockData.exchanges.length,
      itemBuilder: (context, index) {
        final exchange = MockData.exchanges[index];
        final isSelected = _selectedExchange == exchange;

        return GestureDetector(
          onTap: () => setState(() => _selectedExchange = exchange),
          child: AppCard(
            padding: EdgeInsets.zero,
            color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExchangeAvatar(exchangeName: exchange, logo: exchange[0], size: 32),
                const SizedBox(height: 8),
                Text(exchange, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}
