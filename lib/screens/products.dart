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
  static const _pageSize = 10;

  String _ch = 'all';
  String _st = 'all';
  String _q = '';
  int _page = 1;
  DateTime? _from;
  DateTime? _to;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _to = today;
    _from = today.subtract(const Duration(days: 30));
    ProductStore.instance.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchTap() async {
    setState(() {
      _q = _search.text.trim();
      _page = 1;
    });
    final platform = _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;
    await ProductStore.instance.load(platform: platform);
  }

  void _onQuery(String v) {
    setState(() {
      _q = v;
      _page = 1;
    });
  }

  Future<void> _syncNow() async {
    final platform = _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;
    try {
      await MarketplaceSyncStore.instance.syncNow(force: true);
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

  Future<void> _pickRange() async {
    final today = dateOnly(DateTime.now());
    final picked = await showSimpleCalendar(
      context: context,
      from: _from ?? today.subtract(const Duration(days: 30)),
      to: _to ?? today,
    );
    if (picked == null) return;
    setState(() {
      if (picked.cleared) {
        _from = null;
        _to = null;
      } else {
        _from = dateOnly(picked.range!.start);
        _to = dateOnly(picked.range!.end);
      }
      _page = 1;
    });
  }

  List<Product> _filtered() {
    final q = _q.toLowerCase();
    return ProductStore.instance.products.where((p) {
      if (_ch != 'all' && p.channel.name != _ch) return false;
      if (_st != 'all' && p.status.name != _st) return false;
      if (!inDayRange(p.updatedAt, _from, _to)) return false;
      if (q.isEmpty) return true;
      if (p.sku.toLowerCase().contains(q) || p.name.toLowerCase().contains(q) || p.displayId.toLowerCase().contains(q)) {
        return true;
      }
      return p.variants.any(
        (v) => v.sku.toLowerCase().contains(q) || v.modelId.toLowerCase().contains(q) || v.option.toLowerCase().contains(q),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ProductStore.instance, MarketplaceSyncStore.instance]),
      builder: (context, _) {
        final store = ProductStore.instance;
        final syncStore = MarketplaceSyncStore.instance;
        final all = _filtered();
        final pages = (all.length / _pageSize).ceil().clamp(1, 9999);
        if (_page > pages) _page = pages;
        final start = (_page - 1) * _pageSize;
        final rows = all.skip(start).take(_pageSize).toList();
        final busy = store.loading || syncStore.syncing;
        final fromN = all.isEmpty ? 0 : start + 1;
        final toN = start + rows.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('สินค้า', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'รายการสินค้าจาก Shopee, Lazada และ TikTok',
                style: TextStyle(color: Pal.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Panel(
                pad: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                          width: 160,
                          onChanged: (v) => setState(() {
                            _ch = v ?? 'all';
                            _page = 1;
                          }),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                          ],
                        ),
                        Drop<String>(
                          label: 'สถานะ',
                          value: _st,
                          width: 160,
                          onChanged: (v) => setState(() {
                            _st = v ?? 'all';
                            _page = 1;
                          }),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'active', child: Text('พร้อมขาย')),
                            DropdownMenuItem(value: 'inactive', child: Text('ปิดขาย')),
                            DropdownMenuItem(value: 'draft', child: Text('ฉบับร่าง')),
                          ],
                        ),
                        DateRangeField(from: _from, to: _to, onTap: _pickRange),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            onSubmitted: (_) => _searchTap(),
                            decoration: const InputDecoration(
                              hintText: 'ค้นหา SKU หรือชื่อสินค้า',
                              prefixIcon: Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: busy ? null : _searchTap,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('ค้นหา'),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : _syncNow,
                            icon: syncStore.syncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 18),
                            label: Text(syncStore.syncing ? 'กำลัง Sync...' : 'Sync Now'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Pal.text,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Pal.line),
                            ),
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
                      minWidth: 1560,
                      child: Column(
                        children: [
                          _header(),
                          const Divider(height: 1),
                          for (final p in rows) _ProductBlock(p),
                        ],
                      ),
                    ),
                    if (rows.isEmpty && !busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ไม่พบสินค้า')),
                      ),
                    const SizedBox(height: 16),
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: _ProdCols(
        chevron: const SizedBox.shrink(),
        product: const Text('สินค้า', style: tableHead),
        platform: const Text('แพลตฟอร์ม', style: tableHead),
        price: const Text('ราคาเริ่มต้น', style: tableHead),
        stock: const Text('Stock รวม', style: tableHead),
        variants: const Text('จำนวน Variant', style: tableHead),
        status: const Text('สถานะ', style: tableHead),
        sap: const Text('SAP ItemCode', style: tableHead),
        mapping: const Text('Mapping', style: tableHead),
      ),
    );
  }
}

class _ProdCols extends StatelessWidget {
  const _ProdCols({
    required this.chevron,
    required this.product,
    required this.platform,
    required this.price,
    required this.stock,
    required this.variants,
    required this.status,
    required this.sap,
    required this.mapping,
  });

  final Widget chevron;
  final Widget product;
  final Widget platform;
  final Widget price;
  final Widget stock;
  final Widget variants;
  final Widget status;
  final Widget sap;
  final Widget mapping;

  @override
  Widget build(BuildContext context) {
    Widget cell(double w, Widget child) {
      return SizedBox(
        width: w,
        child: Align(alignment: Alignment.centerLeft, child: child),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: chevron),
        Expanded(child: product),
        cell(140, platform),
        cell(120, price),
        cell(100, stock),
        cell(130, variants),
        cell(120, status),
        cell(140, sap),
        cell(150, mapping),
      ],
    );
  }
}

Widget _mapPill(bool mapped, {String? label}) {
  final text = label ?? (mapped ? 'Mapped' : 'Not Mapped');
  if (text == 'บางส่วน') {
    return pill('บางส่วน', const Color(0xFFB45309), Pal.warnBg);
  }
  return mapped
      ? pill('Mapped', const Color(0xFF15803D), Pal.okBg)
      : pill('Not Mapped', const Color(0xFFB91C1C), Pal.errBg);
}

class _ProductBlock extends StatefulWidget {
  const _ProductBlock(this.p);

  final Product p;

  @override
  State<_ProductBlock> createState() => _ProductBlockState();
}

class _ProductBlockState extends State<_ProductBlock> {
  bool _open = false;

  /// Shopee มักไม่ใส่ model_sku — อย่าเอา model_id มาโชว์ซ้ำในคอลัมน์ SKU
  String _sellerSku(ProductVariant v) {
    final sku = v.sku.trim();
    if (sku.isEmpty || sku == '-' || sku == v.modelId) return '-';
    return sku;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(
      children: [
        InkWell(
          onTap: p.hasVariants ? () => setState(() => _open = !_open) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: _ProdCols(
              chevron: p.hasVariants
                  ? Icon(_open ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 22, color: Pal.muted)
                  : const SizedBox.shrink(),
              product: Row(
                children: [
                  _thumb(p.imageUrl.isNotEmpty ? p.imageUrl : (p.hasVariants ? p.variants.first.imageUrl : '')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Product ID: ${p.displayId}', style: const TextStyle(fontSize: 12, color: Pal.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              platform: ChannelLabel(channel: p.channel),
              price: Text(baht.format(p.priceFrom), style: const TextStyle(fontWeight: FontWeight.w600)),
              stock: Text('${p.stockTotal}'),
              variants: Text(p.hasVariants ? '${p.variantCount}' : '-'),
              status: productPill(p.status),
              sap: Text(p.parentSap.isEmpty ? '-' : p.parentSap, maxLines: 1, overflow: TextOverflow.ellipsis),
              mapping: _mapPill(p.mapped, label: p.parentSap == 'บางส่วน' ? 'บางส่วน' : null),
            ),
          ),
        ),
        if (_open && p.hasVariants)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(36, 0, 8, 12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Pal.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('รายการสินค้าย่อย (Variant)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                FillTable(
                  minWidth: 980,
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    columnSpacing: 24,
                    horizontalMargin: 12,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 60,
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Model ID')),
                      DataColumn(label: Text('ตัวเลือก')),
                      DataColumn(label: Text('ราคา')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('SAP ItemCode')),
                      DataColumn(label: Text('Mapping')),
                      DataColumn(label: Text('สถานะ')),
                    ],
                    rows: [
                      for (final v in p.variants)
                        DataRow(
                          cells: [
                            DataCell(Text(_sellerSku(v), style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(v.modelId.isEmpty ? '-' : v.modelId)),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(v.option.isEmpty ? '-' : v.option, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(Text(baht.format(v.price))),
                            DataCell(Text('${v.stock}')),
                            DataCell(Text(v.sapItemCode.isEmpty ? '-' : v.sapItemCode)),
                            DataCell(_mapPill(v.mapped)),
                            DataCell(productPill(v.status)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url.isEmpty || url == '-'
            ? Container(color: const Color(0xFFEEF2F7), child: const Icon(Icons.image_outlined, size: 20, color: Pal.faint))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFEEF2F7),
                  child: const Icon(Icons.image_outlined, size: 20, color: Pal.faint),
                ),
              ),
      ),
    );
  }
}
