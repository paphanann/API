import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/ui.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String _platform = 'all';
  String _status = 'all';
  final _search = TextEditingController();

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

    await Future.wait([
      ShopStore.instance.load(),
      SyncLogStore.instance.load(),
    ]);
    if (status == 'success' && mounted) {
      final anyLive = ShopStore.instance.realShops.any((s) => s.connected);
      if (!anyLive) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) await ShopStore.instance.load();
      }
    }
    if (!mounted) return;

    if (status == 'error') {
      ShopStore.instance.setError(hint.isNotEmpty ? hint : 'เชื่อมต่อไม่สำเร็จ');
    } else if (status == 'success') {
      final shop = ShopStore.instance.latestLive(
        shopId: _decode(_query('shopId')).isNotEmpty ? _decode(_query('shopId')) : _decode(_query('shop_id')),
        channelName: _decode(_query('platform')).isNotEmpty ? _decode(_query('platform')) : _decode(_query('channel')),
      );
      if (shop != null) {
        ShopStore.instance.markConnectSuccess(shop);
      } else {
        ShopStore.instance.setError(
          'Authorize สำเร็จแล้ว แต่ยังไม่พบร้านในฐานข้อมูล — ตรวจ log หลังบ้านว่าบันทึก MarketplaceAuthorization หรือยัง',
        );
      }
    }
    if (fromOAuth && (status == 'success' || status == 'error')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/connections');
      });
    }
  }

  Future<void> _addShop() async {
    final channel = await showDialog<Channel>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => const _AddShopDialog(),
    );
    if (channel == null) return;
    Api.connectPlatform(channel);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _platform = 'all';
      _status = 'all';
      _search.clear();
    });
  }

  List<ShopConn> _filtered(List<ShopConn> shops) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final s in shops)
        if ((_platform == 'all' || s.channel.name == _platform) &&
            (_status == 'all' ||
                (_status == 'live' && s.connected) ||
                (_status == 'off' && !s.connected)) &&
            (q.isEmpty ||
                s.displayName.toLowerCase().contains(q) ||
                s.shopId.toLowerCase().contains(q)))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShopStore.instance,
      builder: (context, _) {
        final store = ShopStore.instance;
        if (store.showConnectSuccess && store.lastConnectedShop != null) {
          return _SuccessView(shop: store.lastConnectedShop!);
        }
        final shops = store.realShops;
        final shown = _filtered(shops);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('การเชื่อมต่อ marketplace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'จัดการร้านค้าบน Shopee, TikTok Shop และ Lazada',
                style: TextStyle(color: Pal.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
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
                  final cards = [
                    for (final channel in Channel.values)
                      _PlatformCard(
                        channel: channel,
                        live: shops.where((s) => s.channel == channel && s.connected).length,
                        off: shops.where((s) => s.channel == channel && !s.connected).length,
                      ),
                  ];
                  if (c.maxWidth < 800) {
                    return Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          cards[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Panel(
                pad: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final filters = [
                          Drop<String>(
                            label: 'แพลตฟอร์ม',
                            value: _platform,
                            width: 180,
                            onChanged: (v) => setState(() => _platform = v ?? 'all'),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('ทุกแพลตฟอร์ม')),
                              ...Channel.values.map((ch) => DropdownMenuItem(value: ch.name, child: Text(ch.label))),
                            ],
                          ),
                          Drop<String>(
                            label: 'สถานะ',
                            value: _status,
                            width: 180,
                            onChanged: (v) => setState(() => _status = v ?? 'all'),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
                              DropdownMenuItem(value: 'live', child: Text('เชื่อมต่อแล้ว')),
                              DropdownMenuItem(value: 'off', child: Text('ยังไม่เชื่อมต่อ')),
                            ],
                          ),
                        ];
                        final search = SizedBox(
                          width: 240,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ค้นหาร้านค้า', style: TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'ชื่อร้านค้า หรือ Shop ID',
                                  hintStyle: TextStyle(fontSize: 13),
                                  prefixIcon: Icon(Icons.search, size: 16),
                                  prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        );
                        final clear = SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: _clearFilters,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Pal.text,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Pal.line),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 13)),
                          ),
                        );
                        if (c.maxWidth < 900) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [filters[0], const SizedBox(width: 12), filters[1]]),
                              const SizedBox(height: 12),
                              search,
                              const SizedBox(height: 12),
                              Align(alignment: Alignment.centerRight, child: clear),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            filters[0],
                            const SizedBox(width: 12),
                            filters[1],
                            const SizedBox(width: 12),
                            search,
                            const SizedBox(width: 12),
                            clear,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'แสดง ${shown.length} จาก ${shops.length} ร้านค้า',
                      style: const TextStyle(color: Pal.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    FillTable(
                      minWidth: 1180,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: tableHeadBg,
                        headingTextStyle: tableHead,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 64,
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('แพลตฟอร์ม')),
                          DataColumn(label: Text('ชื่อร้าน')),
                          DataColumn(label: Text('Shop ID')),
                          DataColumn(label: Text('สถานะ')),
                          DataColumn(label: Text('คลังสินค้า (SAP)')),
                          DataColumn(label: Text('เชื่อมต่อเมื่อ')),
                          DataColumn(label: Text('ดึงข้อมูลล่าสุด')),
                          DataColumn(label: Text('จัดการ')),
                        ],
                        rows: [
                          for (var i = 0; i < shown.length; i++)
                            DataRow(
                              onSelectChanged: (_) => context.go(store.withMeta(shown[i]).detailPath),
                              cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(ChannelDot(channel: shown[i].channel, size: 26)),
                                DataCell(
                                  Text(
                                    shown[i].displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  onTap: () => context.go(store.withMeta(shown[i]).detailPath),
                                ),
                                DataCell(Text(shown[i].shopId == '-' ? '-' : shown[i].shopId)),
                                DataCell(_StatusDot(shown[i])),
                                DataCell(Text(() {
                                  final wh = store.withMeta(shown[i]).warehouse.trim();
                                  return wh.isEmpty ? '-' : wh;
                                }())),
                                DataCell(Text(formatDt(shown[i].lastConnected, withSeconds: true))),
                                DataCell(Text(formatDt(shown[i].lastSync, withSeconds: true))),
                                DataCell(
                                  _ShopActions(shop: shown[i]),
                                  onTap: () {},
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: Text('ยังไม่มีร้านค้าที่เชื่อมต่อ', style: TextStyle(color: Pal.muted))),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _addShop,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('เพิ่มร้านค้า'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.channel, required this.live, required this.off});

  final Channel channel;
  final int live;
  final int off;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChannelDot(channel: channel, size: 28),
              const SizedBox(width: 10),
              Text(channel.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('$live', style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.ok)),
              const SizedBox(width: 6),
              const Text('เชื่อมแล้ว', style: TextStyle(color: Pal.muted, fontSize: 13)),
              const SizedBox(width: 18),
              Text('$off', style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.faint)),
              const SizedBox(width: 6),
              const Text('ยังไม่เชื่อม', style: TextStyle(color: Pal.muted, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.shop);

  final ShopConn shop;

  @override
  Widget build(BuildContext context) {
    final color = shop.connected ? Pal.ok : shop.needsReauth ? Pal.warn : Pal.faint;
    final label = shop.connected ? 'เชื่อมต่อแล้ว' : shop.needsReauth ? 'ต้องเชื่อมต่อใหม่' : 'ยังไม่เชื่อมต่อ';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _ShopActions extends StatelessWidget {
  const _ShopActions({required this.shop});

  final ShopConn shop;

  Future<void> _onMenu(BuildContext context, String v) async {
    if (v == 'detail') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(shop.detailPath);
      });
    } else if (v == 'reconnect') {
      Api.connectPlatform(shop.channel);
    } else if (v == 'disconnect') {
      await confirmDisconnectShop(context, shop);
    } else if (v == 'delete') {
      await confirmDeleteShop(context, shop);
    }
  }

  Widget _item(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Pal.text),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color ?? Pal.text, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'จัดการร้านค้า',
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Pal.line),
      ),
      onSelected: (v) => _onMenu(context, v),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'detail', child: _item(Icons.visibility_outlined, 'ดูรายละเอียด')),
        PopupMenuItem(value: 'reconnect', child: _item(Icons.refresh_rounded, 'เชื่อมต่อใหม่')),
        const PopupMenuDivider(height: 1),
        if (shop.connected)
          PopupMenuItem(value: 'disconnect', child: _item(Icons.link_off_rounded, 'ยกเลิกการเชื่อมต่อ', color: Pal.err))
        else
          PopupMenuItem(value: 'delete', child: _item(Icons.delete_outline_rounded, 'ลบร้านค้า', color: Pal.err)),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.more_vert_rounded, color: Pal.muted),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.shop});

  final ShopConn shop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Pal.line),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: Pal.okBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Pal.ok, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('เชื่อมต่อร้านค้าสำเร็จ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'ระบบบันทึกร้านค้าจาก ${shop.channel.label} แล้ว',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pal.muted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _kv('ชื่อร้านค้า', shop.displayName),
                _kv(shop.idLabel, shop.shopId == '-' ? '-' : shop.shopId),
                _kv('แพลตฟอร์ม', shop.channel.label),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      ShopStore.instance.dismissConnectSuccess();
                      context.go('/connections/${shop.channel.name}/${Uri.encodeComponent(shop.shopId)}');
                    },
                    child: const Text('บันทึกและเสร็จสิ้น'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _AddShopDialog extends StatefulWidget {
  const _AddShopDialog();

  @override
  State<_AddShopDialog> createState() => _AddShopDialogState();
}

class _AddShopDialogState extends State<_AddShopDialog> {
  Channel _channel = Channel.shopee;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: Row(
        children: [
          const Expanded(child: Text('เพิ่มร้านค้าใหม่', style: TextStyle(fontWeight: FontWeight.w800))),
          IconButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('เลือกแพลตฟอร์ม', style: TextStyle(color: Pal.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < Channel.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _PlatformPick(
                      channel: Channel.values[i],
                      selected: _channel == Channel.values[i],
                      onTap: () => setState(() => _channel = Channel.values[i]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Pal.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ระบบจะพาไปหน้า ${_channel.label} เพื่อให้คุณอนุญาตการเข้าถึง (Authorize)',
                style: const TextStyle(fontSize: 13, color: Pal.text),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_channel),
          child: Text('เชื่อมต่อกับ ${_channel.label}'),
        ),
      ],
    );
  }
}

class _PlatformPick extends StatelessWidget {
  const _PlatformPick({required this.channel, required this.selected, required this.onTap});

  final Channel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Pal.primarySoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? Pal.primary : Pal.line, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            children: [
              ChannelDot(channel: channel, size: 28),
              const SizedBox(height: 8),
              Text(
                channel.shortLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 18,
                color: selected ? Pal.primary : Pal.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> confirmDeleteShop(BuildContext context, ShopConn shop) async {
  final name = shop.displayName;
  final platform = shop.channel.label;
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Pal.warn),
          SizedBox(width: 8),
          Expanded(child: Text('ยืนยันการลบร้านค้า?')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการลบร้านค้า $name ($platform) ออกจากระบบ PASS ใช่หรือไม่?'),
            const SizedBox(height: 12),
            const Text(
              'การลบจะยกเลิกการเชื่อมต่อร้านค้านี้และหยุดการซิงค์ข้อมูล โดยไม่ลบคำสั่งซื้อที่บันทึกใน SAP Business One แล้ว',
              style: TextStyle(color: Pal.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Pal.err, foregroundColor: Colors.white),
          child: const Text('ลบร้านค้า'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ShopStore.instance.remove(
    shop.channel,
    shopId: shop.apiShopId.isEmpty ? null : shop.apiShopId,
  );
  if (!context.mounted) return;
  final store = ShopStore.instance;
  if (store.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: Pal.err));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(store.success ?? 'ลบร้านค้าออกจากระบบ PASS แล้ว'), backgroundColor: Pal.ok),
    );
  }
}

Future<void> confirmDisconnectShop(BuildContext context, ShopConn shop) async {
  final name = shop.displayName;
  final platform = shop.channel.label;
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.link_off_rounded, color: Pal.err),
          SizedBox(width: 8),
          Expanded(child: Text('ยกเลิกการเชื่อมต่อ?')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Text('ต้องการยกเลิกการเชื่อมต่อร้านค้า $name ($platform) ใช่หรือไม่? การซิงค์ข้อมูลจะหยุดทันที'),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Pal.err, foregroundColor: Colors.white),
          child: const Text('ยกเลิกการเชื่อมต่อ'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ShopStore.instance.disconnect(
    shop.channel,
    shopId: shop.apiShopId.isEmpty ? null : shop.apiShopId,
  );
  if (!context.mounted) return;
  final store = ShopStore.instance;
  if (store.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: Pal.err));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(store.success ?? 'ยกเลิกการเชื่อมต่อแล้ว'), backgroundColor: Pal.ok),
    );
  }
}
