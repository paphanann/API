import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../widgets/ui.dart';

class StockTransferHistoryScreen extends StatefulWidget {
  const StockTransferHistoryScreen({super.key});

  @override
  State<StockTransferHistoryScreen> createState() => _StockTransferHistoryScreenState();
}

class _StockTransferHistoryScreenState extends State<StockTransferHistoryScreen> {
  String _platform = 'all';
  String _from = '';
  String _to = '';
  String _st = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _toDate = today;
    _fromDate = today.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) TransferStore.instance.load();
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
    });
  }

  void _clearFilters() {
    final today = dateOnly(DateTime.now());
    setState(() {
      _platform = 'all';
      _from = '';
      _to = '';
      _st = 'all';
      _search.clear();
      _toDate = today;
      _fromDate = today.subtract(const Duration(days: 30));
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

  List<StockTransfer> get _rows {
    final q = _search.text.trim().toLowerCase();
    final list = [
      for (final t in TransferStore.instance.rows)
        if ((_platform == 'all' || t.platform == _platform || ChannelX.fromApi(t.platform)?.name == _platform) &&
            (_from.isEmpty || t.fromWarehouseId == _from) &&
            (_to.isEmpty || t.toWarehouseId == _to) &&
            (_st == 'all' || t.status.toLowerCase().contains(_st)) &&
            (_fromDate == null ||
                _toDate == null ||
                t.scheduleDate == null ||
                (!dateOnly(t.scheduleDate!).isBefore(_fromDate!) && !dateOnly(t.scheduleDate!).isAfter(_toDate!))) &&
            (q.isEmpty ||
                t.id.toLowerCase().contains(q) ||
                t.referenceNo.toLowerCase().contains(q) ||
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

  String _platformLabel(String raw) {
    if (raw.isEmpty || raw == '-') return '-';
    return ChannelX.fromApi(raw)?.label ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TransferStore.instance,
      builder: (context, _) {
        final rows = _rows;
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
                    Text('ขอโอนระหว่างคลัง', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                      'ตรวจสอบประวัติการโอนสินค้าจากคลัง Main ไปยังคลัง Online ของแต่ละ Platform',
                      style: TextStyle(color: Pal.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/stock-transfer/create'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('สร้างรายการโอน'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Panel(
            pad: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DateRangeField(from: _fromDate, to: _toDate, onTap: _pickRange),
                const SizedBox(width: 8),
                Drop<String>(
                  label: 'Platform',
                  value: _platform,
                  width: 132,
                  onChanged: (v) => setState(() => _platform = v ?? 'all'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                    ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                  ],
                ),
                const SizedBox(width: 8),
                Drop<String>(
                  label: 'คลังต้นทาง',
                  value: _from,
                  width: 180,
                  onChanged: (v) => setState(() => _from = v ?? ''),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    ...liveWarehouses.map((w) => DropdownMenuItem(value: w.code, child: Text(w.label))),
                  ],
                ),
                const SizedBox(width: 8),
                Drop<String>(
                  label: 'คลังปลายทาง',
                  value: _to,
                  width: 180,
                  onChanged: (v) => setState(() => _to = v ?? ''),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    ...liveWarehouses.map((w) => DropdownMenuItem(value: w.code, child: Text(w.label))),
                  ],
                ),
                const SizedBox(width: 8),
                Drop<String>(
                  label: 'สถานะ',
                  value: _st,
                  width: 132,
                  onChanged: (v) => setState(() => _st = v ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: 'success', child: Text('Success')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending SAP')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาเลขที่เอกสาร / Reference No.',
                      hintStyle: TextStyle(fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: _btnH,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    style: _searchBtn,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('ค้นหา', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: _btnH,
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: _boxBtn,
                    child: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: _btnH,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    style: _boxBtn,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Export', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              int countStatus(String token) =>
                  rows.where((t) => t.status.toLowerCase().contains(token)).length;
              final cards = [
                StatCard(
                  title: 'รายการทั้งหมด',
                  value: '${rows.length}',
                  icon: Icons.inventory_2_outlined,
                  color: Pal.primary,
                  hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
                StatCard(
                  title: 'สำเร็จ',
                  value: '${countStatus('success')}',
                  icon: Icons.check_circle_outline_rounded,
                  color: Pal.ok,
                  hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
                StatCard(
                  title: 'Pending SAP',
                  value: '${countStatus('pending')}',
                  icon: Icons.schedule_rounded,
                  color: Pal.warn,
                  hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
                StatCard(
                  title: 'Failed',
                  value: '${countStatus('fail')}',
                  icon: Icons.cancel_outlined,
                  color: Pal.err,
                  hint: const Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
              ];
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
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'รายการประวัติการโอน',
            pad: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FillTable(
                  minWidth: 1720,
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    headingRowHeight: 44,
                    columnSpacing: 16,
                    horizontalMargin: 8,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: SizedBox(width: 28, child: Text('#', maxLines: 1, softWrap: false))),
                      DataColumn(label: Text('วันที่กำหนด', maxLines: 1, softWrap: false)),
                      DataColumn(label: Text('เลขที่เอกสาร', maxLines: 1, softWrap: false)),
                      DataColumn(label: SizedBox(width: 110, child: Text('Reference No.', maxLines: 1, softWrap: false))),
                      DataColumn(label: Text('จากคลัง', maxLines: 1, softWrap: false)),
                      DataColumn(label: Text('ไปคลัง', maxLines: 1, softWrap: false)),
                      DataColumn(label: Text('Platform', maxLines: 1, softWrap: false)),
                      DataColumn(label: SizedBox(width: 100, child: Text('จำนวนรายการ', maxLines: 1, softWrap: false))),
                      DataColumn(label: SizedBox(width: 110, child: Text('จำนวนรวมโอน', maxLines: 1, softWrap: false))),
                      DataColumn(label: SizedBox(width: 130, child: Text('SAP DocNumber', maxLines: 1, softWrap: false))),
                      DataColumn(label: Text('สถานะ', maxLines: 1, softWrap: false)),
                      DataColumn(label: Text('ผู้ขอโอน', maxLines: 1, softWrap: false)),
                      DataColumn(label: Text('Action', maxLines: 1, softWrap: false)),
                    ],
                    rows: [
                      for (var i = 0; i < rows.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}', style: const TextStyle(color: Pal.muted))),
                            DataCell(Text(rows[i].scheduleDate == null ? '-' : dtFmt.format(rows[i].scheduleDate!))),
                            DataCell(Text(rows[i].id)),
                            DataCell(Text(rows[i].referenceNo.isEmpty || rows[i].referenceNo == '-' ? '-' : rows[i].referenceNo)),
                            DataCell(Text(warehouseLabel(rows[i].fromLabel))),
                            DataCell(Text(warehouseLabel(rows[i].toLabel))),
                            DataCell(Text(_platformLabel(rows[i].platform))),
                            DataCell(Text('${rows[i].items.length}')),
                            DataCell(Text('${rows[i].qtyTotal}')),
                            DataCell(Text(rows[i].id)),
                            DataCell(transferPill(rows[i].status)),
                            DataCell(Text(rows[i].requestedBy.isEmpty || rows[i].requestedBy == '-' ? '-' : rows[i].requestedBy)),
                            DataCell(const Text('ดูรายละเอียด', style: TextStyle(color: Pal.primary, fontWeight: FontWeight.w600))),
                          ],
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('ยังไม่มีข้อมูลประวัติการโอน', style: TextStyle(color: Pal.muted))),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(rows.isEmpty ? 'แสดง 0 รายการ' : 'แสดง ${rows.length} รายการ', style: const TextStyle(color: Pal.muted, fontSize: 13)),
                    const Spacer(),
                    Pages(page: 1, total: 1, onTap: (_) {}),
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
