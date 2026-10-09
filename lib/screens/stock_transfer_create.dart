import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../widgets/ui.dart';

class StockTransferCreateScreen extends StatefulWidget {
  const StockTransferCreateScreen({super.key});

  @override
  State<StockTransferCreateScreen> createState() => _StockTransferCreateScreenState();
}

class _StockTransferCreateScreenState extends State<StockTransferCreateScreen> {
  String _platform = '';
  String _from = '';
  String _to = '';
  String _cat = 'all';
  String _st = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  final _ref = TextEditingController();
  final _note = TextEditingController();
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
    _ref.dispose();
    _note.dispose();
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

  void _emptyAction([String msg = 'ยังไม่มีข้อมูลสินค้าสำหรับโอน']) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  ButtonStyle get _boxBtn => OutlinedButton.styleFrom(
        foregroundColor: Pal.text,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Pal.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

  Widget _labelField(String label, Widget child, {double width = 200}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('โอนสต็อกสินค้า', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'โอนสินค้าจากคลัง Main ไปยังคลัง Online ของแต่ละ Platform',
            style: TextStyle(color: Pal.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Panel(
            title: 'ตั้งค่าการโอนสต็อก',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _emptyAction('ยังไม่มีรายการให้สร้าง'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('สร้างรายการโอน'),
                ),
              ),
            ),
            pad: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Drop<String>(
                  label: 'Platform',
                  value: _platform,
                  width: 180,
                  onChanged: (v) => setState(() => _platform = v ?? ''),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('เลือก Platform')),
                    ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                  ],
                ),
                Drop<String>(
                  label: 'คลังต้นทาง (SAP)',
                  value: _from,
                  width: 200,
                  onChanged: (v) => setState(() => _from = v ?? ''),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('เลือกคลังต้นทาง')),
                  ],
                ),
                Drop<String>(
                  label: 'คลังปลายทาง',
                  value: _to,
                  width: 200,
                  onChanged: (v) => setState(() => _to = v ?? ''),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('เลือกคลังปลายทาง')),
                  ],
                ),
                DateRangeField(from: _fromDate, to: _toDate, onTap: _pickRange),
                _labelField(
                  'เลขที่อ้างอิง / Reference No.',
                  TextField(
                    controller: _ref,
                    decoration: const InputDecoration(
                      hintText: 'ระบุเลขที่อ้างอิง (ถ้ามี)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  width: 220,
                ),
                _labelField(
                  'หมายเหตุ (ถ้ามี)',
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      hintText: 'ระบุหมายเหตุ (ถ้ามี)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  width: 220,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'รายการสินค้า',
            pad: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'ค้นหา SKU / ชื่อสินค้า',
                          prefixIcon: Icon(Icons.search, size: 20),
                          isDense: true,
                        ),
                      ),
                    ),
                    Drop<String>(
                      label: 'หมวดหมู่',
                      value: _cat,
                      width: 160,
                      onChanged: (v) => setState(() => _cat = v ?? 'all'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                      ],
                    ),
                    Drop<String>(
                      label: 'สถานะ',
                      value: _st,
                      width: 160,
                      onChanged: (v) => setState(() => _st = v ?? 'all'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(value: 'ready', child: Text('พร้อมโอน')),
                        DropdownMenuItem(value: 'blocked', child: Text('ไม่พร้อมโอน')),
                      ],
                    ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _emptyAction(),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('เลือกสินค้าทั้งหมด'),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _search.clear();
                          _cat = 'all';
                          _st = 'all';
                        }),
                        style: _boxBtn,
                        child: const Text('ล้างตัวกรอง'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FillTable(
                  minWidth: 1280,
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    dataRowMinHeight: 56,
                    checkboxHorizontalMargin: 12,
                    columns: const [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('ชื่อสินค้า')),
                      DataColumn(label: Text('Platform')),
                      DataColumn(label: Text('คลังปลายทาง')),
                      DataColumn(label: Text('คงเหลือใน SAP')),
                      DataColumn(label: Text('จำนวนโอน')),
                      DataColumn(label: Text('หน่วย')),
                      DataColumn(label: Text('สถานะ')),
                    ],
                    rows: const [],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('ยังไม่มีข้อมูลสินค้า', style: TextStyle(color: Pal.muted))),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final actions = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _emptyAction('ยังไม่มีรายการให้ล้าง'),
                          style: _boxBtn,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('ล้างรายการ'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _emptyAction('ยังไม่มีข้อมูลให้บันทึกร่าง'),
                          style: _boxBtn.copyWith(
                            foregroundColor: const WidgetStatePropertyAll(Pal.primary),
                          ),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('บันทึกร่าง'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _emptyAction('ยังไม่มีข้อมูลให้ยืนยันโอน'),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('ยืนยันโอน'),
                        ),
                      ],
                    );
                    if (box.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _stat(Icons.inventory_2_outlined, 'จำนวนสินค้าที่เลือก', '0 รายการ'),
                          const SizedBox(height: 10),
                          _stat(Icons.layers_outlined, 'ยอดรวมจำนวนโอน', '0 หน่วย'),
                          const SizedBox(height: 12),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        _stat(Icons.inventory_2_outlined, 'จำนวนสินค้าที่เลือก', '0 รายการ'),
                        const SizedBox(width: 24),
                        _stat(Icons.layers_outlined, 'ยอดรวมจำนวนโอน', '0 หน่วย'),
                        const Spacer(),
                        actions,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: Pal.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: Pal.primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
