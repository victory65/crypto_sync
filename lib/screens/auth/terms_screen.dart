import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_sync/theme/app_colors.dart';

class TermsAndServicesScreen extends StatelessWidget {
  const TermsAndServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Services'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: February 24, 2026',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            const Text(
              'Crypto Sync Terms of Service\n\n'
              '(The content of this screen will be updated later by the user.)\n\n'
              'By using this application, you agree to mirror trades at your own risk. '
              'Crypto Sync is a tool and does not provide financial advice.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

