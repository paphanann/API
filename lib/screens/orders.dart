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

  String _ch = 'all';
  String _shop = 'all';
  String _st = 'all';
  String _sap = 'all';
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

    final hasSo = (o.sapDocNum ?? '').trim().isNotEmpty;
    final hasDelivery = (o.deliveryDocNum ?? '').trim().isNotEmpty;

    if (hasDelivery) return 'delivery_ok';
    if (hasSo) return 'delivery_wait';
    return 'wait';
  }

  bool _sapMatch(Order o) {
    if (_sap == 'all') return true;
    final key = _sapKey(o);
    switch (_sap) {
      case 'so_ok':
        return key == 'so_ok' || key == 'delivery_wait' || key == 'delivery_ok';
      case 'ok':
        return key == 'ok' || key == 'delivery_ok';
      default:
        return key == _sap;
    }
  }

  String _sapPill(Order o) {
    if (_sap == 'so_ok' && _sapMatch(o)) return 'so_ok';
    return _sapKey(o);
  }

  String? get _platformQuery => _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;

  String? get _shopQuery {
    if (_shop == 'all') return null;
    final cut = _shop.indexOf('|');
    final id = cut >= 0 ? _shop.substring(cut + 1) : _shop;
    if (id.isEmpty || id == '-') return null;
    return id;
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
        status: _st,
        sap: _sap,
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

  void _applyPeriod(DatePeriod period) {
    if (period == DatePeriod.custom) {
      _pickRange().whenComplete(() {
        if (mounted) setState(() {});
      });
      return;
    }
    final range = rangeOfPeriod(period);
    setState(() {
      _from = range.$1;
      _to = range.$2;
      _page = 1;
    });
    _reload();
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
    if (_sap == 'invoice_wait' || _sap == 'invoice_fail') _sap = 'all';
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
                        Drop<String>(
                          label: 'แพลตฟอร์ม',
                          value: _ch,
                          width: 128,
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
                          width: 140,
                          onChanged: (v) {
                            setState(() {
                              _shop = v ?? 'all';
                              _page = 1;
                            });
                            _reload();
                          },
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
                          width: 128,
                          onChanged: (v) {
                            setState(() {
                              _st = v ?? 'all';
                              _page = 1;
                            });
                            _reload();
                          },
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
                          width: 168,
                          onChanged: (v) {
                            setState(() {
                              _sap = v ?? 'all';
                              _page = 1;
                            });
                            _reload();
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'wait', child: Text('รอสร้างใบ SO')),
                            DropdownMenuItem(value: 'so_ok', child: Text('สร้างใบ SO สำเร็จ')),
                            DropdownMenuItem(value: 'so_fail', child: Text('ใบ SO ล้มเหลว')),
                            DropdownMenuItem(value: 'delivery_wait', child: Text('รอสร้าง Delivery')),
                            DropdownMenuItem(value: 'delivery_ok', child: Text('สร้าง Delivery สำเร็จ')),
                            DropdownMenuItem(value: 'delivery_fail', child: Text('Delivery ล้มเหลว')),
                            DropdownMenuItem(value: 'ok', child: Text('สำเร็จ')),
                            DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
                          ],
                        ),
                        DateRangeField(from: _from, to: _to, onTap: _pickRange),
                        PeriodField(value: periodOfRange(_from, _to), onChanged: _applyPeriod),
                        SizedBox(
                          width: 168,
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            onSubmitted: (_) => _searchTap(),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'ค้นหาเลขคำสั่งซื้อ',
                              hintStyle: TextStyle(fontSize: 12),
                              prefixIcon: Icon(Icons.search, size: 16),
                              prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: busy ? null : _searchTap,
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('ค้นหา', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        LastSyncButton(syncing: syncStore.syncing, onSync: busy ? null : _syncNow),
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
                        minWidth: 1180,
                        widths: const [
                          FixedColumnWidth(48),
                          FlexColumnWidth(1.6),
                          FlexColumnWidth(1.0),
                          FlexColumnWidth(1.3),
                          FlexColumnWidth(1.2),
                          FlexColumnWidth(1.0),
                          FlexColumnWidth(1.1),
                          FlexColumnWidth(1.1),
                          FlexColumnWidth(1.0),
                          FlexColumnWidth(0.9),
                          FlexColumnWidth(1.0),
                        ],
                        headers: const [
                          Text('#'),
                          Text('Order No.'),
                          Text('Platform'),
                          Text('ชื่อร้าน'),
                          Text('วันที่'),
                          Text('ยอดรวม'),
                          Text('สถานะออเดอร์'),
                          Text('สถานะ SAP'),
                          Text('ใบ SO', maxLines: 1, softWrap: false),
                          Text('Delivery', maxLines: 1, softWrap: false),
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
                              Text(dtFmt.format(rows[i].createdAt)),
                              Text(baht.format(rows[i].total), style: const TextStyle(fontWeight: FontWeight.w600)),
                              orderPill(rows[i].status),
                              orderSyncPill(_sapPill(rows[i])),
                              Text(rows[i].sapDocNum ?? '-'),
                              Text((rows[i].deliveryDocNum ?? '').trim().isEmpty ? '-' : rows[i].deliveryDocNum!),
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
