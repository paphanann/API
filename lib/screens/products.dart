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
  static const _pageSize = 50;

  String _ch = 'all';
  String _shop = 'all';
  String _st = 'all';
  String _map = 'all';
  String _q = '';
  int _page = 1;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      if (_st == 'active' && (p.status == ProductStatus.inactive || p.stockTotal <= 0)) return false;
      if (_st == 'inactive' && p.status != ProductStatus.inactive) return false;
      if (_st == 'oos' && (p.stockTotal > 0 || p.status == ProductStatus.inactive)) return false;
      if (_map != 'all' && p.mappingStatus.name != _map) return false;
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('สินค้า', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'รายการสินค้าจาก Shopee, Lazada และ TikTok',
                style: TextStyle(color: Pal.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Panel(
                  expand: true,
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
                          label: 'สถานะสินค้า',
                          value: _st,
                          width: 150,
                          onChanged: (v) => setState(() {
                            _st = v ?? 'all';
                            _page = 1;
                          }),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'active', child: Text('พร้อมขาย')),
                            DropdownMenuItem(value: 'inactive', child: Text('ปิดการขาย')),
                            DropdownMenuItem(value: 'oos', child: Text('สินค้าหมด')),
                          ],
                        ),
                        Drop<String>(
                          label: 'สถานะ Mapping',
                          value: _map,
                          width: 170,
                          onChanged: (v) => setState(() {
                            _map = v ?? 'all';
                            _page = 1;
                          }),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'mapped', child: Text('จับคู่แล้ว')),
                            DropdownMenuItem(value: 'partial', child: Text('จับคู่บางส่วน')),
                            DropdownMenuItem(value: 'unmapped', child: Text('ยังไม่จับคู่')),
                            DropdownMenuItem(value: 'noSku', child: Text('ไม่มี SKU')),
                          ],
                        ),
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
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          return _TableViewport(
                            width: box.maxWidth,
                            child: FillTable(
                              minWidth: 1120,
                              viewportWidth: box.maxWidth.isFinite ? box.maxWidth : null,
                              header: Column(
                                children: [
                                  _header(),
                                  const Divider(height: 1),
                                ],
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < rows.length; i++) _ProductBlock(rows[i], start + i + 1),
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
                      ),
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
        shop: const Text('ร้านค้า', style: tableHead),
        price: const Text('ราคาเริ่มต้น', style: tableHead),
        stock: const Text('สต็อกรวม', style: tableHead),
        status: const Text('สถานะสินค้า', style: tableHead),
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
  final Widget mapping;

  @override
  Widget build(BuildContext context) {
    Widget flex(int n, Widget child) {
      return Expanded(
        flex: n,
        child: Align(alignment: Alignment.centerLeft, child: child),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 36, child: seq),
        flex(7, product),
        flex(2, Padding(padding: const EdgeInsets.only(left: 28), child: platform)),
        flex(2, shop),
        flex(2, price),
        flex(1, stock),
        flex(2, status),
        flex(2, mapping),
        flex(2, problem),
      ],
    );
  }
}

Widget _parentMapPill(Product p) {
  switch (p.mappingStatus) {
    case MappingStatus.mapped:
      return pill(p.mappingLabel, const Color(0xFF15803D), Pal.okBg);
    case MappingStatus.partial:
      return pill(p.mappingLabel, const Color(0xFFB45309), Pal.warnBg);
    case MappingStatus.unmapped:
      return pill(p.mappingLabel, const Color(0xFFB91C1C), Pal.errBg);
    case MappingStatus.noSku:
      return pill(p.mappingLabel, const Color(0xFFBE185D), const Color(0xFFFCE7F3));
  }
}

Widget _varMapPill(ProductVariant v) {
  if (!v.hasSellerSku) {
    return pill('ไม่มี SKU', const Color(0xFFBE185D), const Color(0xFFFCE7F3));
  }
  if (v.mapped) {
    return pill('จับคู่แล้ว', const Color(0xFF15803D), Pal.okBg);
  }
  return pill('ยังไม่จับคู่', const Color(0xFFB91C1C), Pal.errBg);
}

Widget _problemCell(String text) {
  if (text.isEmpty || text == '-') {
    return const Text('-', style: TextStyle(color: Pal.muted, fontSize: 13));
  }
  return Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: text.contains('ไม่มี SKU') ? const Color(0xFFDC2626) : Pal.text,
    ),
  );
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _copyCode,
                          child: Text(
                            'รหัสสินค้า / Item SKU : $_code',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Pal.muted),
                          ),
                        ),
                        if (p.hasVariants) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => setState(() => _open = !_open),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: Pal.primary),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${p.variantCount} ตัวเลือกสินค้า',
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
              status: productPill(p.status, stock: p.stockTotal),
              mapping: _parentMapPill(p),
              problem: _problemCell(p.problem),
            ),
          ),
        if (_open && p.hasVariants)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 8, 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Pal.line),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _variantTable(p, maxWidth: constraints.maxWidth),
                  );
                },
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _variantTable(Product p, {required double maxWidth}) {
    var optionW = _colW(['ตัวเลือก', ...p.variants.map((v) => v.option)], min: 88, max: 220);
    var skuW = _colW(['SKU', ...p.variants.map((v) => v.sellerSku)], min: 88);
    var modelW = _colW(['Model ID', ...p.variants.map((v) => v.modelId)], min: 120);
    var priceW = _colW(['ราคา', ...p.variants.map((v) => baht.format(v.price))], min: 96);
    var stockW = _colW(['Stock', ...p.variants.map((v) => '${v.stock}')], min: 64);
    var sapW = _colW(['ItemCode', ...p.variants.map((v) => v.sapItemCode)], min: 110);
    var mapW = 118.0;
    const gaps = _VarCols.gap * 7;
    final natural = _VarCols.seqW + optionW + skuW + modelW + priceW + stockW + sapW + mapW + gaps + 24;
    final target = maxWidth > natural ? maxWidth : natural;
    final extra = target - natural;
    if (extra > 0) {
      optionW += extra * 0.34;
      skuW += extra * 0.16;
      modelW += extra * 0.16;
      sapW += extra * 0.20;
      mapW += extra * 0.14;
    }
    return SizedBox(
      width: target,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _VarCols(
            optionW: optionW,
            skuW: skuW,
            modelW: modelW,
            priceW: priceW,
            stockW: stockW,
            sapW: sapW,
            mapW: mapW,
            seq: const Text('#', style: tableHead, maxLines: 1, softWrap: false),
            option: const Text('ตัวเลือก', style: tableHead, maxLines: 1, softWrap: false),
            sku: const Text('SKU', style: tableHead, maxLines: 1, softWrap: false),
            modelId: const Text('Model ID', style: tableHead, maxLines: 1, softWrap: false),
            price: const Text('ราคา', style: tableHead, maxLines: 1, softWrap: false),
            stock: const Text('Stock', style: tableHead, maxLines: 1, softWrap: false),
            sap: const Text('ItemCode', style: tableHead, maxLines: 1, softWrap: false),
            mapping: const Text('Mapping', style: tableHead, maxLines: 1, softWrap: false),
          ),
        ),
        for (var i = 0; i < p.variants.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _VarCols(
              optionW: optionW,
              skuW: skuW,
              modelW: modelW,
              priceW: priceW,
              stockW: stockW,
              sapW: sapW,
              mapW: mapW,
              seq: Text('${i + 1}', style: const TextStyle(color: Pal.muted)),
              option: Text(
                p.variants[i].option.isEmpty ? '-' : p.variants[i].option,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              sku: _codeText(p.variants[i].sellerSku),
              modelId: _codeText(p.variants[i].modelId),
              price: Text(baht.format(p.variants[i].price), maxLines: 1, softWrap: false),
              stock: Text('${p.variants[i].stock}', maxLines: 1, softWrap: false),
              sap: _codeText(p.variants[i].sapItemCode),
              mapping: _varMapPill(p.variants[i]),
            ),
          ),
        ],
      ],
      ),
    );
  }

  double _colW(Iterable<String> values, {required double min, double max = 520}) {
    var longest = 1;
    for (final value in values) {
      final n = value.trim().isEmpty ? 1 : value.trim().length;
      if (n > longest) longest = n;
    }
    final width = 20 + longest * 8.6;
    if (width < min) return min;
    if (width > max) return max;
    return width;
  }

  Widget _codeText(String value) {
    final text = value.trim().isEmpty ? '-' : value.trim();
    return Text(text, maxLines: 1, softWrap: false, style: const TextStyle(fontWeight: FontWeight.w600));
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

class _VarCols extends StatelessWidget {
  const _VarCols({
    required this.optionW,
    required this.skuW,
    required this.modelW,
    required this.priceW,
    required this.stockW,
    required this.sapW,
    required this.mapW,
    required this.seq,
    required this.option,
    required this.sku,
    required this.modelId,
    required this.price,
    required this.stock,
    required this.sap,
    required this.mapping,
  });

  static const gap = 20.0;
  static const seqW = 36.0;

  final double optionW;
  final double skuW;
  final double modelW;
  final double priceW;
  final double stockW;
  final double sapW;
  final double mapW;
  final Widget seq;
  final Widget option;
  final Widget sku;
  final Widget modelId;
  final Widget price;
  final Widget stock;
  final Widget sap;
  final Widget mapping;

  @override
  Widget build(BuildContext context) {
    Widget cell(double w, Widget child, {Alignment align = Alignment.centerLeft}) {
      return SizedBox(width: w, child: Align(alignment: align, child: child));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        cell(seqW, seq),
        const SizedBox(width: gap),
        cell(optionW, option),
        const SizedBox(width: gap),
        cell(skuW, sku),
        const SizedBox(width: gap),
        cell(modelW, modelId),
        const SizedBox(width: gap),
        cell(priceW, price),
        const SizedBox(width: gap),
        cell(stockW, stock),
        const SizedBox(width: gap),
        cell(sapW, sap),
        const SizedBox(width: gap),
        cell(mapW, mapping),
      ],
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
