import 'dart:async';

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
  static const _pageSize = 50;

  Set<String> _ch = {};
  Set<String> _shops = {};
  Set<String> _st = {};
  Set<String> _sap = {};
  String _q = '';
  int _page = 1;
  DateTime? _from = DateTime(2026, 10, 1);
  DateTime? _to;
  final _search = TextEditingController();
  List<Order> _rows = [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _req = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reload();
      if (ShopStore.instance.realShops.isEmpty) ShopStore.instance.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  String _sapKey(Order o) {
    if (o.status == OrderStatus.cancelled) return 'cancelled';

    final inv = o.invoiceStatus.trim().toLowerCase();
    final sync = o.syncStatus.trim().toLowerCase();
    final invoiceFail = inv.contains('fail') || inv.contains('error') || inv.contains('ล้มเหลว');
    final deliveryFail = sync.contains('delivery_error') || sync.contains('delivery_fail');
    final soFail = sync.contains('sap_error') || sync.contains('so_fail') || sync.contains('error') || sync.contains('fail');

    if (o.hasInvoiceDoc) return 'invoice_ok';
    if (invoiceFail) return 'invoice_fail';
    if (o.hasDeliveryDoc) return 'delivery_ok';
    if (deliveryFail) return 'delivery_fail';
    if (o.hasSoDoc) return 'delivery_wait';
    if (soFail) return 'so_fail';
    return 'wait';
  }

  String _sapPill(Order o) {
    final key = _sapKey(o);
    if (_sap.length == 1 && _sap.contains('so_ok') && key == 'delivery_wait') return 'so_ok';
    return key;
  }

  String? get _platformQuery {
    if (_ch.isEmpty) return null;
    return _ch.map((name) => Channel.values.byName(name).apiPlatform).join(',');
  }

  String? get _shopQuery {
    if (_shops.isEmpty) return null;
    final ids = <String>[
      for (final value in _shops)
        if (value.contains('|')) value.substring(value.indexOf('|') + 1) else value,
    ].where((id) => id.isNotEmpty && id != '-').toList();
    if (ids.isEmpty) return null;
    return ids.join(',');
  }

  void _setPlatforms(Set<String> next) {
    final shops = {..._shops};
    if (next.isNotEmpty) {
      shops.removeWhere((value) {
        final cut = value.indexOf('|');
        final channel = cut >= 0 ? value.substring(0, cut) : '';
        return channel.isNotEmpty && !next.contains(channel);
      });
    }
    setState(() {
      _ch = next;
      _shops = shops;
      _page = 1;
    });
    _reload();
  }

  Future<void> _reload() async {
    final req = ++_req;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await Api.getOrdersPage(
        platform: _platformQuery,
        shopId: _shopQuery,
        status: _st.isEmpty ? null : _st.join(','),
        sap: _sap.isEmpty ? null : _sap.join(','),
        q: _q,
        from: _from,
        to: _to,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || req != _req) return;
      setState(() {
        _rows = page.items;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || req != _req) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _searchTap() async {
    _searchDebounce?.cancel();
    setState(() {
      _q = _search.text.trim();
      _page = 1;
    });
    await _reload();
  }

  void _onQuery(String v) {
    _q = v;
    _page = 1;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload();
    });
  }

  Future<void> _syncNow() async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await _reload();
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
    await _reload();
  }

  DateTime? _lastSyncAt() {
    DateTime? last;
    for (final s in ShopStore.instance.realShops) {
      final t = s.lastSync;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return last;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ShopStore.instance,
        MarketplaceSyncStore.instance,
      ]),
      builder: (context, _) {
        final syncStore = MarketplaceSyncStore.instance;
        final pages = (_total / _pageSize).ceil().clamp(1, 9999);
        final start = (_page - 1) * _pageSize;
        final rows = _rows;
        final busy = _loading || syncStore.syncing;
        final fromN = _total == 0 ? 0 : start + 1;
        final toN = start + rows.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('คำสั่งซื้อ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'รายการคำสั่งซื้อจาก Shopee, Lazada และ TikTok',
                style: TextStyle(color: Pal.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Panel(
                  expand: true,
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
                      spacing: 8,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        MultiDrop(
                          label: 'แพลตฟอร์ม',
                          selected: _ch,
                          width: 168,
                          onChanged: _setPlatforms,
                          options: [
                            const CheckOption('all', 'ทั้งหมด'),
                            for (final c in Channel.values) CheckOption(c.name, c.label),
                          ],
                        ),
                        MultiDrop(
                          label: 'ร้านค้า',
                          selected: _shops,
                          width: 200,
                          onChanged: (v) {
                            setState(() {
                              _shops = v;
                              _page = 1;
                            });
                            _reload();
                          },
                          options: [
                            const CheckOption('all', 'ทุกร้าน'),
                            for (final s in ShopStore.instance.realShops)
                              if (s.isReal && (_ch.isEmpty || _ch.contains(s.channel.name)))
                                CheckOption(
                                  '${s.channel.name}|${s.apiShopId.isNotEmpty ? s.apiShopId : s.shop}',
                                  s.displayName,
                                ),
                          ],
                        ),
                        MultiDrop(
                          label: 'สถานะ',
                          selected: _st,
                          width: 188,
                          onChanged: (v) {
                            setState(() {
                              _st = v;
                              _page = 1;
                            });
                            _reload();
                          },
                          options: const [
                            CheckOption('all', 'ทั้งหมด'),
                            CheckOption('unpaid', 'รอชำระเงิน'),
                            CheckOption('pending', 'รอดำเนินการ'),
                            CheckOption('shipping', 'กำลังจัดส่ง'),
                            CheckOption('success', 'สำเร็จ'),
                            CheckOption('cancelled', 'ยกเลิก'),
                            CheckOption('returned', 'คืนสินค้า/คืนเงิน'),
                          ],
                        ),
                        MultiDrop(
                          label: 'สถานะ SAP',
                          selected: _sap,
                          width: 300,
                          onChanged: (v) {
                            setState(() {
                              _sap = v;
                              _page = 1;
                            });
                            _reload();
                          },
                          options: const [
                            CheckOption('all', 'ทั้งหมด'),
                            CheckOption('wait', 'รอสร้าง SO'),
                            CheckOption('so_ok', 'สร้าง SO สำเร็จ'),
                            CheckOption('so_fail', 'SO ล้มเหลว'),
                            CheckOption('delivery_ok', 'สร้าง Delivery สำเร็จ'),
                            CheckOption('delivery_fail', 'Delivery ล้มเหลว'),
                            CheckOption('invoice_ok', 'สร้าง A/R Invoice สำเร็จ'),
                            CheckOption('invoice_fail', 'A/R Invoice ล้มเหลว'),
                            CheckOption('ok', 'สำเร็จ'),
                            CheckOption('cancelled', 'ยกเลิก'),
                          ],
                        ),
                        DateRangeField(from: _from, to: _to, onTap: _pickRange),
                        SizedBox(
                          width: 168,
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            onSubmitted: (_) => _searchTap(),
                            style: const TextStyle(fontSize: 13),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: const InputDecoration(
                              hintText: 'ค้นหาเลขคำสั่งซื้อ',
                              hintStyle: TextStyle(fontSize: 12),
                              prefixIcon: Icon(Icons.search, size: 16),
                              prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32),
                              isDense: true,
                              contentPadding: EdgeInsets.fromLTRB(0, 8, 12, 8),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: busy ? null : _searchTap,
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('ค้นหา', style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : _syncNow,
                            icon: syncStore.syncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(syncStore.syncing ? 'กำลัง Sync...' : 'Sync Now', style: const TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Pal.text,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Pal.line),
                              shape: const StadiumBorder(),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Pal.err)),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: StickyTable(
                        minWidth: 1520,
                        widths: const [
                          FixedColumnWidth(44),
                          FlexColumnWidth(1.2),
                          FlexColumnWidth(0.8),
                          FlexColumnWidth(1.55),
                          FixedColumnWidth(168),
                          FlexColumnWidth(0.8),
                          FlexColumnWidth(0.95),
                          FlexColumnWidth(1.5),
                          FlexColumnWidth(0.85),
                          FlexColumnWidth(0.75),
                          FlexColumnWidth(0.8),
                          FlexColumnWidth(0.9),
                        ],
                        aligns: const [
                          Alignment.centerLeft,
                          Alignment.centerLeft,
                          Alignment.centerLeft,
                          Alignment.centerLeft,
                          Alignment.centerLeft,
                          Alignment.centerRight,
                        ],
                        headers: const [
                          Text('#'),
                          Text('Order No.'),
                          Text('Platform'),
                          Text('ชื่อร้าน'),
                          Text('วันที่'),
                          Text('ยอดรวม', textAlign: TextAlign.right),
                          Text('สถานะออเดอร์'),
                          Text('สถานะ SAP'),
                          Text('Sales Order', maxLines: 1, softWrap: false),
                          Text('Delivery', maxLines: 1, softWrap: false),
                          Text('A/R Invoice', maxLines: 1, softWrap: false),
                          Text('Action'),
                        ],
                        rows: [
                          for (var i = 0; i < rows.length; i++)
                            [
                              Text('${start + i + 1}', style: const TextStyle(color: Pal.muted)),
                              Text(rows[i].id, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ChannelLabel(channel: rows[i].channel),
                              Text(
                                ShopStore.instance.nameFor(channel: rows[i].channel, shopId: rows[i].shopId, shopName: rows[i].shopName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                dtFmt.format(rows[i].createdAt),
                                maxLines: 1,
                                softWrap: false,
                              ),
                              Text(baht.format(rows[i].total), style: const TextStyle(fontWeight: FontWeight.w600)),
                              orderPill(rows[i].status),
                              orderSyncPill(_sapPill(rows[i])),
                              Text(rows[i].sapDocNum ?? '-'),
                              Text((rows[i].deliveryDocNum ?? '').trim().isEmpty ? '-' : rows[i].deliveryDocNum!),
                              Text((rows[i].invoiceDocNum ?? '').trim().isEmpty ? '-' : rows[i].invoiceDocNum!),
                              TextButton(
                                onPressed: () => context.go('/orders/${Uri.encodeComponent(rows[i].id)}'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: const Text('ดูรายละเอียด'),
                              ),
                            ],
                        ],
                      ),
                    ),
                    if (rows.isEmpty && !_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ไม่พบคำสั่งซื้อ')),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          _loading && _total == 0
                              ? 'กำลังโหลด...'
                              : _total == 0
                                  ? 'แสดง 0 รายการ'
                                  : 'แสดง $fromN - $toN จาก $_total รายการ',
                          style: const TextStyle(color: Pal.muted, fontSize: 13),
                        ),
                        const Spacer(),
                        Pages(
                          page: _page,
                          total: pages,
                          onTap: (p) {
                            if (p == _page) return;
                            setState(() => _page = p);
                            _reload();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
