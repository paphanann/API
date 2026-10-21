import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/json_util.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../widgets/ui.dart';

class _Row {
  _Row({
    required this.sku,
    required this.name,
    required this.stock,
    required this.image,
    required this.channel,
    this.unit = 'ชิ้น',
  });

  final String sku;
  final String name;
  final int stock;
  final String image;
  final Channel channel;
  final String unit;
  bool selected = false;
  int qty = 0;
}

class _SapLine {
  const _SapLine({required this.sku, required this.name, required this.stock, required this.unit});

  final String sku;
  final String name;
  final int stock;
  final String unit;
}

class StockTransferCreateScreen extends StatefulWidget {
  const StockTransferCreateScreen({super.key});

  @override
  State<StockTransferCreateScreen> createState() => _StockTransferCreateScreenState();
}

class _StockTransferCreateScreenState extends State<StockTransferCreateScreen> {
  int _step = 0;
  String _platform = '';
  String _from = '';
  String _to = '';
  String _wh = 'all';
  String _st = 'all';
  DateTime _docDate = dateOnly(DateTime.now());
  final _ref = TextEditingController();
  final _requester = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  static const _pageSize = 10;
  final _rows = <_Row>[];
  final _sapItems = <_SapLine>[];
  bool _loadingItems = false;
  int _page = 1;
  List<String> _warehouses = const [];
  StockTransfer? _created;

  @override
  void initState() {
    super.initState();
    _requester.text = Session.instance.name;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) setState(() => _loadingItems = true);
      try {
        final opts = await Api.getErpOptions();
        final sap = await Api.getSapItems();
        if (!mounted) return;
        setState(() {
          if (opts.warehouseNames.isNotEmpty) setLiveWarehouses(opts.warehouseNames);
          _warehouses = [for (final w in liveWarehouses) w.code];
          if (!_warehouses.contains(_from)) {
            _from = _warehouses.contains('01') ? '01' : (_warehouses.isEmpty ? '' : _warehouses.first);
          }
          _sapItems
            ..clear()
            ..addAll([
              for (final row in sap)
                _SapLine(
                  sku: pickStr(row, ['sku', 'Sku', 'ItemCode', 'itemCode'], or: ''),
                  name: pickStr(row, ['name', 'Name', 'ItemName', 'itemName'], or: ''),
                  stock: pickInt(row, ['stock', 'Stock', 'QuantityOnStock']),
                  unit: pickStr(row, ['unit', 'Unit', 'InventoryUOM'], or: 'ชิ้น'),
                ),
            ]);
          _loadingItems = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() => _loadingItems = false);
          _toast(e is ApiException ? e.message : 'ดึงสินค้าจาก SAP ไม่สำเร็จ');
        }
      }
      if (mounted) _rebuildRows();
    });
  }

  @override
  void dispose() {
    _ref.dispose();
    _requester.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  void _rebuildRows() {
    final prev = {for (final r in _rows) r.sku: r};
    final next = <_Row>[
      for (final item in _sapItems)
        if (item.sku.isNotEmpty)
          _Row(
            sku: item.sku,
            name: item.name.isEmpty ? item.sku : item.name,
            stock: item.stock,
            image: '',
            channel: Channel.shopee,
            unit: item.unit.isEmpty ? 'ชิ้น' : item.unit,
          )
            ..selected = prev[item.sku]?.selected ?? false
            ..qty = prev[item.sku]?.qty ?? 0,
    ];
    setState(() {
      _rows
        ..clear()
        ..addAll(next);
    });
  }

  List<_Row> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final r in _rows)
        if ((q.isEmpty || r.sku.toLowerCase().contains(q) || r.name.toLowerCase().contains(q)) &&
            (_st == 'all' || (_st == 'ready' && r.stock > 0) || (_st == 'blocked' && r.stock <= 0)))
          r,
    ];
  }

  List<_Row> get _picked => [for (final r in _rows) if (r.selected && r.qty > 0) r];

  int get _qtyTotal => _picked.fold(0, (a, r) => a + r.qty);

  Channel? get _ch => Channel.values.where((c) => c.name == _platform).firstOrNull;

  ButtonStyle get _boxBtn => OutlinedButton.styleFrom(
        foregroundColor: Pal.text,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Pal.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _selectAll() {
    final rows = _filtered;
    final allOn = rows.isNotEmpty && rows.every((r) => r.selected);
    setState(() {
      for (final r in rows) {
        r.selected = !allOn;
        if (r.selected && r.qty <= 0) r.qty = 1;
        if (!r.selected) r.qty = 0;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showSimpleCalendar(context: context, from: _docDate, to: _docDate);
    if (picked == null || picked.cleared || picked.range == null) return;
    setState(() => _docDate = dateOnly(picked.range!.start));
  }

  void _goReview() {
    if (_picked.isEmpty) {
      _toast('เลือกสินค้าและระบุจำนวนโอนก่อน');
      return;
    }
    if (_from.isEmpty || _to.isEmpty) {
      _toast('เลือกคลังต้นทางและคลังปลายทางก่อน');
      return;
    }
    if (_ref.text.trim().isEmpty) {
      final tag = (_ch?.shortLabel ?? 'SAP').replaceAll(' ', '');
      _ref.text = 'TRF-$tag-${dayFmt.format(_docDate).replaceAll('/', '')}';
    }
    setState(() => _step = 1);
  }

  Future<void> _confirm() async {
    try {
      final row = await TransferStore.instance.create(
        fromWarehouseId: _from,
        toWarehouseId: _to,
        note: _note.text.trim(),
        documentNo: _ref.text.trim(),
        requestedBy: _requester.text.trim(),
        dueDate: _docDate,
        platform: _platform,
        items: [
          for (final r in _picked) StockTransferLine(sku: r.sku, name: r.name, qty: r.qty),
        ],
      );
      if (!mounted) return;
      setState(() {
        _created = row;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      _toast(e is ApiException ? e.message : e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ProductStore.instance, TransferStore.instance]),
      builder: (context, _) {
        if (_step == 1) return _review();
        if (_step == 2) return _success();
        return _select();
      },
    );
  }

  Widget _select() {
    final all = _filtered;
    final pages = (all.length / _pageSize).ceil().clamp(1, 9999).toInt();
    if (_page > pages) _page = pages;
    final start = (_page - 1) * _pageSize;
    final rows = all.skip(start).take(_pageSize).toList();
    final fromN = all.isEmpty ? 0 : start + 1;
    final toN = start + rows.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เพิ่มการขอโอนระหว่างคลัง', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('โอนสินค้าจากคลัง Main ไปยังคลัง Online ของแต่ละ Platform', style: TextStyle(color: Pal.muted, fontSize: 14)),
          const SizedBox(height: 16),
          Panel(
            pad: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Drop<String>(
                  label: 'Platform',
                  value: _platform,
                  width: 180,
                  onChanged: (v) {
                    _platform = v ?? '';
                    _rebuildRows();
                  },
                  items: [
                    const DropdownMenuItem(value: '', child: Text('เลือก Platform')),
                    ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                  ],
                ),
                Drop<String>(
                  label: 'คลังต้นทาง (SAP)',
                  value: _from,
                  width: 220,
                  onChanged: (v) => setState(() => _from = v ?? ''),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('เลือกคลังต้นทาง')),
                    ..._warehouseItems(),
                  ],
                ),
                Drop<String>(
                  label: 'คลังปลายทาง',
                  value: _to,
                  width: 220,
                  onChanged: (v) => setState(() => _to = v ?? ''),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('เลือกคลังปลายทาง')),
                    ..._warehouseItems(),
                  ],
                ),
                DateRangeField(
                  label: 'วันที่เอกสาร',
                  from: _docDate,
                  to: _docDate,
                  width: 200,
                  onTap: _pickDate,
                ),
                _boxField(label: 'เลขที่เอกสาร', controller: _ref, hint: 'เช่น TRF-SAP-15102026', width: 200),
                _boxField(label: 'ผู้ขอโอน', controller: _requester, hint: 'ชื่อผู้ขอโอน', width: 180),
                _boxField(label: 'เหตุผลการโอน', controller: _note, hint: 'ระบุเหตุผล', width: 220),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'รายการสินค้า',
            pad: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ค้นหา', style: TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() => _page = 1),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'SKU / ชื่อสินค้า',
                              hintStyle: TextStyle(fontSize: 13),
                              prefixIcon: Icon(Icons.search, size: 16),
                              prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Drop<String>(
                      label: 'คลังสินค้า',
                      value: _wh,
                      width: 160,
                      onChanged: (v) => setState(() {
                        _wh = v ?? 'all';
                        _page = 1;
                      }),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        ..._warehouseItems(),
                      ],
                    ),
                    Drop<String>(
                      label: 'สถานะ',
                      value: _st,
                      width: 140,
                      onChanged: (v) => setState(() {
                        _st = v ?? 'all';
                        _page = 1;
                      }),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(value: 'ready', child: Text('พร้อมโอน')),
                        DropdownMenuItem(value: 'blocked', child: Text('ไม่พร้อมโอน')),
                      ],
                    ),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: all.isEmpty ? null : _selectAll,
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('เลือกสินค้าทั้งหมด'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingItems) const LinearProgressIndicator(minHeight: 3),
                FillTable(
                  minWidth: 980,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(40),
                      1: FixedColumnWidth(36),
                      2: FlexColumnWidth(1.6),
                      3: FlexColumnWidth(2.4),
                      4: FixedColumnWidth(120),
                      5: FixedColumnWidth(128),
                      6: FixedColumnWidth(72),
                    },
                    border: const TableBorder(
                      horizontalInside: BorderSide(color: Pal.line),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          _pickHead('#'),
                          const SizedBox.shrink(),
                          _pickHead('SKU'),
                          _pickHead('ชื่อสินค้า'),
                          _pickHead('คงเหลือ SAP'),
                          _pickHead('จำนวนโอน'),
                          _pickHead('หน่วย'),
                        ],
                      ),
                      for (var i = 0; i < rows.length; i++)
                        TableRow(
                          children: [
                            _pickCell(Text('${start + i + 1}', style: const TextStyle(color: Pal.muted)), padding: const EdgeInsets.fromLTRB(8, 8, 0, 8)),
                            _pickCell(
                              padding: EdgeInsets.zero,
                              Checkbox(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                value: rows[i].selected,
                                onChanged: (v) => setState(() {
                                  rows[i].selected = v ?? false;
                                  if (rows[i].selected && rows[i].qty <= 0) rows[i].qty = 1;
                                  if (!rows[i].selected) rows[i].qty = 0;
                                }),
                              ),
                            ),
                            _pickCell(
                              Row(
                                children: [
                                  _thumb(rows[i].image),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(rows[i].sku, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                            _pickCell(Text(rows[i].name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                            _pickCell(Text('${rows[i].stock}')),
                            _pickCell(
                              SizedBox(
                                width: 88,
                                child: TextField(
                                  key: ValueKey('${rows[i].sku}-${rows[i].qty}'),
                                  controller: TextEditingController(text: rows[i].qty == 0 ? '' : '${rows[i].qty}')
                                    ..selection = TextSelection.collapsed(offset: rows[i].qty == 0 ? 0 : '${rows[i].qty}'.length),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (v) {
                                    final n = int.tryParse(v) ?? 0;
                                    rows[i].qty = n;
                                    rows[i].selected = n > 0;
                                  },
                                  onEditingComplete: () => setState(() {}),
                                  decoration: const InputDecoration(isDense: true, hintText: '0'),
                                ),
                              ),
                            ),
                            _pickCell(Text(rows[i].unit)),
                          ],
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('ยังไม่มีข้อมูลสินค้า', style: TextStyle(color: Pal.muted))),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      all.isEmpty ? 'แสดง 0 รายการ' : 'แสดง $fromN - $toN จาก ${all.length} รายการ',
                      style: const TextStyle(color: Pal.muted, fontSize: 13),
                    ),
                    const Spacer(),
                    Pages(page: _page, total: pages, onTap: (p) => setState(() => _page = p)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('เลือกแล้ว ${_picked.length} รายการ', style: const TextStyle(color: Pal.muted)),
                    const SizedBox(width: 16),
                    Text('ยอดรวมจำนวนโอน $_qtyTotal หน่วย', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => context.go('/stock-transfer'),
                      style: _boxBtn,
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _goReview,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('ตรวจสอบข้อมูล'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ตรวจสอบข้อมูลก่อนยืนยัน', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('กรุณาตรวจสอบข้อมูลก่อนบันทึกเป็น Inventory Transfer Request ใน SAP', style: TextStyle(color: Pal.muted, fontSize: 14)),
          const SizedBox(height: 16),
          Panel(
            title: 'ข้อมูลเอกสาร',
            pad: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                _kv('Platform', _ch == null ? Text(_platform) : ChannelLabel(channel: _ch!)),
                _kv('คลังต้นทาง (SAP)', Text(warehouseLabel(_from))),
                _kv('คลังปลายทาง', Text(warehouseLabel(_to))),
                _kv('วันที่เอกสาร', Text(dayFmt.format(_docDate))),
                _kv('เลขที่เอกสาร', Text(_ref.text.trim().isEmpty ? '-' : _ref.text.trim())),
                _kv('ผู้ขอโอน', Text(_requester.text.trim().isEmpty ? '-' : _requester.text.trim())),
                _kv('เหตุผลการโอน', Text(_note.text.trim().isEmpty ? '-' : _note.text.trim())),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'รายการสินค้า',
            pad: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                FillTable(
                  minWidth: 720,
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('ชื่อสินค้า')),
                      DataColumn(label: Text('คงเหลือ SAP')),
                      DataColumn(label: Text('จำนวนโอน')),
                      DataColumn(label: Text('หน่วย')),
                    ],
                    rows: [
                      for (var i = 0; i < _picked.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(_picked[i].sku)),
                            DataCell(Text(_picked[i].name)),
                            DataCell(Text('${_picked[i].stock}')),
                            DataCell(Text('${_picked[i].qty}')),
                            DataCell(Text(_picked[i].unit)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    Text('รวม $_qtyTotal หน่วย', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _step = 0),
                      style: _boxBtn,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('กลับไปแก้ไข'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: TransferStore.instance.saving ? null : _confirm,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(TransferStore.instance.saving ? 'กำลังโอน...' : 'ยืนยันโอน'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    final t = _created;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
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
                const SizedBox(height: 16),
                const Text('สร้างใบขอโอนสำเร็จ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('บันทึกเป็น Inventory Transfer Request ใน SAP แล้ว', textAlign: TextAlign.center, style: TextStyle(color: Pal.muted, fontSize: 13)),
                const SizedBox(height: 22),
                _kv('เลขที่เอกสาร SAP (Inventory Transfer Request)', Text(t?.id ?? '-')),
                _kv('วันที่เอกสาร', Text(dayFmt.format(_docDate))),
                _kv('ผู้ขอโอน', Text(_requester.text.trim().isEmpty ? '-' : _requester.text.trim())),
                _kv('เหตุผลการโอน', Text(_note.text.trim().isEmpty ? '-' : _note.text.trim())),
                _kv('Platform', _ch == null ? Text(_platform) : ChannelLabel(channel: _ch!)),
                _kv('คลังต้นทาง', Text(warehouseLabel(_from))),
                _kv('คลังปลายทาง', Text(warehouseLabel(_to))),
                _kv('จำนวนรายการ', Text('${_picked.length} รายการ')),
                _kv('จำนวนโอนรวม', Text('$_qtyTotal หน่วย')),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/stock-transfer'),
                        child: const Text('ดูรายละเอียดเอกสาร'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/stock-transfer'),
                        child: const Text('กลับไปหน้ารายการโอน'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _boxField({
    required String label,
    required TextEditingController controller,
    required String hint,
    double width = 200,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Pal.muted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _warehouseItems() {
    final rows = liveWarehouses.where((w) => _warehouses.contains(w.code)).toList();
    final source = rows.isEmpty ? [for (final code in _warehouses) SapWarehouse(code)] : rows;
    return [for (final w in source) DropdownMenuItem(value: w.code, child: Text(w.label))];
  }

  Widget _kv(String k, Widget v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
          Expanded(child: v),
        ],
      ),
    );
  }

  Widget _pickHead(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
      child: Text(text, style: tableHead, maxLines: 1, softWrap: false),
    );
  }

  Widget _pickCell(Widget child, {EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(8, 8, 4, 8)}) {
    return Padding(
      padding: padding,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  Widget _thumb(String url) {
    if (url.isEmpty || url == '-') {
      return const SizedBox(width: 36, height: 36, child: Icon(Icons.inventory_2_outlined, size: 18, color: Pal.muted));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(width: 36, height: 36, child: Icon(Icons.inventory_2_outlined, size: 18)),
      ),
    );
  }
}
