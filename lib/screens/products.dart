import 'package:flutter/material.dart';

import '../api.dart';
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

  Future<void> _syncNow() async {
    final platform = _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await ProductStore.instance.load(platform: platform);
      await InventoryStore.instance.load();
      if (!mounted) return;
      final msg = MarketplaceSyncStore.instance.lastMessage ?? 'Sync สำเร็จ';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ProductStore.instance, MarketplaceSyncStore.instance]),
      builder: (context, _) {
        final store = ProductStore.instance;
        final syncStore = MarketplaceSyncStore.instance;
        final rows = store.products.where((p) => _ch == 'all' || p.channel.name == _ch).toList();
        final busy = store.loading || syncStore.syncing;
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
                        onPressed: busy ? null : _search,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('ค้นหา'),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : _syncNow,
                        icon: syncStore.syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(syncStore.syncing ? 'กำลัง Sync...' : 'Sync Now'),
                      ),
                    ),
                  ],
                ),
                if (store.error != null) ...[
                  const SizedBox(height: 12),
                  Text(store.error!, style: const TextStyle(color: Pal.err)),
                ],
                if (busy) ...[
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
                      DataColumn(label: Text('ชื่อสินค้า')),
                      DataColumn(label: Text('แพลตฟอร์ม')),
                      DataColumn(label: Text('ราคา')),
                      DataColumn(label: Text('สต็อก')),
                      DataColumn(label: Text('สถานะ')),
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
                          ],
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty && !busy)
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
