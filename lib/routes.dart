import 'package:go_router/go_router.dart';

import 'screens/connect.dart';
import 'screens/home.dart';
import 'screens/inventory.dart';
import 'screens/login.dart';
import 'screens/order_detail.dart';
import 'screens/orders.dart';
import 'screens/products.dart';
import 'screens/settings.dart';
import 'screens/sync_log.dart';
import 'session.dart';
import 'widgets/shell.dart';

GoRouter buildRouter(Session session) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: session,
    redirect: (context, state) {
      final atLogin = state.matchedLocation == '/login';
      if (!session.loggedIn && !atLogin) return '/login';
      if (session.loggedIn && atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => LoginScreen(session: session)),
      ShellRoute(
        builder: (_, _, child) => AppShell(session: session, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
          GoRoute(
            path: '/orders/:id',
            builder: (_, state) => OrderDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
          GoRoute(path: '/inventory', builder: (_, _) => const InventoryScreen()),
          GoRoute(path: '/integration', builder: (_, _) => const ConnectScreen()),
          GoRoute(path: '/sync-log', builder: (_, _) => const SyncLogScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ],
  );
}
