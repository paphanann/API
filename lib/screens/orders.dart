import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/sync_status.dart';
import '../widgets/ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _pageSize = 20;

  String _ch = 'all';
  String _shop = 'all';
  String _st = 'all';
  String _sap = 'all';
  String _q = '';
  int _page = 1;
  DateTime? _from = DateTime(2026, 10, 1);
  DateTime? _to;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orders = OrderStore.instance;
      if (orders.orders.isEmpty) {
        orders.load();
      } else {
        orders.load(silent: true);
      }
      if (ShopStore.instance.realShops.isEmpty) ShopStore.instance.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  String _sapKey(Order o) {
    final doc = (o.sapDocNum ?? '').trim();
    final raw = doc.isNotEmpty ? 'sap_ok' : o.syncStatus;
    final v = raw.toLowerCase();
    if (v.contains('sap_ok') || v.contains('sapok') || v == 'ok') return 'ok';
    if (v.contains('sap_error') || v.contains('error')) return 'error';
    if (v.contains('saved') || v.isEmpty) return 'wait';
    return 'other';
  }

  bool get _hasDateFilter => _from != null && _to != null;

  String? get _platformQuery => _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;

  Future<void> _searchTap() async {
    setState(() {
      _q = _search.text.trim();
      _page = 1;
    });
    await OrderStore.instance.load(platform: _platformQuery);
  }

  void _onQuery(String v) {
    setState(() {
      _q = v;
      _page = 1;
    });
  }

  Future<void> _syncNow() async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await OrderStore.instance.load(platform: _platformQuery);
      if (!mounted) return;
      await showSystemStatusSnack(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }

  Future<void> _pickRange() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showSimpleCalendar(
      context: context,
      from: _from ?? today.subtract(const Duration(days: 30)),
      to: _to ?? today,
    );
    if (picked == null) return;
    setState(() {
      if (picked.cleared) {
        _from = null;
        _to = null;
      } else {
        _from = _dateOnly(picked.range!.start);
        _to = _dateOnly(picked.range!.end);
      }
      _page = 1;
    });
  }

  ShopConn? get _selectedShop {
    if (_shop == 'all') return null;
    for (final s in ShopStore.instance.realShops) {
      if ('${s.channel.name}|${s.apiShopId}' == _shop) return s;
      if ('${s.channel.name}|${s.shopId}' == _shop) return s;
      if ('${s.channel.name}|${s.shop}' == _shop) return s;
    }
    return null;
  }

  bool _matchShop(Order o) {
    final shop = _selectedShop;
    if (shop == null) return true;
    if (o.channel != shop.channel) return false;
    final sameCh = [
      for (final s in ShopStore.instance.realShops)
        if (s.isReal && s.channel == shop.channel) s,
    ];
    if (sameCh.length <= 1) return true;
    final orderKeys = {
      for (final v in [o.shopId, o.shopName, o.companyId])
        if (v.trim().isNotEmpty && v.trim() != '-') v.trim().toLowerCase(),
    };
    if (orderKeys.isEmpty) return true;
    final want = shop.identityKeys;
    return orderKeys.any((id) => want.contains(id) || want.any((w) => w.contains(id) || id.contains(w)));
  }

  DateTime? _lastSyncAt() {
    DateTime? last;
    for (final s in ShopStore.instance.realShops) {
      final t = s.lastSync;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    for (final o in OrderStore.instance.orders) {
      final t = o.lastSyncedAt;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return last;
  }

  List<Order> _filtered() {
    final q = _q.toLowerCase();
    return OrderStore.instance.orders.where((o) {
      if (_ch != 'all' && o.channel.name != _ch) return false;
      if (!_matchShop(o)) return false;
      if (_st != 'all' && o.status.name != _st) return false;
      if (_sap != 'all' && _sapKey(o) != _sap) return false;
      if (_hasDateFilter) {
        final day = _dateOnly(o.createdAt);
        if (day.isBefore(_from!) || day.isAfter(_to!)) return false;
      }
      if (q.isNotEmpty && !o.id.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        OrderStore.instance,
        ShopStore.instance,
        MarketplaceSyncStore.instance,
      ]),
      builder: (context, _) {
        final store = OrderStore.instance;
        final syncStore = MarketplaceSyncStore.instance;
        final all = _filtered();
        final pages = (all.length / _pageSize).ceil().clamp(1, 9999);
        if (_page > pages) _page = pages;
        final start = (_page - 1) * _pageSize;
        final rows = all.skip(start).take(_pageSize).toList();
        final busy = store.loading || syncStore.syncing;
        final fromN = all.isEmpty ? 0 : start + 1;
        final toN = start + rows.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('คำสั่งซื้อ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'รายการคำสั่งซื้อจาก Shopee, Lazada และ TikTok',
                style: TextStyle(color: Pal.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Panel(
                pad: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _lastSyncAt() == null ? 'Sync ล่าสุด : -' : 'Sync ล่าสุด : ${dtFmt.format(_lastSyncAt()!)}',
                        style: const TextStyle(color: Pal.muted, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Drop<String>(
                          label: 'แพลตฟอร์ม',
                          value: _ch,
                          width: 160,
                          onChanged: (v) {
                            _ch = v ?? 'all';
                            _shop = 'all';
                            _page = 1;
                            setState(() {});
                            _searchTap();
                          },
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                          ],
                        ),
                        Drop<String>(
                          label: 'ร้านค้า',
                          value: _shop,
                          width: 200,
                          onChanged: (v) => setState(() {
                            _shop = v ?? 'all';
                            _page = 1;
                          }),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทุกร้าน')),
                            for (final s in ShopStore.instance.realShops)
                              if (s.isReal && (_ch == 'all' || s.channel.name == _ch))
                                DropdownMenuItem(
                                  value: '${s.channel.name}|${s.apiShopId.isNotEmpty ? s.apiShopId : s.shop}',
                                  child: Text(s.displayName),
                                ),
                          ],
                        ),
                        Drop<String>(
                          label: 'สถานะ',
                          value: _st,
                          width: 200,
                          onChanged: (v) => setState(() {
                            _st = v ?? 'all';
                            _page = 1;
                          }),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'unpaid', child: Text('รอชำระเงิน')),
                            DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
                            DropdownMenuItem(value: 'shipping', child: Text('กำลังจัดส่ง')),
                            DropdownMenuItem(value: 'success', child: Text('สำเร็จ')),
                            DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
                            DropdownMenuItem(value: 'returned', child: Text('คืนสินค้า/คืนเงิน')),
                          ],
                        ),
                        Drop<String>(
                          label: 'สถานะ SAP',
                          value: _sap,
                          width: 180,
                          onChanged: (v) => setState(() {
                            _sap = v ?? 'all';
                            _page = 1;
                          }),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'wait', child: Text('รอ SAP')),
                            DropdownMenuItem(value: 'ok', child: Text('สำเร็จ')),
                            DropdownMenuItem(value: 'error', child: Text('SAP ล้มเหลว')),
                          ],
                        ),
                        DateRangeField(from: _from, to: _to, onTap: _pickRange),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            onSubmitted: (_) => _searchTap(),
                            decoration: const InputDecoration(
                              hintText: 'ค้นหาเลขคำสั่งซื้อ',
                              prefixIcon: Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: busy ? null : _searchTap,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('ค้นหา'),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : _syncNow,
                            icon: syncStore.syncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 18),
                            label: Text(syncStore.syncing ? 'กำลัง Sync...' : 'Sync Now'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Pal.text,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Pal.line),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (store.error != null) ...[
                      const SizedBox(height: 12),
                      Text(store.error!, style: const TextStyle(color: Pal.err)),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    const SizedBox(height: 16),
                    DataTable(
                      headingRowColor: tableHeadBg,
                      headingTextStyle: tableHead,
                      headingRowHeight: 40,
                      horizontalMargin: 8,
                      columnSpacing: 16,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Order No.')),
                        DataColumn(label: Text('Platform')),
                        DataColumn(label: Text('ชื่อร้าน')),
                        DataColumn(label: Text('วันที่')),
                        DataColumn(label: Text('ยอดรวม')),
                        DataColumn(label: Text('สถานะออเดอร์')),
                        DataColumn(label: Text('สถานะ SAP')),
                        DataColumn(label: Text('SAP DocNum')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: [
                        for (var i = 0; i < rows.length; i++)
                          DataRow(
                            cells: [
                              DataCell(Text('${start + i + 1}', style: const TextStyle(color: Pal.muted))),
                              DataCell(Text(rows[i].id, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(ChannelLabel(channel: rows[i].channel)),
                              DataCell(Text(
                                ShopStore.instance.nameFor(channel: rows[i].channel, shopId: rows[i].shopId, shopName: rows[i].shopName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                              DataCell(Text(dtFmt.format(rows[i].createdAt))),
                              DataCell(Text(baht.format(rows[i].total), style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(orderPill(rows[i].status)),
                              DataCell(orderSyncPill(
                                rows[i].sapDocNum != null && rows[i].sapDocNum!.isNotEmpty
                                    ? 'sap_ok'
                                    : rows[i].syncStatus,
                              )),
                              DataCell(Text(rows[i].sapDocNum ?? '-')),
                              DataCell(
                                TextButton(
                                  onPressed: () => context.go('/orders/${Uri.encodeComponent(rows[i].id)}'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('ดูรายละเอียด'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (rows.isEmpty && !busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ไม่พบคำสั่งซื้อ')),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          all.isEmpty
                              ? 'แสดง 0 รายการ'
                              : 'แสดง $fromN - $toN จาก ${all.length} รายการ',
                          style: const TextStyle(color: Pal.muted, fontSize: 13),
                        ),
                        const Spacer(),
                        Pages(page: _page, total: pages, onTap: (p) => setState(() => _page = p)),
                      ],
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
