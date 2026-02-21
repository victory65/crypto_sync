import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Mirror trades to more accounts with higher precision',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            _buildPlanCard(
              context,
              'Basic',
              'Free',
              'For casual traders',
              ['Up to 2 Slaves', '1-minute latency', 'Community Support'],
              isSelected: true,
            ),
            const SizedBox(height: 20),
            _buildPlanCard(
              context,
              'Pro',
              '\$29/mo',
              'For serious traders',
              ['Up to 10 Slaves', 'Real-time Sync', 'Priority Support', 'Advanced Lot Sizing'],
              isPopular: true,
            ),
            const SizedBox(height: 20),
            _buildPlanCard(
              context,
              'Enterprise',
              'Custom',
              'For institutional needs',
              ['Unlimited Slaves', 'Ultra-low Latency', 'Dedicated Manager', 'Custom API Integration'],
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
  }) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      border: isPopular ? Border.all(color: AppColors.primary, width: 2) : Border.all(color: AppColors.border),
      color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: const Text('MOST POPULAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isPopular ? AppColors.primary : AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              const AppDivider(),
              const SizedBox(height: 24),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(f, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSelected ? null : () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? AppColors.primary : AppColors.surface,
                    foregroundColor: isPopular ? Colors.white : AppColors.textPrimary,
                    side: isPopular ? null : const BorderSide(color: AppColors.primary),
                  ),
                  child: Text(isSelected ? 'Current Plan' : 'Select Plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}
