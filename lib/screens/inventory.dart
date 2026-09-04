import 'package:flutter/material.dart';

import '../dummy.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _wh = 'all';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final rows = _wh == 'all' ? Dummy.stocks : Dummy.stocks.where((r) => r.wh == _wh).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Panel(
        title: 'รายการสินค้าในคลัง',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Drop<String>(
                  label: 'คลังสินค้า',
                  value: _wh,
                  onChanged: (v) => setState(() => _wh = v ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: '01', child: Text('01')),
                    DropdownMenuItem(value: '02', child: Text('02')),
                    DropdownMenuItem(value: '03', child: Text('03')),
                  ],
                ),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('ค้นหา'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FillTable(
              child: DataTable(
                headingRowColor: tableHeadBg,
                headingTextStyle: tableHead,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text('SKU (ItemCode)')),
                  DataColumn(label: Text('ชื่อสินค้า')),
                  DataColumn(label: Text('คลัง')),
                  DataColumn(label: Text('คงเหลือ')),
                  DataColumn(label: Text('จอง')),
                  DataColumn(label: Text('Shopee')),
                  DataColumn(label: Text('TikTok Shop')),
                  DataColumn(label: Text('Lazada')),
                  DataColumn(label: Text('อัปเดตล่าสุด')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(r.sku, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(r.name)),
                        DataCell(Text(r.wh)),
                        DataCell(Text('${r.available}')),
                        DataCell(Text('${r.reserved}')),
                        DataCell(_ok(r.shopee)),
                        DataCell(_ok(r.tiktok)),
                        DataCell(_ok(r.lazada)),
                        DataCell(Text(dtFmt.format(r.updatedAt))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('แสดง 1 - 8 จาก 156 รายการ', style: TextStyle(color: Pal.muted, fontSize: 13)),
                const Spacer(),
                Pages(page: _page, total: 20, onTap: (p) => setState(() => _page = p)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ok(bool v) {
    return Icon(v ? Icons.check_circle_rounded : Icons.remove_circle_outline, size: 20, color: v ? Pal.ok : Pal.faint);
  }
}
