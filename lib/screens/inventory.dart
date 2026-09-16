import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _wh = 'all';

  @override
  void initState() {
    super.initState();
    InventoryStore.instance.load();
  }

  Future<void> _search() async {
    await InventoryStore.instance.load(
      warehouse: (_wh == 'all' || _wh == 'MARKETPLACE') ? null : _wh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InventoryStore.instance,
      builder: (context, _) {
        final store = InventoryStore.instance;
        final warehouses = {
          for (final r in store.rows)
            if (r.wh.isNotEmpty && r.wh != '-') r.wh,
        }.toList()
          ..sort();
        final rows = (_wh == 'all' || _wh == 'MARKETPLACE')
            ? store.rows
            : store.rows.where((r) {
                if (_wh == 'Shopee') return r.shopee;
                if (_wh == 'TikTok') return r.tiktok;
                if (_wh == 'Lazada') return r.lazada;
                return r.wh == _wh;
              }).toList();
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
                      value: {'all', 'MARKETPLACE', 'Shopee', 'TikTok', 'Lazada', ...warehouses}.contains(_wh)
                          ? _wh
                          : 'all',
                      onChanged: (v) => setState(() => _wh = v ?? 'all'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        const DropdownMenuItem(value: 'MARKETPLACE', child: Text('MARKETPLACE')),
                        const DropdownMenuItem(value: 'Shopee', child: Text('Shopee')),
                        const DropdownMenuItem(value: 'TikTok', child: Text('TikTok')),
                        const DropdownMenuItem(value: 'Lazada', child: Text('Lazada')),
                        ...warehouses
                            .where((w) => !{'MARKETPLACE', 'Shopee', 'TikTok', 'Lazada'}.contains(w))
                            .map((w) => DropdownMenuItem(value: w, child: Text(w))),
                      ],
                    ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: store.loading ? null : _search,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('ค้นหา'),
                      ),
                    ),
                  ],
                ),
                if (store.error != null) ...[
                  const SizedBox(height: 12),
                  Text(store.error!, style: const TextStyle(color: Pal.err)),
                ],
                if (store.loading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(minHeight: 3),
                ],
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
                if (rows.isEmpty && !store.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('ไม่พบสินค้าในคลัง')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ok(bool v) {
    return Icon(v ? Icons.check_circle_rounded : Icons.remove_circle_outline, size: 20, color: v ? Pal.ok : Pal.faint);
  }
}
