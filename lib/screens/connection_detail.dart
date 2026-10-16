import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/ui.dart';
import 'connections.dart';

class ConnectionDetailScreen extends StatefulWidget {
  const ConnectionDetailScreen({super.key, required this.channel, required this.shopId});

  final String channel;
  final String shopId;

  @override
  State<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends State<ConnectionDetailScreen> {
  bool _editing = false;
  bool _testing = false;
  List<String> _warehouses = [for (final w in sapWarehouses) w.code];
  late final TextEditingController _note;
  late final TextEditingController _group;
  String _country = '';
  String _warehouse = '';

  @override
  void initState() {
    super.initState();
    _note = TextEditingController();
    _group = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ShopStore.instance.realShops.isEmpty) await ShopStore.instance.load();
      if (!mounted) return;
      _hydrate(ShopStore.instance.findShop(widget.channel, widget.shopId));
      try {
        final opts = await Api.getErpOptions();
        if (mounted) {
          setState(() {
            _warehouses = [
              ...{for (final w in sapWarehouses) w.code, ...opts.warehouses},
            ];
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _group.dispose();
    super.dispose();
  }

  void _hydrate(ShopConn? shop) {
    if (shop == null) return;
    _country = shop.country;
    _group.text = shop.group;
    _warehouse = shop.warehouse;
    _note.text = shop.note;
  }

  Future<void> _test(ShopConn shop) async {
    setState(() => _testing = true);
    await ShopStore.instance.load();
    if (!mounted) return;
    final next = ShopStore.instance.findShop(widget.channel, widget.shopId);
    setState(() => _testing = false);
    final ok = next?.connected == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'การเชื่อมต่อปกติ Token ยังใช้งานได้' : 'ทดสอบแล้ว — ร้านนี้ต้องเชื่อมต่อใหม่'),
        backgroundColor: ok ? Pal.ok : Pal.warn,
      ),
    );
  }

  void _save(ShopConn shop) {
    ShopStore.instance.saveMeta(
      shop,
      country: _country,
      group: _group.text.trim(),
      warehouse: _warehouse,
      note: _note.text.trim(),
    );
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกข้อมูลร้านค้าแล้ว'), backgroundColor: Pal.ok),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShopStore.instance,
      builder: (context, _) {
        final shop = ShopStore.instance.findShop(widget.channel, widget.shopId);
        if (shop == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ShopStore.instance.loading ? 'กำลังโหลด...' : 'ไม่พบร้านค้า'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => context.go('/connections'), child: const Text('กลับไปการเชื่อมต่อ')),
              ],
            ),
          );
        }
        return _body(context, shop);
      },
    );
  }

  Widget _body(BuildContext context, ShopConn shop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(onPressed: () => context.go('/connections'), icon: const Icon(Icons.arrow_back_rounded)),
              ChannelDot(channel: shop.channel, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'จัดการการเชื่อมต่อ — ${shop.displayName}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${shop.channel.label} | ${shop.idLabel}: ${shop.shopId == '-' ? '-' : shop.shopId}',
                          style: const TextStyle(color: Pal.muted, fontSize: 13),
                        ),
                        shop.connected
                            ? connPill(ConnStatus.live)
                            : shop.needsReauth
                                ? pill('ต้องเชื่อมต่อใหม่', const Color(0xFFB45309), Pal.warnBg)
                                : connPill(ConnStatus.off),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final info = _infoCard(shop);
              final status = _statusCard(shop);
              if (c.maxWidth < 980) {
                return Column(children: [info, const SizedBox(height: 12), status]);
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: info),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: status),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoCard(ShopConn shop) {
    final warehouses = <String>{
      if (_warehouse.isNotEmpty) _warehouse,
      for (final w in sapWarehouses) w.code,
      ..._warehouses,
    }.toList();

    return _Card(
      icon: Icons.inventory_2_outlined,
      title: 'ข้อมูลร้านค้า',
      trailing: TextButton.icon(
        onPressed: () {
          if (_editing) {
            _save(shop);
          } else {
            _hydrate(shop);
            setState(() => _editing = true);
          }
        },
        icon: Icon(_editing ? Icons.save_outlined : Icons.edit_outlined, size: 16),
        label: Text(_editing ? 'บันทึก' : 'แก้ไข'),
      ),
      child: Column(
        children: [
          _pair(
            _box('ชื่อร้านค้า', shop.displayName),
            _box(shop.idLabel, shop.shopId == '-' ? '-' : shop.shopId),
          ),
          _pair(
            _box('แพลตฟอร์ม', shop.channel.label, leading: ChannelDot(channel: shop.channel, size: 20)),
            _editing
                ? _drop('ประเทศ', _country, ['', 'Thailand', 'Singapore', 'Malaysia', 'Vietnam', 'Indonesia', 'Philippines'], (v) => setState(() => _country = v))
                : _box('ประเทศ', _country.isEmpty ? '-' : _country),
          ),
          _pair(
            _editing
                ? _labeled(
                    'กลุ่มสินค้า',
                    TextField(
                      controller: _group,
                      decoration: const InputDecoration(isDense: true, hintText: 'เช่น Shopee - ชื่อร้าน'),
                    ),
                  )
                : _box('กลุ่มสินค้า', _group.text.trim().isEmpty ? '-' : _group.text.trim()),
            _editing
                ? _drop('คลังสินค้า (SAP)', _warehouse, warehouses, (v) => setState(() => _warehouse = v))
                : _box('คลังสินค้า (SAP)', _warehouse.isEmpty ? '-' : warehouseLabel(_warehouse)),
          ),
          _editing
              ? _labeled(
                  'หมายเหตุ',
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(isDense: true, hintText: 'เช่น ร้านหลักสำหรับขายออนไลน์'),
                  ),
                )
              : _box('หมายเหตุ', _note.text.trim().isEmpty ? '-' : _note.text.trim()),
        ],
      ),
    );
  }

  Widget _statusCard(ShopConn shop) {
    final expire = shop.tokenExpiresAt;
    final remain = expire == null ? null : expire.difference(DateTime.now()).inDays;
    return _Card(
      icon: Icons.link_rounded,
      title: 'สถานะการเชื่อมต่อ',
      trailing: TextButton.icon(
        onPressed: _testing ? null : () => _test(shop),
        icon: _testing
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded, size: 16),
        label: Text(_testing ? 'กำลังทดสอบ...' : 'ทดสอบการเชื่อมต่อ'),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: shop.connected ? Pal.okBg : shop.needsReauth ? Pal.warnBg : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  shop.connected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: shop.connected ? Pal.ok : Pal.err,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  shop.connected ? 'เชื่อมต่อแล้ว' : shop.needsReauth ? 'ต้องเชื่อมต่อใหม่' : 'ยังไม่เชื่อมต่อ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: shop.connected ? Pal.ok : Pal.err,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  shop.connected
                      ? 'Token ยังใช้งานได้ปกติ'
                      : shop.needsReauth
                          ? 'Token หมดอายุหรือถูกยกเลิก'
                          : 'ยังไม่มี Token ของร้านนี้',
                  style: const TextStyle(color: Pal.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _kv('เชื่อมต่อเมื่อ', formatDt(shop.lastConnected, withSeconds: true)),
          _kv('ดึงข้อมูลล่าสุด', formatDt(shop.lastSync, withSeconds: true)),
          _kv(
            'หมดอายุ Token',
            formatDt(expire, withSeconds: true),
            extra: remain == null
                ? null
                : Text(
                    remain >= 0 ? 'เหลืออีก $remain วัน' : 'หมดอายุแล้ว',
                    style: TextStyle(color: remain >= 0 ? Pal.ok : Pal.err, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
          ),
          _kv(
            'สถานะการซิงก์',
            shop.connected ? 'ซิงก์ปกติ' : 'หยุดซิงก์',
            extra: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: shop.connected ? Pal.ok : Pal.faint,
                shape: BoxShape.circle,
              ),
            ),
            extraFirst: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => Api.connectPlatform(shop.channel),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('เชื่อมต่อใหม่'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: ShopStore.instance.loading
                        ? null
                        : () async {
                            await confirmDisconnectShop(context, shop);
                            if (!mounted) return;
                            context.go('/connections');
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Pal.err,
                      side: const BorderSide(color: Pal.err),
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('ยกเลิกการเชื่อมต่อ'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pair(Widget a, Widget b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Pal.muted, fontSize: 12)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _box(String label, String value, {Widget? leading}) {
    return _labeled(
      label,
      InputDecorator(
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    final opts = [for (final x in items) x];
    if (value.isNotEmpty && !opts.contains(value)) opts.add(value);
    return _labeled(
      label,
      DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: opts.contains(value) ? value : '',
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('เลือก')),
          for (final x in opts)
            if (x.isNotEmpty) DropdownMenuItem(value: x, child: Text(label.contains('คลัง') ? warehouseLabel(x) : x)),
        ],
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      ),
    );
  }

  Widget _kv(String k, String v, {Widget? extra, bool extraFirst = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
          if (extra != null && extraFirst) extra,
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          if (extra != null && !extraFirst) extra,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child, this.trailing});

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Pal.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
