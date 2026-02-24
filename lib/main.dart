import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/sync_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'widgets/sync_status_pill.dart';
import 'screens/dashboard_screen.dart';
import 'screens/positions/positions_list_screen.dart';
import 'screens/positions/position_detail_screen.dart';
import 'screens/accounts/accounts_overview_screen.dart';
import 'screens/accounts/slave_detail_screen.dart';
import 'screens/accounts/add_account_screen.dart';
import 'screens/trade/manual_trade_setup_screen.dart';
import 'screens/trade/trade_preview_sync_screen.dart';
import 'screens/trade/live_execution_status_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/settings/security_screen.dart';
import 'screens/bots/bot_nexus_screen.dart';
import 'screens/subscription_screen.dart';

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
              builder: (context, state) => SlaveDetailScreen(
                slaveId: state.pathParameters['id']!,
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
            ),
          ],
        ),
        GoRoute(
          path: '/p2p',
          builder: (context, state) => const BotNexusScreen(),
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