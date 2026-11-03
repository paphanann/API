import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/sync_status.dart';
import '../widgets/ui.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const _pageSize = 10;

  String _ch = 'all';
  String _shop = 'all';
  String _st = 'active';
  String _issue = 'all';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ProductStore.instance.load();
        if (ShopStore.instance.realShops.isEmpty) ShopStore.instance.load();
      }
    });
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
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await ProductStore.instance.load(platform: platform);
      await InventoryStore.instance.load();
      if (!mounted) return;
      await showSystemStatusSnack(context);
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

  DateTime? _lastSyncAt() {
    DateTime? last;
    for (final s in ShopStore.instance.realShops) {
      final t = s.lastSync;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    for (final p in ProductStore.instance.products) {
      final t = p.updatedAt;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return last;
  }

  List<Product> _filtered() {
    final q = _q.toLowerCase();
    return ProductStore.instance.products.where((p) {
      if (_ch != 'all' && p.channel.name != _ch) return false;
      if (_shop != 'all' && _shop != '${p.channel.name}|${p.shopId}') return false;
      if (_st != 'all' && p.status.name != _st) return false;
      if (_issue == 'sap' && p.problem.isEmpty) return false;
      if (_issue == 'none' && p.problem.isNotEmpty) return false;
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
      listenable: Listenable.merge([ProductStore.instance, ShopStore.instance, MarketplaceSyncStore.instance]),
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
                pad: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _lastSyncAt() == null ? 'Sync ล่าสุด : -' : 'Sync ล่าสุด : ${dtFmt.format(_lastSyncAt()!)}',
                        style: const TextStyle(color: Pal.muted, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
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
                            _shop = 'all';
                            _page = 1;
                          }),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                          ],
                        ),
                        Drop<String>(
                          label: 'ร้านค้า',
                          value: _shop,
                          width: 180,
                          onChanged: (v) => setState(() {
                            _shop = v ?? 'all';
                            _page = 1;
                          }),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทุกร้าน')),
                            for (final s in ShopStore.instance.realShops)
                              if (s.connected && s.apiShopId.isNotEmpty && (_ch == 'all' || s.channel.name == _ch))
                                DropdownMenuItem(
                                  value: '${s.channel.name}|${s.apiShopId}',
                                  child: Text(s.displayName),
                                ),
                          ],
                        ),
                        Drop<String>(
                          label: 'สถานะ',
                          value: _st,
                          width: 150,
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
                        Drop<String>(
                          label: 'ปัญหา',
                          value: _issue,
                          width: 170,
                          onChanged: (v) => setState(() {
                            _issue = v ?? 'all';
                            _page = 1;
                          }),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'none', child: Text('ไม่มีปัญหา')),
                            DropdownMenuItem(value: 'sap', child: Text('ไม่พบสินค้าใน SAP')),
                          ],
                        ),
                        DateRangeField(from: _from, to: _to, onTap: _pickRange),
                        SizedBox(
                          width: 240,
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
                    LayoutBuilder(
                      builder: (context, box) {
                        return _TableViewport(
                          width: box.maxWidth,
                          child: FillTable(
                            minWidth: 1850,
                            child: Column(
                              children: [
                                _header(),
                                const Divider(height: 1),
                                for (var i = 0; i < rows.length; i++) _ProductBlock(rows[i], start + i + 1),
                              ],
                            ),
                          ),
                        );
                      },
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
        seq: const Text('#', style: tableHead),
        product: const Text('สินค้า', style: tableHead),
        platform: const Text('แพลตฟอร์ม', style: tableHead),
        shop: const Text('ชื่อร้าน', style: tableHead),
        price: const Text('ราคาเริ่มต้น', style: tableHead),
        stock: const Text('Stock รวม', style: tableHead),
        status: const Text('สถานะ', style: tableHead),
        sap: const Text('SAP ItemCode', style: tableHead),
        mapping: const Text('Mapping', style: tableHead),
        problem: const Text('ปัญหา', style: tableHead),
      ),
    );
  }
}

class _ProdCols extends StatelessWidget {
  const _ProdCols({
    required this.seq,
    required this.product,
    required this.platform,
    required this.price,
    required this.shop,
    required this.stock,
    required this.status,
    required this.problem,
    required this.sap,
    required this.mapping,
  });

  final Widget seq;
  final Widget product;
  final Widget platform;
  final Widget price;
  final Widget shop;
  final Widget stock;
  final Widget status;
  final Widget problem;
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
        SizedBox(width: 32, child: seq),
        Expanded(child: product),
        cell(140, platform),
        cell(160, shop),
        cell(120, price),
        cell(100, stock),
        cell(120, status),
        cell(140, sap),
        cell(150, mapping),
        cell(200, problem),
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
  const _ProductBlock(this.p, this.seq);

  final Product p;
  final int seq;

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

  String get _code {
    final sku = widget.p.sku.trim();
    if (sku.isNotEmpty && sku != '-') return sku;
    return widget.p.displayId;
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คัดลอกรหัสแล้ว')));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: _ProdCols(
              seq: Text('${widget.seq}', style: const TextStyle(color: Pal.muted)),
              product: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumb(p.imageUrl.isNotEmpty ? p.imageUrl : (p.hasVariants ? p.variants.first.imageUrl : '')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'รหัส ${_code}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Pal.muted),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _copyCode,
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.content_copy_rounded, size: 14, color: Pal.faint),
                              ),
                            ),
                          ],
                        ),
                        if (p.hasVariants) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => setState(() => _open = !_open),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Pal.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD6E2F5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: Pal.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${p.variantCount} รายการย่อย',
                                    style: const TextStyle(color: Pal.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              platform: ChannelLabel(channel: p.channel),
              price: Text(baht.format(p.priceFrom), style: const TextStyle(fontWeight: FontWeight.w600)),
              shop: Text(
                ShopStore.instance.nameFor(channel: p.channel, shopId: p.shopId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              stock: Text('${p.stockTotal}'),
              status: productPill(p.status),
              sap: Text(p.parentSap.isEmpty ? '-' : p.parentSap, maxLines: 1, overflow: TextOverflow.ellipsis),
              mapping: _mapPill(p.mapped, label: p.parentSap == 'บางส่วน' ? 'บางส่วน' : null),
              problem: productProblemCell(p.problem),
            ),
          ),
        if (_open && p.hasVariants)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Pal.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: DataTable(
                headingRowColor: tableHeadBg,
                headingTextStyle: tableHead,
                columnSpacing: 24,
                horizontalMargin: 16,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 60,
                columns: const [
                  DataColumn(label: SizedBox(width: 28, child: Text('#', maxLines: 1, softWrap: false))),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Model ID')),
                  DataColumn(label: Text('ตัวเลือก')),
                  DataColumn(label: Text('ราคา')),
                  DataColumn(label: Text('Stock')),
                  DataColumn(label: Text('SAP ItemCode')),
                  DataColumn(label: Text('Mapping')),
                  DataColumn(label: Text('สถานะ')),
                  DataColumn(label: Text('ปัญหา')),
                ],
                rows: [
                  for (var i = 0; i < p.variants.length; i++)
                    DataRow(
                      cells: [
                        DataCell(Text('${i + 1}', style: const TextStyle(color: Pal.muted))),
                        DataCell(Text(_sellerSku(p.variants[i]), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(p.variants[i].modelId.isEmpty ? '-' : p.variants[i].modelId)),
                        DataCell(Text(p.variants[i].option.isEmpty ? '-' : p.variants[i].option, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DataCell(Text(baht.format(p.variants[i].price))),
                        DataCell(Text('${p.variants[i].stock}')),
                        DataCell(Text(p.variants[i].sapItemCode.isEmpty ? '-' : p.variants[i].sapItemCode)),
                        DataCell(_mapPill(p.variants[i].mapped)),
                        DataCell(productPill(p.variants[i].status)),
                        DataCell(productProblemCell(p.variants[i].problem)),
                      ],
                    ),
                ],
              ),
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
        width: 56,
        height: 56,
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

class _TableViewport extends InheritedWidget {
  const _TableViewport({required this.width, required super.child});

  final double width;

  static double? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TableViewport>()?.width;
  }

  @override
  bool updateShouldNotify(_TableViewport oldWidget) => oldWidget.width != width;
}
