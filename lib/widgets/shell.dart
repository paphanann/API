import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../stores/stores.dart';
import 'sync_status.dart';
import 'ui.dart';

const _menus = [
  ('/', 'หน้าหลัก', Icons.grid_view_rounded),
  ('/orders', 'คำสั่งซื้อ', Icons.receipt_long_rounded),
  ('/products', 'สินค้า', Icons.inventory_2_outlined),
  ('/inventory', 'คลังสินค้า', Icons.warehouse_outlined),
  ('/connections', 'การเชื่อมต่อ marketplace', Icons.link_rounded),
  ('/sync-log', 'Sync Log', Icons.sync_rounded),
  ('/settings', 'ตั้งค่า', Icons.settings_outlined),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.session, required this.child});

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final title = _title(path);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    const side = 248.0;
    const top = 68.0;

    if (wide) {
      return Scaffold(
        backgroundColor: Pal.bg,
        body: LayoutBuilder(
          builder: (context, box) {
            final size = MediaQuery.sizeOf(context);
            final w = box.maxWidth.isFinite && box.maxWidth > 0 ? box.maxWidth : size.width;
            final h = box.maxHeight.isFinite && box.maxHeight > 0 ? box.maxHeight : size.height;
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, bottom: 0, width: side, child: SideMenu(session: session)),
                  Positioned(left: side, top: 0, right: 0, height: top, child: TopBar(title: title, session: session)),
                  Positioned(
                    left: side,
                    top: top,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(color: Pal.bg, child: child),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Pal.bg,
      drawer: Drawer(
        width: side,
        backgroundColor: Pal.sidebar,
        child: SideMenu(session: session, onPick: () => Navigator.of(context).maybePop()),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final size = MediaQuery.sizeOf(context);
          final w = box.maxWidth.isFinite && box.maxWidth > 0 ? box.maxWidth : size.width;
          final h = box.maxHeight.isFinite && box.maxHeight > 0 ? box.maxHeight : size.height;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: top,
                  child: Builder(
                    builder: (ctx) => TopBar(
                      title: title,
                      session: session,
                      onMenu: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: top,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(color: Pal.bg, child: child),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _title(String path) {
    if (path == '/') return 'หน้าหลัก';
    if (path.startsWith('/orders/')) return 'รายละเอียดคำสั่งซื้อ';
    if (path == '/orders') return '';
    if (path == '/products') return '';
    if (path == '/inventory') return '';
    if (path.startsWith('/products')) return 'สินค้า';
    if (path.startsWith('/inventory')) return 'คลังสินค้า';
    if (path.startsWith('/connections') || path.startsWith('/integration')) return 'การเชื่อมต่อ marketplace';
    if (path.startsWith('/sync-log/')) return 'Error Detail';
    if (path.startsWith('/sync-log')) return 'Sync Log';
    if (path.startsWith('/settings')) return 'ตั้งค่า';
    return 'PASS';
  }
}

class SideMenu extends StatelessWidget {
  const SideMenu({super.key, required this.session, this.onPick});

  final Session session;
  final VoidCallback? onPick;

  bool _on(String loc, String path) {
    if (path == '/') return loc == '/';
    return loc == path || loc.startsWith('$path/') || (path == '/connections' && loc.startsWith('/integration'));
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;

    return Container(
      width: 248,
      color: Pal.sidebar,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: LogoMark(size: 34, light: true)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Marketplace Integration', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in _menus)
                  _tile(
                    icon: m.$3,
                    label: m.$2,
                    selected: _on(loc, m.$1),
                    onTap: () {
                      final to = m.$1;
                      onPick?.call();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) context.go(to);
                      });
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                ),
                _tile(
                  icon: Icons.logout_rounded,
                  label: 'ออกจากระบบ',
                  selected: false,
                  danger: true,
                  onTap: () {
                    onPick?.call();
                    session.logout();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Demo / Test Data', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  SizedBox(height: 4),
                  Text('ERP/SAP Sandbox', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final c = danger ? const Color(0xFFFCA5A5) : (selected ? Colors.white : Colors.white70);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Pal.sidebarActive : Colors.transparent,
        type: selected ? MaterialType.canvas : MaterialType.transparency,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Pal.sidebarHover,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: danger ? c : (selected ? Colors.white : Colors.white60), size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, required this.session, this.onMenu});

  final String title;
  final Session session;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final initial = session.name.isEmpty ? 'U' : session.name[0].toUpperCase();

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Pal.line)),
      ),
      child: Row(
        children: [
          if (onMenu != null) IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox.shrink()),
          IconButton(
            onPressed: () {
              ShopStore.instance.load();
              SyncLogStore.instance.load();
              showDialog<void>(
                context: context,
                builder: (ctx) => FutureBuilder(
                  future: Api.getSettings(),
                  builder: (ctx, snap) => AlertDialog(
                    title: const Text('การแจ้งเตือน'),
                    content: SizedBox(
                      width: 320,
                      child: SyncStatusBody(autoSync: snap.data?.autoSync),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'out') session.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.name, style: const TextStyle(fontWeight: FontWeight.w700, color: Pal.text)),
                    Text(session.email, style: const TextStyle(fontSize: 12, color: Pal.muted)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'out', child: Text('ออกจากระบบ')),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Pal.primarySoft,
                  child: Text(initial, style: const TextStyle(color: Pal.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Text('User', style: TextStyle(fontSize: 11, color: Pal.muted)),
                  ],
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Pal.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
