import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../screens/connection_detail.dart';
import '../screens/connections.dart';
import '../screens/home.dart';
import '../screens/inventory.dart';
import '../screens/login.dart';
import '../screens/order_detail.dart';
import '../screens/orders.dart';
import '../screens/products.dart';
import '../screens/settings.dart';
import '../screens/stock_transfer_create.dart';
import '../screens/stock_transfer_history.dart';
import '../screens/sync_log.dart';
import 'session.dart';
import '../widgets/shell.dart';

String _appPath(String raw) {
  var path = raw;
  if (path.startsWith('/API')) {
    path = path.substring(4);
    if (!path.startsWith('/')) path = '/$path';
  }
  if (path.isEmpty || path == '/index.html') return '/login';
  return path;
}

String _startLocation() {
  if (!kIsWeb) return '/login';

  final uri = Uri.base;
  final hash = uri.fragment.trim();
  final fromHash = hash.isEmpty ? null : Uri.parse(hash.startsWith('/') ? hash : '/$hash');
  final route = fromHash != null && fromHash.path.isNotEmpty ? fromHash : uri;

  final status = (route.queryParameters['status'] ?? uri.queryParameters['status'] ?? '').toLowerCase();
  final query = route.query.isNotEmpty ? route.query : uri.query;
  if (status == 'success' || status == 'error' || Api.pendingOAuthReturn) {
    return query.isEmpty ? '/connections' : '/connections?$query';
  }

  final path = _appPath(route.path);
  return (fromHash ?? route).hasQuery ? '$path?${(fromHash ?? route).query}' : path;
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

      if (session.loggedIn && oauth != null && !atConnections && session.allowsPath('/connections')) {
        return oauth;
      }
      if (!session.loggedIn && !atLogin) return '/login';
      if (session.loggedIn && atLogin) return oauth != null && session.allowsPath('/connections') ? oauth : session.homePath;
      if (loc == '/integration') {
        if (!session.allowsPath('/connections')) return '/';
        final q = state.uri.hasQuery ? '?${state.uri.query}' : '';
        return '/connections$q';
      }
      if (session.loggedIn && !session.allowsPath(loc)) return '/';
      if (loc == '/inventory' || loc.startsWith('/inventory/')) return '/';
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
          GoRoute(
            path: '/stock-transfer',
            builder: (_, _) => const StockTransferHistoryScreen(),
            routes: [
              GoRoute(path: 'create', builder: (_, _) => const StockTransferCreateScreen()),
              GoRoute(path: 'history', redirect: (_, _) => '/stock-transfer'),
            ],
          ),
          GoRoute(
            path: '/connections',
            builder: (_, _) => const ConnectScreen(),
            routes: [
              GoRoute(
                path: ':channel/:shopId',
                builder: (_, state) => ConnectionDetailScreen(
                  channel: state.pathParameters['channel']!,
                  shopId: state.pathParameters['shopId']!,
                ),
              ),
            ],
          ),
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
