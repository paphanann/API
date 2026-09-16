import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _ch = 'all';

  @override
  void initState() {
    super.initState();
    ProductStore.instance.load();
  }

  Future<void> _search() async {
    final platform = _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;
    await ProductStore.instance.load(platform: platform);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProductStore.instance,
      builder: (context, _) {
        final store = ProductStore.instance;
        final rows = store.products.where((p) => _ch == 'all' || p.channel.name == _ch).toList();
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
                            DataCell(
                              pill(
                                p.synced ? 'Synced' : 'Pending',
                                p.synced ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                p.synced ? Pal.okBg : Pal.warnBg,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty && !store.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('ไม่พบสินค้า')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
