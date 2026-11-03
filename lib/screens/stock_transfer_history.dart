import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../widgets/sync_status.dart';
import '../widgets/ui.dart';

class _TrDraft {
  _TrDraft({
    required this.channel,
    required this.docNo,
    required this.fromCode,
    required this.toCode,
    required this.orders,
    required this.items,
  });

  final Channel channel;
  final String docNo;
  final String fromCode;
  final String toCode;
  final List<Order> orders;
  final List<StockTransferLine> items;

  int get lineCount {
    final n = orders.fold<int>(0, (a, o) => a + o.lines.length);
    if (n > 0) return n;
    if (items.isNotEmpty) return items.length;
    return orders.length;
  }

  String get soRef => [for (final o in orders) o.id].join(', ');
}

class _TrSendResult {
  _TrSendResult({required this.draft, this.row, this.error});

  final _TrDraft draft;
  final StockTransfer? row;
  final String? error;

  bool get ok => error == null && row != null;
}

class StockTransferHistoryScreen extends StatefulWidget {
  const StockTransferHistoryScreen({super.key});

  @override
  State<StockTransferHistoryScreen> createState() => _StockTransferHistoryScreenState();
}

class _StockTransferHistoryScreenState extends State<StockTransferHistoryScreen> {
  int _tab = 0;
  String _platform = 'all';
  String _st = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  final _search = TextEditingController();
  final _selected = <String>{};
  int _page = 1;
  int _histPage = 1;
  static const _pageSize = 5;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _toDate = today;
    _fromDate = today.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      TransferStore.instance.load();
      final orders = OrderStore.instance;
      if (orders.orders.isEmpty) {
        orders.load();
      } else {
        orders.load(silent: true);
      }
      if (ShopStore.instance.realShops.isEmpty) ShopStore.instance.load();
      if (SyncLogStore.instance.logs.isEmpty) SyncLogStore.instance.load();
      try {
        final opts = await Api.getErpOptions();
        if (!mounted) return;
        if (opts.warehouseNames.isNotEmpty) {
          setState(() => setLiveWarehouses(opts.warehouseNames));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime? _lastSyncAt() {
    DateTime? last;
    for (final s in ShopStore.instance.realShops) {
      final t = s.lastSync;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    for (final l in SyncLogStore.instance.logs) {
      if (l.status != SyncStatus.success && l.status != SyncStatus.partial) continue;
      if (last == null || l.time.isAfter(last)) last = l.time;
    }
    return last;
  }

  Future<void> _syncNow() async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await Future.wait([
        OrderStore.instance.load(),
        ShopStore.instance.load(),
        SyncLogStore.instance.load(),
        TransferStore.instance.load(),
      ]);
      if (!mounted) return;
      await showSystemStatusSnack(context, reload: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }

  Future<void> _pickRange() async {
    final today = dateOnly(DateTime.now());
    final picked = await showSimpleCalendar(
      context: context,
      from: _fromDate ?? today.subtract(const Duration(days: 30)),
      to: _toDate ?? today,
    );
    if (picked == null) return;
    setState(() {
      if (picked.cleared) {
        _fromDate = null;
        _toDate = null;
      } else {
        _fromDate = dateOnly(picked.range!.start);
        _toDate = dateOnly(picked.range!.end);
      }
      _page = 1;
      _histPage = 1;
    });
  }

  void _clearFilters() {
    final today = dateOnly(DateTime.now());
    setState(() {
      _platform = 'all';
      _st = 'all';
      _search.clear();
      _toDate = today;
      _fromDate = today.subtract(const Duration(days: 30));
      _page = 1;
      _histPage = 1;
    });
  }

  ButtonStyle get _boxBtn => OutlinedButton.styleFrom(
        foregroundColor: Pal.text,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Pal.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );

  ButtonStyle get _searchBtn => ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  static const _btnH = 36.0;

  StockTransfer? _trFor(Order o) {
    final keys = <String>{
      o.id,
      if (o.sapDocNum != null && o.sapDocNum!.isNotEmpty) o.sapDocNum!,
      if (o.sapDocNum != null && o.sapDocNum!.isNotEmpty) 'SO-${o.sapDocNum}',
      if (o.transferDocNum.isNotEmpty) o.transferDocNum,
    };
    for (final t in TransferStore.instance.rows) {
      if (keys.contains(t.id) || keys.contains(t.referenceNo)) return t;
      final parts = <String>{
        ...t.salesOrderIds,
        ...t.referenceNo.split(RegExp(r'[,;]+')).map((part) => part.trim()).where((part) => part.isNotEmpty),
      };
      if (parts.any(keys.contains)) return t;
    }
    return null;
  }

  String _soKind(Order o) {
    final linked = o.transferStatus.toLowerCase();
    if (linked.contains('fail') || linked.contains('error')) return 'fail';
    if (linked.contains('success') || linked.contains('done') || linked.contains('complete')) return 'done';
    if (linked.contains('pending') || linked.contains('wait')) return 'sent';
    final tr = _trFor(o);
    if (tr == null) return 'ready';
    final s = tr.status.toLowerCase();
    if (s.contains('fail') || s.contains('error')) return 'fail';
    if (s.contains('success') || s.contains('done') || s.contains('complete')) return 'done';
    return 'sent';
  }

  bool _canSend(Order o) {
    final kind = _soKind(o);
    return kind == 'ready' || kind == 'fail';
  }

  Widget _soPill(String kind) {
    switch (kind) {
      case 'sent':
        return soSentPill();
      case 'done':
        return soDonePill();
      case 'fail':
        return soFailPill();
      default:
        return soReadyPill();
    }
  }

  bool _orderMatches(Order o, String q) {
    if (q.isEmpty) return true;
    final shop = ShopStore.instance.nameFor(channel: o.channel, shopId: o.shopId, shopName: o.shopName).toLowerCase();
    final sap = (o.sapDocNum ?? '').toLowerCase();
    return o.id.toLowerCase().contains(q) ||
        sap.contains(q) ||
        shop.contains(q) ||
        (o.customer != '-' && o.customer.toLowerCase().contains(q));
  }

  List<Order> get _soRows {
    final q = _search.text.trim().toLowerCase();
    final list = [
      for (final o in OrderStore.instance.orders)
        if ((_platform == 'all' || o.channel.name == _platform) &&
            (_st == 'all' || _soKind(o) == _st || (_st == 'ready' && _soKind(o) == 'ready')) &&
            (q.isNotEmpty || inDayRange(o.createdAt, _fromDate, _toDate)) &&
            _orderMatches(o, q))
          o,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<StockTransfer> get _trRows {
    final q = _search.text.trim().toLowerCase();
    final list = [
      for (final t in TransferStore.instance.rows)
        if ((_platform == 'all' || t.platform == _platform || ChannelX.fromApi(t.platform)?.name == _platform) &&
            (_st == 'all' || t.status.toLowerCase().contains(_st)) &&
            (q.isNotEmpty ||
                _fromDate == null ||
                _toDate == null ||
                t.scheduleDate == null ||
                (!dateOnly(t.scheduleDate!).isBefore(_fromDate!) && !dateOnly(t.scheduleDate!).isAfter(_toDate!))) &&
            (q.isEmpty ||
                t.id.toLowerCase().contains(q) ||
                t.sapDocNum.toLowerCase().contains(q) ||
                t.referenceNo.toLowerCase().contains(q) ||
                t.salesOrderIds.any((id) => id.toLowerCase().contains(q)) ||
                t.requestedBy.toLowerCase().contains(q)))
          t,
    ];
    list.sort((a, b) {
      final da = a.scheduleDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.scheduleDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  static const _fromCode = 'MDL';
  static const _toCode = 'ONLINE';

  String _fromWhs(Order _) => warehouseLabel(_fromCode);

  String _toWhs(Order _) => warehouseLabel(_toCode);

  List<StockTransferLine> _mergeLines(List<Order> orders) {
    final map = <String, StockTransferLine>{};
    for (final o in orders) {
      for (final l in o.lines) {
        final sku = l.sku.trim().isEmpty ? '-' : l.sku.trim();
        final prev = map[sku];
        if (prev == null) {
          map[sku] = StockTransferLine(sku: sku, name: l.name, qty: l.qty);
        } else {
          map[sku] = StockTransferLine(
            sku: sku,
            name: prev.name.isEmpty ? l.name : prev.name,
            qty: prev.qty + l.qty,
          );
        }
      }
    }
    return map.values.toList();
  }

  String _newDocNo(Channel ch, Set<String> used) {
    final tag = ch.shortLabel.replaceAll(' ', '').toUpperCase();
    final day = dayFmt.format(DateTime.now()).replaceAll('/', '');
    var n = 1;
    String next() => n == 1 ? 'TRF-$tag-$day' : 'TRF-$tag-$day-$n';
    while (used.contains(next())) {
      n++;
    }
    final v = next();
    used.add(v);
    return v;
  }

  List<_TrDraft> _draftsFor(List<Order> selected) {
    final used = <String>{
      for (final t in TransferStore.instance.rows) ...[t.id, t.referenceNo],
    };
    used.removeWhere((s) => s.isEmpty || s == '-');
    final grouped = <Channel, List<Order>>{};
    for (final o in selected) {
      grouped.putIfAbsent(o.channel, () => []).add(o);
    }
    final drafts = <_TrDraft>[];
    for (final ch in Channel.values) {
      final orders = grouped[ch];
      if (orders == null || orders.isEmpty) continue;
      drafts.add(
        _TrDraft(
          channel: ch,
          docNo: _newDocNo(ch, used),
          fromCode: _fromCode,
          toCode: _toCode,
          orders: orders,
          items: _mergeLines(orders),
        ),
      );
    }
    return drafts;
  }

  Future<T?> _runBusy<T>(String msg, Future<T> Function() task) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _sendSelected() async {
    if (_sending) return;
    final picked = [
      for (final o in OrderStore.instance.orders)
        if (_selected.contains(o.id)) o,
    ];
    final ready = [for (final o in picked) if (_canSend(o)) o];
    if (ready.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(picked.isEmpty ? 'เลือก Sales Order ก่อนสร้าง TR' : 'รายการที่เลือกสร้าง Transfer Request ไปแล้ว'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _runBusy('กำลังดึงรายการสินค้าจากออเดอร์...', () async {
        for (final o in ready) {
          if (o.lines.isEmpty) await OrderStore.instance.loadOne(o.id);
        }
      });
      if (!mounted) return;

      final selected = [
        for (final o in OrderStore.instance.orders)
          if (_selected.contains(o.id) && _canSend(o)) o,
      ];
      final drafts = _draftsFor(selected);
      if (drafts.isEmpty) return;
      final skipped = _selected.length - selected.length;
      final ok = await _confirmDrafts(drafts, skipped: skipped);
      if (ok != true || !mounted) return;

      final results = await _runBusy('กำลังส่ง Transfer Request...', () async {
        final out = <_TrSendResult>[];
        for (final d in drafts) {
          try {
            final row = await TransferStore.instance.create(
              fromWarehouseId: d.fromCode.isEmpty ? '-' : d.fromCode,
              toWarehouseId: d.toCode.isEmpty ? '-' : d.toCode,
              items: d.items,
              note: 'Transfer Request จาก Sales Order (${d.channel.shortLabel}): ${d.soRef}',
              documentNo: d.docNo,
              referenceNo: d.soRef,
              requestedBy: Session.instance.name,
              dueDate: dateOnly(DateTime.now()),
              platform: d.channel.name,
            );
            out.add(_TrSendResult(draft: d, row: row));
          } catch (e) {
            out.add(
              _TrSendResult(
                draft: d,
                error: e is ApiException ? e.message : e.toString(),
              ),
            );
          }
        }
        return out;
      });
      if (!mounted || results == null) return;
      setState(() => _selected.clear());
      await _showSendResult(results);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool?> _confirmDrafts(List<_TrDraft> drafts, {int skipped = 0}) {
    final totalLines = drafts.fold<int>(0, (a, d) => a + d.lineCount);
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการส่ง Transfer Request'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ระบบจะแยกเอกสารตามแพลตฟอร์ม แพลตฟอร์มละ 1 ใบ',
                  style: TextStyle(color: Pal.muted, fontSize: 13),
                ),
                if (skipped > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ข้าม $skipped รายการที่สร้างไปแล้ว',
                    style: const TextStyle(color: Pal.warn, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 14),
                for (final d in drafts) _draftCard(d),
                Text(
                  'รวม ${drafts.length} ใบเอกสาร · $totalLines รายการ',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text('ยืนยันส่ง (${drafts.length} ใบ)'),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(_TrDraft d) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Pal.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChannelDot(channel: d.channel, size: 22),
              const SizedBox(width: 8),
              Text(d.channel.shortLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Pal.primarySoft, borderRadius: BorderRadius.circular(99)),
                child: const Text('1 ใบ', style: TextStyle(color: Pal.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kv('เลขที่เอกสาร', d.docNo),
          _kv('จำนวนรายการ', '${d.lineCount} รายการ'),
          _kv('จาก Sales Order', '${d.orders.length} ใบ'),
          _kv('อ้างอิง SO', d.soRef),
          _kv('คลังต้นทาง', d.fromCode.isEmpty ? '-' : warehouseLabel(d.fromCode)),
          _kv('คลังปลายทาง', d.toCode.isEmpty ? '-' : warehouseLabel(d.toCode)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendResult(List<_TrSendResult> results) {
    final okN = results.where((r) => r.ok).length;
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(okN == results.length ? 'ส่ง Transfer Request แล้ว' : 'ส่ง Transfer Request บางส่วน'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in results)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Pal.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Pal.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ChannelDot(channel: r.draft.channel, size: 22),
                          const SizedBox(width: 8),
                          Text(r.draft.channel.shortLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const Spacer(),
                          r.ok ? sapStatusPill(r.row?.status ?? 'success') : soFailPill(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _kv('เลขที่เอกสาร', r.draft.docNo),
                      _kv('SAP DocNumber', r.row == null || r.row!.sapDocNum.isEmpty ? '-' : r.row!.sapDocNum),
                      _kv('จำนวนรายการ', '${r.draft.lineCount} รายการ'),
                      _kv('อ้างอิง SO', r.draft.soRef),
                      if (r.error != null) _kv('ข้อผิดพลาด', r.error!),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  String _cust(Order o) {
    final shop = ShopStore.instance.nameFor(channel: o.channel, shopId: o.shopId, shopName: o.shopName);
    if (shop.isNotEmpty && shop != '-') return shop;
    if (o.customer.isNotEmpty && o.customer != '-') return o.customer;
    return '-';
  }

  Widget _plat(Channel ch) {
    return Text(ch.shortLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }

  Widget _detailBtn(StockTransfer t) {
    return TextButton(
      onPressed: () => _openTransfer(t),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text('ดูรายละเอียด'),
    );
  }

  Future<void> _openTransfer(StockTransfer t) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: Row(
          children: [
            const Expanded(child: Text('รายละเอียด Transfer Request', style: TextStyle(fontWeight: FontWeight.w800))),
            sapStatusPill(t.status),
            IconButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('เลขที่เอกสาร', t.id),
                _kv('วันที่โอน', formatDt(t.displayAt)),
                _kv('แพลตฟอร์ม', t.platform.trim().isEmpty ? '-' : (ChannelX.fromApi(t.platform)?.label ?? t.platform)),
                _kv('SAP DocNumber', t.sapDocNum.isEmpty ? '-' : t.sapDocNum),
                _kv('อ้างอิง SO', t.referenceNo.trim().isEmpty ? '-' : t.referenceNo),
                _kv('ผู้ขอโอน', t.requestedBy.trim().isEmpty ? '-' : t.requestedBy),
                _kv('คลังต้นทาง', t.fromLabel),
                _kv('คลังปลายทาง', t.toLabel),
                _kv('จำนวนรายการ', '${t.items.isEmpty ? t.qtyTotal : t.items.length}'),
                _kv('จำนวนโอนรวม', '${t.qtyTotal}'),
                if (t.note.trim().isNotEmpty) _kv('หมายเหตุ', t.note),
                if (t.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('รายการสินค้า', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final line in t.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.name.isEmpty ? line.sku : '${line.sku}  ${line.name}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text('x ${line.qty}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _trPlat(StockTransfer t) {
    final ch = ChannelX.fromApi(t.platform);
    if (ch == null) {
      final label = t.platform.trim();
      return Text(label.isEmpty ? '-' : label, style: const TextStyle(fontWeight: FontWeight.w600));
    }
    return Text(ch.shortLabel, style: const TextStyle(fontWeight: FontWeight.w600));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TransferStore.instance,
        OrderStore.instance,
        ShopStore.instance,
        MarketplaceSyncStore.instance,
        SyncLogStore.instance,
      ]),
      builder: (context, _) {
        final soAll = _soRows;
        final trAll = _trRows;
        final readyN = soAll.where((o) => _soKind(o) == 'ready').length;
        final okN = TransferStore.instance.rows.where((t) => t.status.toLowerCase().contains('success')).length;
        final pendingN = TransferStore.instance.rows.where((t) => t.status.toLowerCase().contains('pending')).length;
        final failN = TransferStore.instance.rows.where((t) => t.status.toLowerCase().contains('fail') || t.status.toLowerCase().contains('error')).length;
        final pages = (soAll.length / _pageSize).ceil().clamp(1, 9999);
        if (_page > pages) _page = pages;
        final start = (_page - 1) * _pageSize;
        final soPage = soAll.skip(start).take(_pageSize).toList();
        final histPages = (trAll.length / _pageSize).ceil().clamp(1, 9999);
        if (_histPage > histPages) _histPage = histPages;
        final histStart = (_histPage - 1) * _pageSize;
        final recent = trAll.skip(histStart).take(_pageSize).toList();
        final allIds = [for (final o in soAll) o.id];
        final selectedN = allIds.where(_selected.contains).length;
        final bool? allSelected =
            allIds.isEmpty ? false : selectedN == 0 ? false : selectedN == allIds.length ? true : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transfer Request จาก Sales Order', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text(
                          'สร้างคำขอโอนสินค้าสำหรับออเดอร์ขาย และติดตามสถานะการส่งเข้า SAP',
                          style: TextStyle(color: Pal.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _tabs(),
              const SizedBox(height: 16),
              _filters(),
              const SizedBox(height: 16),
              _stats(readyN, okN, pendingN, failN),
              const SizedBox(height: 16),
              if (_tab == 0) ...[
                _soPanel(soAll, soPage, start, pages, allSelected, allIds),
                const SizedBox(height: 16),
                _bottom(recent, trAll.length, histStart, histPages),
              ] else
                _historyPanel(trAll),
            ],
          ),
        );
      },
    );
  }

  Widget _tabs() {
    Widget tab(String label, int i, IconData icon) {
      final on = _tab == i;
      return InkWell(
        onTap: () => setState(() => _tab = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: on ? Border.all(color: Pal.line) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: on ? Pal.primary : Pal.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: on ? Pal.primary : Pal.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab('รายการโอน', 0, Icons.list_alt_rounded),
          tab('ประวัติการโอน', 1, Icons.history_rounded),
        ],
      ),
    );
  }

  Widget _filters() {
    final syncing = MarketplaceSyncStore.instance.syncing;
    return Panel(
      pad: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 210),
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                DateRangeField(from: _fromDate, to: _toDate, onTap: _pickRange, width: 220),
                Drop<String>(
                  label: 'Platform',
                  value: _platform,
                  width: 132,
                  onChanged: (v) => setState(() {
                    _platform = v ?? 'all';
                    _page = 1;
                    _histPage = 1;
                  }),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                    ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                  ],
                ),
                Drop<String>(
                  label: 'สถานะ',
                  value: _st,
                  width: 140,
                  onChanged: (v) => setState(() {
                    _st = v ?? 'all';
                    _page = 1;
                    _histPage = 1;
                  }),
                  items: _tab == 0
                      ? const [
                          DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                          DropdownMenuItem(value: 'ready', child: Text('พร้อมสร้าง')),
                          DropdownMenuItem(value: 'sent', child: Text('ส่ง SAP')),
                          DropdownMenuItem(value: 'done', child: Text('สำเร็จ')),
                          DropdownMenuItem(value: 'fail', child: Text('ผิดพลาด')),
                        ]
                      : const [
                          DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                          DropdownMenuItem(value: 'success', child: Text('Success')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending SAP')),
                          DropdownMenuItem(value: 'failed', child: Text('Failed')),
                        ],
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => setState(() {
                      _page = 1;
                      _histPage = 1;
                    }),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาเลขที่ SO / ลูกค้า / Reference No.',
                      hintStyle: TextStyle(fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                SizedBox(
                  height: _btnH,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _page = 1;
                      _histPage = 1;
                    }),
                    style: _searchBtn,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('ค้นหา', style: TextStyle(fontSize: 13)),
                  ),
                ),
                SizedBox(
                  height: _btnH,
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: _boxBtn,
                    child: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 13)),
                  ),
                ),
                LastSyncButton(syncing: syncing, onSync: syncing ? null : _syncNow),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: LastSyncLabel(lastSync: _lastSyncAt()),
          ),
        ],
      ),
    );
  }

  Widget _stats(int ready, int ok, int pending, int fail) {
    final cards = [
      StatCard(
        title: 'SO รอโอน',
        value: '$ready',
        icon: Icons.inventory_2_outlined,
        color: Pal.primary,
        hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
      ),
      StatCard(
        title: 'TR ส่งเข้า SAP สำเร็จ',
        value: '$ok',
        icon: Icons.check_circle_outline_rounded,
        color: Pal.ok,
        hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
      ),
      StatCard(
        title: 'Pending SAP',
        value: '$pending',
        icon: Icons.schedule_rounded,
        color: Pal.warn,
        hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
      ),
      StatCard(
        title: 'Failed',
        value: '$fail',
        icon: Icons.cancel_outlined,
        color: Pal.err,
        hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
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
    );
  }

  Widget _soPanel(List<Order> all, List<Order> rows, int start, int pages, bool? allSelected, List<String> allIds) {
    return Panel(
      pad: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      title: 'รายการ Sales Order สำหรับสร้าง Transfer Request',
      trailing: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _selected.isEmpty || _sending ? null : _sendSelected,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(_sending ? 'กำลังส่ง...' : 'สร้าง TR การขายที่เลือก (${_selected.length})'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 10),
          Text('เลือกแล้ว ${_selected.length} รายการ', style: const TextStyle(color: Pal.muted, fontSize: 13)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DataTable(
            headingRowColor: tableHeadBg,
            headingTextStyle: tableHead,
            headingRowHeight: 44,
            columnSpacing: 14,
            horizontalMargin: 8,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            showCheckboxColumn: false,
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 28,
                  child: Checkbox(
                    tristate: true,
                    value: allSelected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: allIds.isEmpty
                        ? null
                        : (_) => setState(() {
                              if (allSelected == true) {
                                _selected.removeAll(allIds);
                              } else {
                                _selected.addAll(allIds);
                              }
                            }),
                  ),
                ),
              ),
              const DataColumn(label: Text('วันที่', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('Sales Order No.', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('ลูกค้า', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('Platform', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('คลังต้นทาง', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('คลังปลายทาง', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('จำนวนรายการ', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('จำนวนรวม', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('สถานะ', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('SAP Status', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('Action', maxLines: 1, softWrap: false)),
            ],
            rows: [
              for (final o in rows)
                DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: _selected.contains(o.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(o.id);
                          } else {
                            _selected.remove(o.id);
                          }
                        }),
                      ),
                    ),
                    DataCell(Text(dtFmt.format(o.createdAt))),
                    DataCell(Text(o.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(_cust(o), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DataCell(_plat(o.channel)),
                    DataCell(Text(_fromWhs(o), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DataCell(Text(_toWhs(o), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DataCell(Text(o.lines.isNotEmpty ? '${o.lines.length}' : (o.itemCount > 0 ? '${o.itemCount}' : '-'))),
                    DataCell(Text(nFmt.format(o.total))),
                    DataCell(_soPill(_soKind(o))),
                    DataCell(sapStatusPill(_trFor(o)?.status.isNotEmpty == true ? _trFor(o)!.status : o.transferStatus)),
                    DataCell(
                      TextButton(
                        onPressed: () => context.go('/orders/${Uri.encodeComponent(o.id)}'),
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
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('ยังไม่มี Sales Order สำหรับสร้าง Transfer Request', style: TextStyle(color: Pal.muted))),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                all.isEmpty ? 'แสดง 0 รายการ' : 'แสดง ${start + 1} - ${start + rows.length} จาก ${all.length} รายการ',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
              Pages(page: _page, total: pages, onTap: (p) => setState(() => _page = p)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyPanel(List<StockTransfer> rows) {
    return Panel(
      title: 'รายการประวัติการโอน',
      pad: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DataTable(
            headingRowColor: tableHeadBg,
            headingTextStyle: tableHead,
            headingRowHeight: 44,
            columnSpacing: 16,
            horizontalMargin: 8,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columns: const [
              DataColumn(label: Text('วันที่โอน', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('แพลตฟอร์ม', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('SAP DocNumber', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('อ้างอิง SO', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('จำนวนสินค้า', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('สถานะ', maxLines: 1, softWrap: false)),
              DataColumn(label: Text('Action', maxLines: 1, softWrap: false)),
            ],
            rows: [
              for (final t in rows)
                DataRow(
                  cells: [
                    DataCell(Text(formatDt(t.displayAt))),
                    DataCell(_trPlat(t)),
                    DataCell(Text(t.sapDocNum.isEmpty ? '-' : t.sapDocNum)),
                    DataCell(_clipText(t.referenceNo)),
                    DataCell(Text('${t.items.length}')),
                    DataCell(sapStatusPill(t.status)),
                    DataCell(_detailBtn(t), onTap: () => _openTransfer(t)),
                  ],
                ),
            ],
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('ยังไม่มีข้อมูลประวัติการโอน', style: TextStyle(color: Pal.muted))),
            ),
        ],
      ),
    );
  }

  Widget _clipText(String raw, {TextStyle? style}) {
    final t = raw.trim().isEmpty || raw == '-' ? '-' : raw;
    return Tooltip(
      message: t,
      waitDuration: const Duration(milliseconds: 400),
      child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }

  Widget _recentTable(List<StockTransfer> recent) {
    Widget head(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Text(label, style: tableHead, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }

    Widget cell(Widget child, {double pad = 8}) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
        child: child,
      );
    }

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: FlexColumnWidth(0.9),
        3: FlexColumnWidth(1.6),
        4: IntrinsicColumnWidth(),
        5: IntrinsicColumnWidth(),
        6: IntrinsicColumnWidth(),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            head('วันที่โอน'),
            head('แพลตฟอร์ม'),
            head('SAP DocNumber'),
            head('อ้างอิง SO'),
            head('จำนวนสินค้า'),
            head('สถานะ'),
            head('Action'),
          ],
        ),
        for (final t in recent)
          TableRow(
            children: [
              cell(Text(formatDt(t.displayAt), maxLines: 1, overflow: TextOverflow.ellipsis)),
              cell(_trPlat(t)),
              cell(_clipText(t.sapDocNum)),
              cell(_clipText(t.referenceNo)),
              cell(Text('${t.items.length}')),
              cell(sapStatusPill(t.status)),
              cell(_detailBtn(t)),
            ],
          ),
      ],
    );
  }

  Widget _bottom(List<StockTransfer> recent, int total, int start, int pages) {
    return Panel(
      pad: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      title: 'ประวัติการโอนล่าสุด',
      trailing: TextButton(
        onPressed: () => setState(() => _tab = 1),
        child: const Text('ดูประวัติการโอนทั้งหมด →'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('ยังไม่มีประวัติการโอน', style: TextStyle(color: Pal.muted)),
            )
          else
            _recentTable(recent),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                total == 0 ? 'แสดง 0 รายการ' : 'แสดง ${start + 1} - ${start + recent.length} จาก $total รายการ',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
              Pages(page: _histPage, total: pages, onTap: (p) => setState(() => _histPage = p)),
            ],
          ),
        ],
      ),
    );
  }
}
