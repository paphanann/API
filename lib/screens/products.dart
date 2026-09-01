import 'package:flutter/material.dart';

import '../dummy.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _ch = 'all';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final rows = _ch == 'all' ? Dummy.products : Dummy.products.where((p) => p.channel.name == _ch).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Panel(
        title: 'รายการสินค้า',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Drop<String>(
                  label: 'แพลตฟอร์ม',
                  value: _ch,
                  onChanged: (v) => setState(() => _ch = v ?? 'all'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                    ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
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
                    DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('สินค้า')),
                    DataColumn(label: Text('Platform')),
                    DataColumn(label: Text('ราคา')),
                    DataColumn(label: Text('สต็อก')),
                    DataColumn(label: Text('สถานะ')),
                    DataColumn(label: Text('Sync')),
                  ],
                  rows: [
                    for (final p in rows)
                      DataRow(
                        cells: [
                          DataCell(Text(p.sku, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(p.name)),
                          DataCell(ChannelLabel(channel: p.channel)),
                          DataCell(Text(baht.format(p.price))),
                          DataCell(Text('${p.stock}')),
                          DataCell(productPill(p.status)),
                          DataCell(pill(p.synced ? 'Synced' : 'Pending', p.synced ? const Color(0xFF15803D) : const Color(0xFFB45309), p.synced ? Pal.okBg : Pal.warnBg)),
                        ],
                      ),
                  ],
              ),
            ),
            const SizedBox(height: 16),
            Pages(page: _page, total: 4, onTap: (p) => setState(() => _page = p)),
          ],
        ),
      ),
    );
  }
}
