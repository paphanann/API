import 'package:flutter/material.dart';

import '../dummy.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Panel(
        title: 'คลังสินค้า',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FillTable(
              child: DataTable(
                  headingRowColor: tableHeadBg,
                  headingTextStyle: tableHead,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('สินค้า')),
                    DataColumn(label: Text('คลัง')),
                    DataColumn(label: Text('คงเหลือ')),
                    DataColumn(label: Text('จอง')),
                    DataColumn(label: Text('Shopee')),
                    DataColumn(label: Text('TikTok')),
                    DataColumn(label: Text('Lazada')),
                  ],
                  rows: [
                    for (final r in Dummy.stocks)
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
                        ],
                      ),
                  ],
              ),
            ),
            const SizedBox(height: 16),
            Pages(page: _page, total: 3, onTap: (p) => setState(() => _page = p)),
          ],
        ),
      ),
    );
  }

  Widget _ok(bool v) {
    return Icon(v ? Icons.check_circle_rounded : Icons.remove_circle_outline, size: 20, color: v ? Pal.ok : Pal.faint);
  }
}
