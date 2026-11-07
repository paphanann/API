import 'dart:async';

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
  static const _pageSize = 50;
  bool _sending = false;
  List<Order> _soItems = const [];
  int _soTotal = 0;
  bool _soLoading = false;
  String? _soError;
  int _soReq = 0;
  Timer? _searchDebounce;
  final _picked = <String, Order>{};

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _toDate = today;
    _fromDate = today.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      TransferStore.instance.load();
      _reloadSo();
      if (ShopStore.instance.realShops.isEmpty) ShopStore.instance.load();
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
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _syncNow() async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await Future.wait([
        _reloadSo(),
        ShopStore.instance.load(),
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

  void _applyPeriod(DatePeriod period) {
    if (period == DatePeriod.custom) {
      _pickRange().whenComplete(() {
        if (mounted) setState(() {});
      });
      return;
    }
    final range = rangeOfPeriod(period);
    setState(() {
      _fromDate = range.$1;
      _toDate = range.$2;
      _page = 1;
      _histPage = 1;
    });
    _reloadSo();
  }

  Future<void> _reloadSo() async {
    final req = ++_soReq;
    final q = _search.text.trim();
    final platform = _platform == 'all' ? null : Channel.values.byName(_platform).apiPlatform;
    const kinds = {'ready', 'sent', 'done', 'fail'};
    if (mounted) {
      setState(() {
        _soLoading = true;
        _soError = null;
      });
    }
    try {
      final page = await Api.getOrdersPage(
        platform: platform,
        q: q,
        tr: kinds.contains(_st) ? _st : null,
        wide: q.isNotEmpty,
        links: true,
        from: q.isNotEmpty ? null : _fromDate,
        to: q.isNotEmpty ? null : _toDate,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || req != _soReq) return;
      setState(() {
        _soItems = page.items;
        _soTotal = page.total;
        _soLoading = false;
        for (final o in page.items) {
          if (_picked.containsKey(o.id)) _picked[o.id] = o;
        }
      });
      OrderStore.instance.remember(page.items);
    } catch (e) {
      if (!mounted || req != _soReq) return;
      setState(() {
        _soLoading = false;
        _soError = e is ApiException ? e.message : e.toString();
      });
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
    _reloadSo();
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
    _reloadSo();
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
    final picked = [for (final id in _selected) if (_picked[id] != null) _picked[id]!];
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
      final loaded = <Order>[];
      await _runBusy('กำลังดึงรายการสินค้าจากออเดอร์...', () async {
        for (final o in ready) {
          if (o.lines.isNotEmpty) {
            loaded.add(o);
          } else {
            loaded.add(await OrderStore.instance.loadOne(o.id) ?? o);
          }
        }
      });
      if (!mounted) return;

      final selected = [for (final o in loaded) if (_canSend(o)) o];
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
              note: 'Transfer Request จาก Sales Order (${d.channel.shortLabel}) ${d.soRef}',
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
      setState(() {
        _selected.clear();
        _picked.clear();
      });
      await _showSendResult(results);
      if (mounted) await _reloadSo();
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

  Widget _plat(Channel ch) {
    return Text(ch.shortLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }

  Future<void> _openTransfer(StockTransfer t) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SelectionArea(
          child: SizedBox(
            width: 720,
            child: _TrDetailDialog(t: t, trNo: _trNo(t), soCount: _soCount(t)),
          ),
        ),
      ),
    );
  }

  Widget _trPlat(StockTransfer t) {
    final ch = ChannelX.fromApi(t.platform);
    if (ch == null) {
      final label = t.platform.trim();
      return Text(label.isEmpty ? '—' : label, style: const TextStyle(fontWeight: FontWeight.w600));
    }
    return Text(ch.shortLabel, style: const TextStyle(fontWeight: FontWeight.w600));
  }

  bool _trFailed(StockTransfer t) {
    final v = t.status.trim().toLowerCase();
    return v.contains('fail') || v.contains('error') || v.contains('ล้มเหลว');
  }

  String _trNo(StockTransfer t) {
    if (_trFailed(t)) return '-';
    for (final raw in [t.sapDocNum, t.id]) {
      final v = raw.trim();
      if (v.isEmpty || v == '-') continue;
      if (v.toUpperCase().startsWith('TRF-')) continue;
      return v;
    }
    return '-';
  }

  int _soCount(StockTransfer t) => _transferSoKeys(t).length;

  Widget _soCountCell(StockTransfer t) {
    final n = _soCount(t);
    if (n <= 0) return const Text('—', style: TextStyle(color: Pal.muted));
    return Text('$n รายการ', style: const TextStyle(fontWeight: FontWeight.w700));
  }

  Widget _qtyCell(StockTransfer t) {
    final qty = t.qtyTotal > 0 ? t.qtyTotal : t.items.length;
    return Text('${nFmt.format(qty)} ชิ้น', style: const TextStyle(fontWeight: FontWeight.w700));
  }

  Widget _trHistStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('success') || v.contains('สำเร็จ') || v.contains('done') || v.contains('complete')) {
      return pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg);
    }
    if (v.contains('fail') || v.contains('error') || v.contains('ล้มเหลว')) {
      return pill('ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
    }
    if (v.contains('pending') || v.contains('wait') || v.contains('รอ')) {
      return pill('รอดำเนินการ', const Color(0xFFC2410C), const Color(0xFFFFEDD5));
    }
    return sapStatusPill(raw);
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
        final soPage = _soItems;
        final trAll = _trRows;
        final pages = (_soTotal / _pageSize).ceil().clamp(1, 9999);
        final start = (_page - 1) * _pageSize;
        final histPages = (trAll.length / _pageSize).ceil().clamp(1, 9999);
        if (_histPage > histPages) _histPage = histPages;
        final histStart = (_histPage - 1) * _pageSize;
        final recent = trAll.skip(histStart).take(_pageSize).toList();
        final allIds = [for (final o in soPage) o.id];
        final selectedN = allIds.where(_selected.contains).length;
        final bool? allSelected =
            allIds.isEmpty ? false : selectedN == 0 ? false : selectedN == allIds.length ? true : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Transfer Request จาก Sales Order', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text(
                'สร้างคำขอโอนสินค้าสำหรับออเดอร์ขาย และติดตามสถานะการส่งเข้า SAP',
                style: TextStyle(color: Pal.muted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _tabs(),
              const SizedBox(height: 10),
              Expanded(
                child: Panel(
                  expand: true,
                  dense: true,
                  pad: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _filters(),
                      if (_tab == 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _routeBar()),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _selected.isEmpty || _sending ? null : _sendSelected,
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: Text(_sending ? 'กำลังส่ง...' : 'สร้าง TR จากรายการที่เลือก (${_selected.length})'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('เลือกแล้ว ${_selected.length} รายการ', style: const TextStyle(color: Pal.muted, fontSize: 13)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: _tab == 0
                            ? _soPanel(_soTotal, soPage, start, pages, allSelected, allIds)
                            : _historyPanel(recent, trAll.length, histStart, histPages),
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

  Widget _tabs() {
    Widget tab(String label, int i, IconData icon) {
      final on = _tab == i;
      return InkWell(
        onTap: () => setState(() => _tab = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          DateRangeField(from: _fromDate, to: _toDate, onTap: _pickRange, width: 280),
          PeriodField(value: periodOfRange(_fromDate, _toDate), onChanged: _applyPeriod),
          Drop<String>(
            label: 'Platform',
            value: _platform,
            width: 132,
            onChanged: (v) {
              setState(() {
                _platform = v ?? 'all';
                _page = 1;
                _histPage = 1;
              });
              _reloadSo();
            },
            items: [
              const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
              ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
            ],
          ),
          Drop<String>(
            label: 'สถานะ',
            value: _st,
            width: 140,
            onChanged: (v) {
              setState(() {
                _st = v ?? 'all';
                _page = 1;
                _histPage = 1;
              });
              _reloadSo();
            },
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
                    DropdownMenuItem(value: 'success', child: Text('สำเร็จ')),
                    DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
                    DropdownMenuItem(value: 'failed', child: Text('ล้มเหลว')),
                  ],
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _search,
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  if (!mounted) return;
                  setState(() {
                    _page = 1;
                    _histPage = 1;
                  });
                  _reloadSo();
                });
              },
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                setState(() {
                  _page = 1;
                  _histPage = 1;
                });
                _reloadSo();
              },
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
              onPressed: () {
                _searchDebounce?.cancel();
                setState(() {
                  _page = 1;
                  _histPage = 1;
                });
                _reloadSo();
              },
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
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 10),
          child: TopBarLastSync(),
        ),
      ],
    );
  }

  Widget _routeBar() {
    Widget whs(String label, String code) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warehouse_outlined, size: 18, color: Pal.primary),
          const SizedBox(width: 6),
          Text('$label : $code', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: Pal.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warehouse_outlined, size: 18, color: Pal.primary),
          ),
          const SizedBox(width: 10),
          const Text('เส้นทางการโอนสินค้า', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(width: 4),
          const Text('(กำหนดโดยระบบ)', style: TextStyle(color: Pal.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 20),
          whs('คลังต้นทาง', _fromCode),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: Pal.muted),
          ),
          whs('คลังปลายทาง', _toCode),
        ],
      ),
    );
  }

  Widget _soPanel(int total, List<Order> rows, int start, int pages, bool? allSelected, List<String> allIds) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StickyTable(
              minWidth: 920,
              widths: const [
                FixedColumnWidth(44),
                FlexColumnWidth(1.4),
                FlexColumnWidth(1.8),
                FlexColumnWidth(1.0),
                FlexColumnWidth(1.0),
                FlexColumnWidth(1.0),
                FlexColumnWidth(1.1),
              ],
              headers: [
                Checkbox(
                  tristate: true,
                  value: allSelected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: allIds.isEmpty
                      ? null
                          : (_) => setState(() {
                            if (allSelected == true) {
                              _selected.removeAll(allIds);
                              for (final id in allIds) {
                                _picked.remove(id);
                              }
                            } else {
                              _selected.addAll(allIds);
                              for (final o in rows) {
                                _picked[o.id] = o;
                              }
                            }
                          }),
                ),
                const Text('วันที่', maxLines: 1, softWrap: false),
                const Text('Sales Order No.', maxLines: 1, softWrap: false),
                const Text('แพลตฟอร์ม', maxLines: 1, softWrap: false),
                const Text('จำนวนรายการ', maxLines: 1, softWrap: false),
                const Text('สถานะ', maxLines: 1, softWrap: false),
                const Text('Action', maxLines: 1, softWrap: false),
              ],
              rows: [
                for (final o in rows)
                  [
                    Checkbox(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: _selected.contains(o.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(o.id);
                          _picked[o.id] = o;
                        } else {
                          _selected.remove(o.id);
                          _picked.remove(o.id);
                        }
                      }),
                    ),
                    Text(dtFmt.format(o.createdAt)),
                    Text(o.id, style: const TextStyle(fontWeight: FontWeight.w600)),
                    _plat(o.channel),
                    Text(o.lines.isNotEmpty ? '${o.lines.length}' : (o.itemCount > 0 ? '${o.itemCount}' : '-')),
                    _soPill(_soKind(o)),
                    TextButton(
                      onPressed: () => context.go('/orders/${Uri.encodeComponent(o.id)}'),
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
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  _soLoading
                      ? 'กำลังโหลด...'
                      : (_soError ?? 'ยังไม่มี Sales Order สำหรับสร้าง Transfer Request'),
                  style: const TextStyle(color: Pal.muted),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                _soLoading && rows.isEmpty
                    ? 'กำลังโหลด...'
                    : total == 0
                        ? 'แสดง 0 รายการ'
                        : 'แสดง ${start + 1} - ${start + rows.length} จาก $total รายการ',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
              Pages(
                page: _page,
                total: pages,
                onTap: (p) {
                  setState(() => _page = p);
                  _reloadSo();
                },
              ),
            ],
          ),
        ],
    );
  }

  Widget _historyPanel(List<StockTransfer> rows, int total, int start, int pages) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StickyTable(
              minWidth: 1040,
              widths: const [
                FixedColumnWidth(44),
                FlexColumnWidth(1.1),
                FlexColumnWidth(1.0),
                FlexColumnWidth(1.2),
                FlexColumnWidth(1.1),
                FlexColumnWidth(1.0),
                FlexColumnWidth(0.9),
                FlexColumnWidth(1.0),
              ],
              headers: const [
                Text('#'),
                Text('วันที่', maxLines: 1, softWrap: false),
                Text('แพลตฟอร์ม', maxLines: 1, softWrap: false),
                Text('TR No.', maxLines: 1, softWrap: false),
                Text('จำนวนใบ SO', maxLines: 1, softWrap: false),
                Text('จำนวนรวม', maxLines: 1, softWrap: false),
                Text('สถานะ', maxLines: 1, softWrap: false),
                Text('Action', maxLines: 1, softWrap: false),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  [
                    Text('${start + i + 1}', style: const TextStyle(color: Pal.muted)),
                    Text(rows[i].displayAt == null ? '—' : dayFmt.format(rows[i].displayAt!)),
                    _trPlat(rows[i]),
                    InkWell(
                      onTap: () => _openTransfer(rows[i]),
                      child: Text(
                        _trNo(rows[i]),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _trNo(rows[i]) == '-' ? Pal.muted : Pal.text,
                        ),
                      ),
                    ),
                    _soCountCell(rows[i]),
                    _qtyCell(rows[i]),
                    _trHistStatus(rows[i].status),
                    TextButton(
                      onPressed: () => _openTransfer(rows[i]),
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
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('ยังไม่มีข้อมูลประวัติการโอน', style: TextStyle(color: Pal.muted))),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                total == 0 ? 'แสดง 0 รายการ' : 'แสดง ${start + 1} - ${start + rows.length} จาก $total รายการ',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
              Pages(page: _histPage, total: pages, onTap: (p) => setState(() => _histPage = p)),
            ],
          ),
        ],
    );
  }

}

String _soKeyNorm(String raw) {
  var v = raw.trim();
  if (v.toUpperCase().startsWith('SO-')) v = v.substring(3).trim();
  return v;
}

List<String> _transferSoKeys(StockTransfer t) {
  final first = <String, String>{};
  for (final raw in [...t.salesOrderIds, ...t.referenceNo.split(RegExp(r'[,;]+'))]) {
    final k = raw.trim();
    if (k.isEmpty || k == '-') continue;
    final norm = _soKeyNorm(k);
    if (norm.isEmpty) continue;
    final id = norm.toLowerCase();
    final existing = first[id];
    if (existing == null || (k.toUpperCase().startsWith('SO-') && !existing.toUpperCase().startsWith('SO-'))) {
      first[id] = k;
    }
  }
  return first.values.toList();
}

class _TrDetailDialog extends StatefulWidget {
  const _TrDetailDialog({
    required this.t,
    required this.trNo,
    required this.soCount,
  });

  final StockTransfer t;
  final String trNo;
  final int soCount;

  @override
  State<_TrDetailDialog> createState() => _TrDetailDialogState();
}

class _TrDetailDialogState extends State<_TrDetailDialog> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final missing = [for (final key in _soKeys()) if (_orderOf(key) == null) key];
    if (missing.isEmpty) return;
    Future(() async {
      for (final key in missing) {
        await OrderStore.instance.loadOne(key);
        if (_orderOf(key) != null) continue;
        final bare = key.replaceFirst(RegExp(r'^SO-', caseSensitive: false), '');
        if (bare != key) await OrderStore.instance.loadOne(bare);
      }
      if (mounted) setState(() {});
    });
  }

  String _whs(String code, String name, {required String fallback, required String fallbackName}) {
    var c = code.trim();
    if (c.isEmpty || c == '-') c = fallback;
    final live = warehouseByCode(c);
    var n = (live?.name ?? name).trim();
    if (n.isEmpty || n == '-' || n == c) n = fallbackName;
    if (n.isEmpty) return c;
    return '$c : $n';
  }

  List<String> _soKeys() => _transferSoKeys(widget.t);

  Order? _orderOf(String key) {
    final norm = _soKeyNorm(key).toLowerCase();
    for (final o in OrderStore.instance.orders) {
      if (o.id == key || _soKeyNorm(o.id).toLowerCase() == norm) return o;
      final sap = (o.sapDocNum ?? '').trim();
      if (sap.isNotEmpty && (sap == key || sap.toLowerCase() == norm || 'so-$sap'.toLowerCase() == key.toLowerCase())) {
        return o;
      }
    }
    return null;
  }

  int _orderQty(Order o) {
    if (o.lines.isNotEmpty) return o.lines.fold<int>(0, (a, l) => a + l.qty);
    if (o.itemCount > 0) return o.itemCount;
    return 1;
  }

  String _soNo(String key, Order? o) {
    final sap = (o?.sapDocNum ?? '').trim();
    if (sap.isNotEmpty) return sap;
    final id = (o?.id ?? key).trim();
    return id.isEmpty || id == '-' ? '-' : id;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final ch = ChannelX.fromApi(t.platform);
    final qty = t.qtyTotal > 0 ? t.qtyTotal : t.items.length;
    final keys = _soKeys();
    final soRows = [
      for (final key in keys)
        () {
          final o = _orderOf(key);
          return (
            no: _soNo(key, o),
            qty: o == null ? 1 : _orderQty(o),
            orderId: (o?.id ?? key).trim(),
          );
        }(),
    ];
    final creator = t.requestedBy.trim().isEmpty || t.requestedBy == '-' ? Session.instance.name : t.requestedBy;

    Widget meta(String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted)),
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pal.text),
              child: value,
            ),
          ],
        ),
      );
    }

    Widget tab(String label, int i) {
      final on = _tab == i;
      return InkWell(
        onTap: () => setState(() => _tab = i),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? Pal.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : Pal.muted,
            ),
          ),
        ),
      );
    }

    void openSo(String id) {
      final orderId = id.trim();
      if (orderId.isEmpty || orderId == '-') return;
      final router = GoRouter.of(context);
      Navigator.of(context, rootNavigator: true).pop();
      router.go('/orders/${Uri.encodeComponent(orderId)}');
    }

    final tableN = _tab == 0 ? (soRows.isEmpty ? 1 : soRows.length) : (t.items.isEmpty ? 1 : t.items.length);
    final tableLock = tableN > 6;

    final soTable = StickyTable(
      fill: tableLock,
      widths: const [
        FixedColumnWidth(56),
        FlexColumnWidth(1.8),
        FlexColumnWidth(1.0),
        FlexColumnWidth(1.2),
      ],
      headers: const [
        Text('ลำดับ'),
        Text('SO No. (SAP)'),
        Text('จำนวนสินค้า'),
        Text('Action'),
      ],
      rows: [
        if (soRows.isEmpty)
          const [Text('-'), Text('-'), Text('-'), Text('-')]
        else
          for (var i = 0; i < soRows.length; i++)
            [
              Text('${i + 1}'),
              Text(soRows[i].no, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${nFmt.format(soRows[i].qty)} ชิ้น'),
              TextButton(
                onPressed: () => openSo(soRows[i].orderId),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('ดูรายละเอียด'),
              ),
            ],
      ],
    );

    final itemTable = StickyTable(
      fill: tableLock,
      widths: const [
        FixedColumnWidth(56),
        FlexColumnWidth(1.2),
        FlexColumnWidth(2.0),
        FlexColumnWidth(0.8),
      ],
      headers: const [
        Text('ลำดับ'),
        Text('SKU'),
        Text('ชื่อสินค้า'),
        Text('จำนวน'),
      ],
      rows: [
        if (t.items.isEmpty)
          const [Text('-'), Text('-'), Text('-'), Text('-')]
        else
          for (var i = 0; i < t.items.length; i++)
            [
              Text('${i + 1}'),
              Text(t.items[i].sku, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(t.items[i].name.isEmpty ? '-' : t.items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${nFmt.format(t.items[i].qty)} ชิ้น'),
            ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('รายละเอียด Transfer Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: meta('เลขที่ TR (SAP)', Text(widget.trNo))),
                  Expanded(child: meta('วันที่สร้าง', Text(t.displayAt == null ? '-' : dtFmt.format(t.displayAt!)))),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: meta('แพลตฟอร์ม', Text(ch?.label ?? (t.platform.trim().isEmpty ? '-' : t.platform)))),
                  Expanded(child: meta('ผู้สร้าง', Text(creator.isEmpty ? '-' : creator))),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: meta('คลังต้นทาง', Text(_whs(t.fromWarehouseId, t.fromWarehouseName, fallback: 'MDL', fallbackName: 'คลังหลัก')))),
                  Expanded(child: meta('คลังปลายทาง', Text(_whs(t.toWarehouseId, t.toWarehouseName, fallback: 'ONLINE', fallbackName: 'คลังออนไลน์')))),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: meta('จำนวน SO', Text('${keys.isNotEmpty ? keys.length : widget.soCount} ใบ'))),
                  Expanded(child: meta('จำนวนสินค้าทั้งหมด', Text('${nFmt.format(qty)} ชิ้น'))),
                ],
              ),
              Row(
                children: [
                  tab('รายการ SO (${keys.length})', 0),
                  const SizedBox(width: 8),
                  tab('รายการสินค้า (${t.items.length})', 1),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Pal.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: tableLock
                  ? SizedBox(height: 240, child: _tab == 0 ? soTable : itemTable)
                  : (_tab == 0 ? soTable : itemTable),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('ปิด'),
            ),
          ),
        ),
      ],
    );
  }
}
