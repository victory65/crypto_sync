import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final syncProvider = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileSection(context),
            const SizedBox(height: 32),
            _buildSettingsGroup(context, 'Account', [
              _SettingItem(
                icon: Icons.person_outline, 
                title: 'Profile Information', 
                onTap: () {}
              ),
              _SettingItem(
                icon: Icons.security, 
                title: 'Security Center', 
                onTap: () => context.push('/settings/security'),
              ),
              _SettingItem(
                icon: Icons.hub_outlined, 
                title: 'Bot Nexus', 
                onTap: () => context.push('/p2p'),
              ),
              _SettingItem(
                icon: Icons.payment, 
                title: 'Subscription Plan', 
                onTap: () => context.push('/subscription')
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsGroup(context, 'App Settings', [
              _SettingItem(
                icon: Icons.notifications_none, 
                title: 'Push Notifications', 
                onTap: () {}
              ),
              _SettingItem(
                icon: Icons.dark_mode_outlined, 
                title: 'Dark Mode', 
                trailingWidget: Switch(
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (val) => settings.setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
                ),
                onTap: settings.toggleTheme,
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsGroup(context, 'Support', [
              _SettingItem(icon: Icons.help_outline, title: 'Help Center', onTap: () {}),
              _SettingItem(icon: Icons.policy_outlined, title: 'Privacy Policy', onTap: () {}),
            ]),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () {
                context.read<SyncProvider>().disconnect();
                context.go('/login');
              },
              child: const Text('Log Out', style: TextStyle(color: AppColors.danger)),
            ),
            const SizedBox(height: 12),
            const Text('v1.0.4 (Build 122)', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  syncProvider.userName ?? 'User', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                Text(
                  syncProvider.userEmail ?? 'Not logged in', 
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, String title, List<_SettingItem> items) {
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
                    leading: Icon(item.icon, size: 22, color: Theme.of(context).iconTheme.color),
                    title: Text(item.title, style: const TextStyle(fontSize: 14)),
                    trailing: item.trailingWidget ?? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.trailingText != null)
                          Text(item.trailingText!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                      ],
                    ),
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
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String? trailingText;
  final Widget? trailingWidget;
  final VoidCallback onTap;

  _SettingItem({
    required this.icon, 
    required this.title, 
    this.trailingText, 
    this.trailingWidget,
    required this.onTap
  });
}
