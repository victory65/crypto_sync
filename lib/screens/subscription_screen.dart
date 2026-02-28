import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Choose your plan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Mirror trades to more accounts with higher precision',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.7)),
            ),
            const SizedBox(height: 40),
            _buildPlanCard(
              context,
              'Free',
              'Trial',
              '3-Day Experience',
              [
                '1 Master Account',
                '1 Investor Account',
                '3-Day Access only',
                'Manual Execution'
              ],
              isSelected: subProvider.plan == SubscriptionPlan.free,
              onSelect: () => _handlePlanSelection(
                  context, subProvider, SubscriptionPlan.free),
            ),
            const SizedBox(height: 20),
            _buildPlanCard(
              context,
              'Basic',
              '\$19/mo',
              'For small clusters',
              [
                '1 Master Account',
                '5 Investor Accounts',
                'Standard Priority Support',
                'Manual Execution'
              ],
              isSelected: subProvider.plan == SubscriptionPlan.basic,
              isPopular: true,
              onSelect: () => _handlePlanSelection(
                  context, subProvider, SubscriptionPlan.basic),
            ),
            const SizedBox(height: 20),
            _buildPlanCard(
              context,
              'Pro',
              '\$49/mo',
              'Professional mirroring',
              [
                '1 Master Account',
                '10 Investor Accounts included',
                '\$10 per extra investor (>10)',
                'Ultra-low Latency Sync',
                'Priority Support',
                'Manual Execution'
              ],
              isSelected: subProvider.plan == SubscriptionPlan.pro,
              onSelect: () => _handlePlanSelection(
                  context, subProvider, SubscriptionPlan.pro),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    String title,
    String price,
    String subtitle,
    List<String> features, {
    bool isSelected = false,
    bool isPopular = false,
    required VoidCallback onSelect,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      border: isPopular
          ? Border.all(color: AppColors.primary, width: 2)
          : Border.all(color: Theme.of(context).dividerColor),
      color: isSelected
          ? AppColors.primary.withOpacity(0.05)
          : Theme.of(context).cardTheme.color,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPopular)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('MOST POPULAR',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(price,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isPopular
                              ? AppColors.primary
                              : Theme.of(context).textTheme.titleLarge?.color)),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 24),
              const AppDivider(),
              const SizedBox(height: 24),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(f, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSelected ? null : onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? AppColors.primary
                        : Theme.of(context).cardTheme.color,
                    foregroundColor:
                        isPopular ? Colors.white : AppColors.primary,
                    side: isPopular
                        ? null
                        : const BorderSide(color: AppColors.primary),
                  ),
                  child: Text(
                    isSelected
                        ? 'Current Plan'
                        : (context.read<SubscriptionProvider>().isAdmin
                            ? 'Select Plan'
                            : 'Contact Support'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  void _handlePlanSelection(BuildContext context,
      SubscriptionProvider subProvider, SubscriptionPlan plan) {
    if (subProvider.isAdmin) {
      subProvider.setPlanOverride(plan);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ADMIN: Plan switched to ${plan.name.toUpperCase()}'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      // Logic for real users (e.g. open payment gateway)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Real-world payment gateway would open here.')),
      );
    }
  }
}

