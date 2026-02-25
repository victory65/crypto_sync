import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_sync/providers/settings_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Center'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShieldHeader(context),
            const SizedBox(height: 32),
            _buildSecurityLevel(context, settings),
            const SizedBox(height: 32),
            _buildSection(context, 'Authentication', [
              _SecurityItem(
                icon: Icons.fingerprint,
                title: 'Biometric Unlock',
                subtitle: 'Use fingerprint to unlock the app',
                trailing: Switch.adaptive(
                  value: settings.isBiometricEnabled,
                  onChanged: (val) => settings.setBiometricEnabled(val),
                ),
              ),
              _SecurityItem(
                icon: Icons.verified_user_outlined,
                title: 'Two-Factor Auth (2FA)',
                subtitle: 'Manage authenticator app',
                trailing: StatusBadge(
                  label: settings.isTwoFactorEnabled ? 'ON' : 'OFF', 
                  color: settings.isTwoFactorEnabled ? AppColors.success : AppColors.textMuted, 
                  small: true
                ),
                onTap: () => context.push('/settings/security/2fa'),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, 'Login Activity', [
              _SecurityItem(
                icon: Icons.devices,
                title: 'Active Sessions',
                subtitle: 'Manage connected devices',
                onTap: () => context.push('/settings/security/sessions'),
              ),
              _SecurityItem(
                icon: Icons.history,
                title: 'Login History',
                subtitle: 'Review recent access attempts',
                onTap: () => context.push('/settings/security/history'),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, 'Account Recovery', [
              _SecurityItem(
                icon: Icons.password,
                title: 'Change Password',
                subtitle: 'Update your login credentials',
                onTap: () => context.push('/settings/security/change-password'),
              ),
            ]),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'Encryption: AES-256-GCM (Hardware Backed)',
                style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShieldHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Keep your assets secure',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage all security protocols from one place',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityLevel(BuildContext context, SettingsProvider settings) {
    double strength = 0.3;
    String label = 'Fair';
    Color color = AppColors.warning;
    String tip = 'Enable 2FA to achieve "High" security status.';

    if (settings.isTwoFactorEnabled && settings.isBiometricEnabled) {
      strength = 1.0;
      label = 'SECURED';
      color = AppColors.success;
      tip = 'Your account is protected by maximum security protocols.';
    } else if (settings.isTwoFactorEnabled) {
      strength = 0.7;
      label = 'High';
      color = AppColors.success;
      tip = 'Great! Turn on Biometrics for instant "SECURED" status.';
    } else if (settings.isBiometricEnabled) {
      strength = 0.5;
      label = 'Medium';
      color = AppColors.warning;
      tip = 'Enable 2FA to significantly boost your security level.';
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Security Strength', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: strength,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Text(
            tip,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<_SecurityItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.1)),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.map((item) {
              final isLast = items.indexOf(item) == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(item.icon, size: 22, color: AppColors.primary),
                    title: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: item.trailing ?? const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                    onTap: item.onTap,
                  ),
                  if (!isLast) const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showMocks(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is currently in simulation mode.')),
    );
  }
}

class _SecurityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  _SecurityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
}

