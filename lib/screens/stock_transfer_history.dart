import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../models/models.dart';
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ประวัติการโอนสต็อก', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'ตรวจสอบประวัติการโอนสินค้าจากคลัง Main ไปยังคลัง Online ของแต่ละ Platform',
            style: TextStyle(color: Pal.muted, fontSize: 14),
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
                  width: 140,
                  onChanged: (v) => setState(() => _from = v ?? ''),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                  ],
                ),
                const SizedBox(width: 8),
                Drop<String>(
                  label: 'คลังปลายทาง',
                  value: _to,
                  width: 140,
                  onChanged: (v) => setState(() => _to = v ?? ''),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
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
                    onPressed: () {},
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
              final cards = [
                const StatCard(
                  title: 'รายการทั้งหมด',
                  value: '0',
                  icon: Icons.inventory_2_outlined,
                  color: Pal.primary,
                  hint: Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
                const StatCard(
                  title: 'สำเร็จ',
                  value: '0',
                  icon: Icons.check_circle_outline_rounded,
                  color: Pal.ok,
                  hint: Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
                const StatCard(
                  title: 'Pending SAP',
                  value: '0',
                  icon: Icons.schedule_rounded,
                  color: Pal.warn,
                  hint: Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
                ),
                const StatCard(
                  title: 'Failed',
                  value: '0',
                  icon: Icons.cancel_outlined,
                  color: Pal.err,
                  hint: Text('รายการ', style: TextStyle(fontSize: 11, color: Pal.muted)),
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
                  minWidth: 1480,
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    dataRowMinHeight: 52,
                    columns: const [
                      DataColumn(label: Text('วันที่ / เวลา')),
                      DataColumn(label: Text('เลขที่เอกสาร')),
                      DataColumn(label: Text('Reference No.')),
                      DataColumn(label: Text('จากคลัง')),
                      DataColumn(label: Text('ไปคลัง')),
                      DataColumn(label: Text('Platform')),
                      DataColumn(label: Text('จำนวนรายการ')),
                      DataColumn(label: Text('จำนวนรวมโอน')),
                      DataColumn(label: Text('SAP DocNumber')),
                      DataColumn(label: Text('สถานะ')),
                      DataColumn(label: Text('ผู้ดำเนินการ')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: const [],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('ยังไม่มีข้อมูลประวัติการโอน', style: TextStyle(color: Pal.muted))),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('แสดง 0 รายการ', style: TextStyle(color: Pal.muted, fontSize: 13)),
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
  }
}
