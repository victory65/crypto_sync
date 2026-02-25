import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/providers/settings_provider.dart';
import 'package:crypto_sync/providers/subscription_provider.dart';
import 'package:crypto_sync/services/connectivity_service.dart';
import 'package:crypto_sync/widgets/offline_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto_sync/theme/app_theme.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/screens/auth/splash_screen.dart';
import 'package:crypto_sync/screens/auth/login_screen.dart';
import 'package:crypto_sync/screens/auth/signup_screen.dart';
import 'package:crypto_sync/screens/auth/forgot_password_screen.dart';
import 'package:crypto_sync/widgets/sync_status_pill.dart';
import 'package:crypto_sync/screens/dashboard_screen.dart';
import 'package:crypto_sync/screens/positions/positions_list_screen.dart';
import 'package:crypto_sync/screens/positions/position_detail_screen.dart';
import 'package:crypto_sync/screens/accounts/accounts_overview_screen.dart';
import 'package:crypto_sync/screens/accounts/investor_detail_screen.dart';
import 'package:crypto_sync/screens/accounts/add_account_screen.dart';
import 'package:crypto_sync/screens/trade/manual_trade_setup_screen.dart';
import 'package:crypto_sync/screens/trade/trade_preview_sync_screen.dart';
import 'package:crypto_sync/screens/trade/live_execution_status_screen.dart';
import 'package:crypto_sync/screens/settings_screen.dart';
import 'package:crypto_sync/screens/settings/security_screen.dart';
import 'package:crypto_sync/screens/settings/profile_edit_screen.dart';
import 'package:crypto_sync/screens/settings/notifications_screen.dart';
import 'package:crypto_sync/screens/settings/security/two_fa_screen.dart';
import 'package:crypto_sync/screens/settings/security/active_sessions_screen.dart';
import 'package:crypto_sync/screens/settings/security/history_screen.dart';
import 'package:crypto_sync/screens/settings/security/change_password_screen.dart';
import 'package:crypto_sync/screens/auth/verify_2fa_login_screen.dart';
import 'package:crypto_sync/screens/auth/terms_screen.dart';
import 'package:crypto_sync/screens/bots/bot_nexus_screen.dart';
import 'package:crypto_sync/screens/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('protocol_logs');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: const CryptoSyncApp(),
    ),
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  initialLocation: '/splash',
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainNavigationWrapper(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/positions',
          builder: (context, state) => const PositionsListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => PositionDetailScreen(
                positionId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsOverviewScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddAccountScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => InvestorDetailScreen(
                investorId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/trade',
          builder: (context, state) => const ManualTradeSetupScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'security',
              builder: (context, state) => const SecurityScreen(),
              routes: [
                GoRoute(path: '2fa', builder: (context, state) => const TwoFactorAuthScreen()),
                GoRoute(path: 'sessions', builder: (context, state) => const ActiveSessionsScreen()),
                GoRoute(path: 'history', builder: (context, state) => const LoginHistoryScreen()),
                GoRoute(path: 'change-password', builder: (context, state) => const ChangePasswordScreen()),
              ]
            ),
            GoRoute(
              path: 'profile',
              builder: (context, state) => const ProfileEditScreen(),
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/trade/preview',
      builder: (context, state) => const TradePreviewSyncScreen(),
    ),
    GoRoute(
      path: '/trade/execution',
      builder: (context, state) => LiveExecutionStatusScreen(positionId: state.extra as String),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/p2p',
      builder: (context, state) => const BotNexusScreen(),
    ),
    GoRoute(
      path: '/auth/verify-2fa',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return Verify2FALoginScreen(
          tempToken: extra['temp_token'],
          userId: extra['user_id'],
        );
      },
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsAndServicesScreen(),
    ),
  ],
);

class CryptoSyncApp extends StatelessWidget {
  const CryptoSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    return MaterialApp.router(
      title: 'Crypto Sync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return OfflineOverlay(child: child!);
      },
    );
  }
}

class MainNavigationWrapper extends StatelessWidget {
  final Widget child;

  const MainNavigationWrapper({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location == '/') return 0;
    if (location.startsWith('/positions')) return 1;
    if (location.startsWith('/accounts')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/positions');
        break;
      case 2:
        context.go('/accounts');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Positions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SyncStatusPill(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          '$title Screen Placeholder',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
