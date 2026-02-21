import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../data/mock_data.dart';

class LiveExecutionStatusScreen extends StatefulWidget {
  const LiveExecutionStatusScreen({super.key});

  @override
  State<LiveExecutionStatusScreen> createState() => _LiveExecutionStatusScreenState();
}

class _LiveExecutionStatusScreenState extends State<LiveExecutionStatusScreen> {
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _startExecutionSimulation();
  }

  void _startExecutionSimulation() async {
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      setState(() => _isFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Execution'),
        automaticallyImplyLeading: _isFinished,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildMasterStatus(),
            const SizedBox(height: 40),
            const SectionHeader(title: 'Slave Sync Status'),
            const SizedBox(height: 16),
            Expanded(child: _buildSlaveStatuses()),
            if (_isFinished)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Return to Dashboard'),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterStatus() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              const ExchangeAvatar(exchangeName: 'Binance', logo: '₿', size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Master Account (Binance)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(_isFinished ? 'Execution Complete' : 'Executing Trade...', 
                        style: TextStyle(color: _isFinished ? AppColors.success : AppColors.primary, fontSize: 12)),
                  ],
                ),
              ),
              if (!_isFinished)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              if (_isFinished)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlaveStatuses() {
    return ListView.builder(
      itemCount: MockData.slaveAccounts.length,
      itemBuilder: (context, index) {
        final slave = MockData.slaveAccounts[index];
        // Simulate some variety in status
        bool isDone = _isFinished || index < 2; 
        bool isError = index == 3 && _isFinished;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExchangeAvatar(exchangeName: slave.exchangeName, logo: slave.exchangeLogo, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slave.exchangeName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(isError ? 'API Error: Timeout' : (isDone ? 'Filled' : 'Pending...'), 
                          style: TextStyle(fontSize: 10, color: isError ? AppColors.danger : (isDone ? AppColors.success : AppColors.textMuted))),
                    ],
                  ),
                ),
                if (!isDone && !isError)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
                if (isDone && !isError)
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                if (isError)
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 150).ms);
      },
    );
  }
}
