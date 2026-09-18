import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _boot();
    });
  }

  String _query(String key) {
    final fromRoute = GoRouterState.of(context).uri.queryParameters[key];
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    return Uri.base.queryParameters[key] ?? '';
  }

  String _decode(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    try {
      return Uri.decodeQueryComponent(t);
    } catch (_) {
      return t;
    }
  }

  Future<void> _boot() async {
    final status = _query('status');
    final hint = _decode(_query('message'));
    final fromOAuth = status == 'success' || status == 'error' || Api.pendingOAuthReturn;
    Api.clearOAuthReturn();

    // โหลดจาก GET /api/connections หลัง Authorize — ถ้า success แต่ยังว่าง ให้ลองอีกครั้งสั้นๆ
    await ShopStore.instance.load();
    if (status == 'success' && mounted) {
      final anyLive = ShopStore.instance.shops.any((s) => s.connected);
      if (!anyLive) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) await ShopStore.instance.load();
      }
    }
    if (!mounted) return;

    if (status == 'error') {
      ShopStore.instance.setError(hint.isNotEmpty ? hint : 'เชื่อมต่อไม่สำเร็จ');
    } else if (status == 'success') {
      final anyLive = ShopStore.instance.shops.any((s) => s.connected);
      if (anyLive) {
        ShopStore.instance.setSuccess(hint.isNotEmpty ? hint : 'เชื่อมต่อสำเร็จ');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เชื่อมต่อสำเร็จ'), backgroundColor: Pal.ok),
        );
      } else {
        ShopStore.instance.setError(
          'Authorize สำเร็จแล้ว แต่ยังไม่พบร้านในฐานข้อมูล — ตรวจ log หลังบ้านว่าบันทึก MarketplaceAuthorization หรือยัง',
        );
      }
    }
    if (fromOAuth && (status == 'success' || status == 'error')) {
      context.go('/connections');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShopStore.instance,
      builder: (context, _) {
        final store = ShopStore.instance;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.success != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Pal.okBg,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(store.success!, style: const TextStyle(color: Pal.ok, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              if (store.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Pal.errBg,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(store.error!, style: const TextStyle(color: Pal.err)),
                    ),
                  ),
                ),
              if (store.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              LayoutBuilder(
                builder: (context, c) {
                  final shops = store.shops;
                  if (c.maxWidth >= 1100) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < shops.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: _Card(shops[i])),
                        ],
                      ],
                    );
                  }
                  final w = c.maxWidth >= 720 ? (c.maxWidth - 16) / 2 : c.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final s in shops) SizedBox(width: w, child: _Card(s)),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.s);

  final ShopConn s;

  static const _labelW = 120.0;
  static const _rowH = 36.0;

  String _text(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty || t == '-' ? '-' : t;
  }

  String _when(DateTime? t) => formatDt(t, withSeconds: true);

  @override
  Widget build(BuildContext context) {
    final busy = ShopStore.instance.syncing == s.channel;
    final shop = _text(s.shop);
    final shopId = _text(s.shopId);

    Widget row(String k, String v, {Color? color}) {
      final value = _text(v);
      return SizedBox(
        height: _rowH,
        child: Row(
          children: [
            SizedBox(
              width: _labelW,
              child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13)),
            ),
            Expanded(
              child: Tooltip(
                message: value == '-' ? '' : value,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color ?? Pal.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final actions = <Widget>[
      if (s.connected) ...[
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await ShopStore.instance.sync(s.channel);
                    if (!context.mounted) return;
                    if (ShopStore.instance.error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ซิงค์ออเดอร์ ${s.channel.label} สำเร็จ')),
                      );
                    }
                  },
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Sync Orders'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 44, child: _ReconnectBtn(channel: s.channel, outlined: true)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: ShopStore.instance.loading ? null : () => _confirmDisconnect(context, s.channel),
            style: OutlinedButton.styleFrom(
              foregroundColor: Pal.err,
              side: const BorderSide(color: Pal.err),
            ),
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('ยกเลิกการเชื่อมต่อ'),
          ),
        ),
      ] else if (s.needsReauth) ...[
        SizedBox(height: 44, child: _ReconnectBtn(channel: s.channel, outlined: false)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: ShopStore.instance.loading ? null : () => _confirmDisconnect(context, s.channel),
            style: OutlinedButton.styleFrom(
              foregroundColor: Pal.err,
              side: const BorderSide(color: Pal.err),
            ),
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('ยกเลิกการเชื่อมต่อ'),
          ),
        ),
      ] else
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => Api.connectPlatform(s.channel),
            child: Text('Connect ${s.channel.shortLabel}'),
          ),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                ChannelDot(channel: s.channel, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.channel.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                s.connected
                    ? connPill(ConnStatus.live)
                    : s.needsReauth
                        ? pill('ต้องเชื่อมต่อใหม่', const Color(0xFFB45309), Pal.warnBg)
                        : connPill(ConnStatus.off),
              ],
            ),
          ),
          const SizedBox(height: 18),
          row('ร้านค้า', shop),
          row('Shop ID', shopId),
          row('เชื่อมต่อเมื่อ', _when(s.lastConnected)),
          row('ดึงข้อมูลล่าสุด', _when(s.lastSync)),
          row(
            'สถานะ',
            s.connected
                ? 'เชื่อมต่อแล้ว'
                : s.needsReauth
                    ? 'ต้อง Authorize ใหม่'
                    : 'ยังไม่เชื่อมต่อ',
            color: s.connected ? Pal.ok : Pal.err,
          ),
          const SizedBox(height: 16),
          ...actions,
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, Channel channel) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text('ยกเลิกการเชื่อมต่อ ${channel.label}'),
        content: const Text('ร้านค้าจะหยุดซิงค์คำสั่งซื้อและสินค้าจนกว่าจะเชื่อมต่อใหม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: const Text('ไม่'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Pal.err, foregroundColor: Colors.white),
            child: const Text('ยืนยันยกเลิกการเชื่อมต่อ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ShopStore.instance.disconnect(channel);
    if (!context.mounted) return;
    final store = ShopStore.instance;
    if (store.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: Pal.err));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.success ?? 'ยกเลิกการเชื่อมต่อ ${channel.label} แล้ว'), backgroundColor: Pal.ok),
      );
    }
  }
}

class _ReconnectBtn extends StatelessWidget {
  const _ReconnectBtn({required this.channel, required this.outlined});

  final Channel channel;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = outlined
        ? OutlinedButton.icon(
            onPressed: () => Api.connectPlatform(channel),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('เชื่อมต่อใหม่'),
          )
        : ElevatedButton.icon(
            onPressed: () => Api.connectPlatform(channel),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('เชื่อมต่อใหม่'),
          );
    return SizedBox(width: double.infinity, child: child);
  }
}
