import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
// Redundant mock_data import removed
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import 'dart:math';

class LiveExecutionStatusScreen extends StatelessWidget {
  final String positionId;
  const LiveExecutionStatusScreen({super.key, required this.positionId});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final position = syncProvider.currentPositions[positionId];
    
    // If position is missing (maybe finished or cleanup), use mock or neutral state
    final isFinished = position == null || _checkIfFinished(position);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Mirroring'),
        automaticallyImplyLeading: isFinished,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildMasterStatus(position, isFinished),
            const SizedBox(height: 40),
            const SectionHeader(title: 'Slave Mirroring Progress'),
            const SizedBox(height: 16),
            Expanded(child: _buildSlaveStatuses(position)),
            if (isFinished)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: GradientButton(
                  label: 'Return to Dashboard',
                  onPressed: () => context.go('/'),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  bool _checkIfFinished(Map<String, dynamic> pos) {
    final slaves = pos['slaves'] as Map<String, dynamic>? ?? {};
    if (slaves.isEmpty) return false;
    return slaves.values.every((s) => s['status'] == 'filled' || s['status'] == 'failed');
  }

  Widget _buildMasterStatus(Map<String, dynamic>? position, bool isFinished) {
    final symbol = position?['symbol'] ?? 'Unknown';
    final side = (position?['side'] as String?)?.toUpperCase() ?? 'TRADE';
    
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
                    Text('Master $side: $symbol', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(isFinished ? 'Execution Sequence Complete' : 'Synchronizing Mirroring...', 
                        style: TextStyle(color: isFinished ? AppColors.success : AppColors.primary, fontSize: 12)),
                  ],
                ),
              ),
              if (!isFinished)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              if (isFinished)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlaveStatuses(Map<String, dynamic>? position) {
    if (position == null) {
      return const Center(child: Text('Initializing mirroring...'));
    }

    final slaves = position['slaves'] as Map<String, dynamic>? ?? {};
    final slaveIds = slaves.keys.toList();

    if (slaveIds.isEmpty) {
      return const Center(child: Text('No slave accounts found for mirroring.'));
    }

    return ListView.builder(
      itemCount: slaveIds.length,
      itemBuilder: (context, index) {
        final slaveId = slaveIds[index];
        final slaveData = slaves[slaveId];
        final status = slaveData['status'] ?? 'pending';
        final isDone = status == 'filled';
        final isError = status == 'failed';
        final isRetrying = status == 'retrying';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(slaveId.substring(0, min(slaveId.length, 1)).toUpperCase(), 
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Slave Account: $slaveId', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(isError ? 'Error: Execution Failed' : (isDone ? 'Filled' : (isRetrying ? 'Retrying (Attempt ${slaveData['retries'] ?? 1})...' : 'Pending...')), 
                          style: TextStyle(fontSize: 10, color: isError ? AppColors.danger : (isDone ? AppColors.success : (isRetrying ? AppColors.warning : AppColors.textMuted)))),
                    ],
                  ),
                ),
                if (!isDone && !isError && !isRetrying)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
                if (isRetrying)
                   const Icon(Icons.sync_problem, color: AppColors.warning, size: 18).animate(onPlay: (c) => c.repeat()).rotate(),
                if (isDone)
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                if (isError)
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 100).ms);
      },
    );
  }
}

int min(int a, int b) => a < b ? a : b;
