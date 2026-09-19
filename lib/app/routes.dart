import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../screens/connect.dart';
import '../screens/home.dart';
import '../screens/inventory.dart';
import '../screens/login.dart';
import '../screens/order_detail.dart';
import '../screens/orders.dart';
import '../screens/products.dart';
import '../screens/settings.dart';
import '../screens/sync_log.dart';
import 'session.dart';
import '../widgets/shell.dart';

String _startLocation() {
  if (!kIsWeb) return '/login';

  final uri = Uri.base;
  final hash = uri.fragment.trim();
  final fromHash = hash.isEmpty ? null : Uri.parse(hash.startsWith('/') ? hash : '/$hash');
  final loc = fromHash ?? uri;
  final status = (loc.queryParameters['status'] ?? uri.queryParameters['status'] ?? '').toLowerCase();
  final query = loc.query.isNotEmpty ? loc.query : uri.query;

  if (status == 'success' || status == 'error' || Api.pendingOAuthReturn) {
    return query.isEmpty ? '/connections' : '/connections?$query';
  }

  final path = loc.path.isEmpty ? '/' : loc.path;
  if (path == '/' || path.isEmpty) return '/login';
  return loc.hasQuery ? '$path?${loc.query}' : path;
}

String? _oauthTarget(Uri uri) {
  final status = (uri.queryParameters['status'] ?? Uri.base.queryParameters['status'] ?? '').toLowerCase();
  final path = uri.path.toLowerCase();
  final fromCallback = status == 'success' ||
      status == 'error' ||
      path.contains('callback') ||
      path.contains('oauth') ||
      path.contains('authorize');
  if (!fromCallback && !Api.pendingOAuthReturn) return null;
  final q = uri.query.isNotEmpty ? uri.query : Uri.base.query;
  return q.isEmpty ? '/connections' : '/connections?$q';
}

GoRouter buildRouter(Session session) {
  return GoRouter(
    initialLocation: _startLocation(),
    refreshListenable: session,
    redirect: (context, state) {
      final oauth = _oauthTarget(state.uri);
      final loc = state.matchedLocation;
      final atLogin = loc == '/login';
      final atConnections = loc == '/connections' || loc == '/integration';

      if (session.loggedIn && oauth != null && !atConnections) {
        return oauth;
      }
      if (!session.loggedIn && !atLogin) return '/login';
      if (session.loggedIn && atLogin) return oauth ?? '/connections';
      if (loc == '/integration') {
        final q = state.uri.hasQuery ? '?${state.uri.query}' : '';
        return '/connections$q';
      }
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
          GoRoute(path: '/connections', builder: (_, _) => const ConnectScreen()),
          GoRoute(path: '/integration', builder: (_, _) => const ConnectScreen()),
          GoRoute(path: '/sync-log', builder: (_, _) => const SyncLogScreen()),
          GoRoute(
            path: '/sync-log/:id',
            builder: (_, state) => ErrorDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ],
  );
}
