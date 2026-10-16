import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/sync_status.dart';
import '../widgets/ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _pageSize = 10;

  String _ch = 'all';
  String _shop = 'all';
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
        InventoryStore.instance.load();
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
    await InventoryStore.instance.load(platform: platform);
  }

  void _onQuery(String v) {
    setState(() {
      _q = v;
      _page = 1;
    });
  }

  Future<void> _syncNow() async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await InventoryStore.instance.load(
        platform: _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform,
      );
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

  bool _matchShop(StockRow r) {
    if (_shop == 'all') return true;
    ShopConn? shop;
    for (final s in ShopStore.instance.realShops) {
      if ('${s.channel.name}|${s.shopId}' == _shop) shop = s;
    }
    if (shop == null) return false;
    if (r.channel != null && r.channel != shop.channel) return false;
    final keys = {r.shopId.trim().toLowerCase(), r.shopName.trim().toLowerCase()}..removeWhere((v) => v.isEmpty || v == '-');
    if (keys.isEmpty) {
      final same = [for (final s in ShopStore.instance.realShops) if (s.channel == shop.channel && s.isReal) s];
      return same.length <= 1;
    }
    return keys.any((id) => shop!.identityKeys.contains(id) || shop.identityKeys.any((w) => w.contains(id) || id.contains(w)));
  }

  List<StockRow> _filtered() {
    final q = _q.toLowerCase();
    return InventoryStore.instance.rows.where((r) {
      if (_ch != 'all' && r.channel?.name != _ch) return false;
      if (!_matchShop(r)) return false;
      if (!inDayRange(r.updatedAt, _from, _to)) return false;
      if (q.isEmpty) return true;
      return r.warehouseName.toLowerCase().contains(q) ||
          r.warehouseId.toLowerCase().contains(q) ||
          r.sapWhsCode.toLowerCase().contains(q) ||
          r.shopName.toLowerCase().contains(q);
    }).toList();
  }

  List<String> _sapCodes(StockRow r) {
    return [
      ...{
        '',
        for (final w in sapWarehouses) w.code,
        if (r.sapWhsCode.isNotEmpty && r.sapWhsCode != '-') r.sapWhsCode,
      },
    ];
  }

  Future<void> _setSap(StockRow r, String? code) async {
    await InventoryStore.instance.mapSap(r, code ?? '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(code == null || code.isEmpty ? 'ล้างแมปคลัง SAP แล้ว' : 'แมปคลัง SAP เป็น ${warehouseLabel(code)} แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([InventoryStore.instance, ShopStore.instance, MarketplaceSyncStore.instance]),
      builder: (context, _) {
        final store = InventoryStore.instance;
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
              const Text('คลังสินค้า', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'แมปคลัง SAP กับคลังของแต่ละแพลตฟอร์ม',
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
                          onChanged: (v) {
                            _ch = v ?? 'all';
                            _shop = 'all';
                            _page = 1;
                            setState(() {});
                            _searchTap();
                          },
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                          ],
                        ),
                        Drop<String>(
                          label: 'ร้านค้า',
                          value: _shop,
                          width: 200,
                          onChanged: (v) => setState(() {
                            _shop = v ?? 'all';
                            _page = 1;
                          }),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทุกร้าน')),
                            for (final s in ShopStore.instance.realShops)
                              if (s.isReal && (_ch == 'all' || s.channel.name == _ch))
                                DropdownMenuItem(value: '${s.channel.name}|${s.shopId}', child: Text(s.displayName)),
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
                              hintText: 'ค้นหาคลัง / Warehouse ID / SAP',
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
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                      minWidth: 1380,
                      child: DataTable(
                        headingRowColor: tableHeadBg,
                        headingTextStyle: tableHead,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 72,
                        columnSpacing: 20,
                        headingRowHeight: 48,
                        columns: [
                          const DataColumn(label: Text('แพลตฟอร์ม')),
                          const DataColumn(label: Text('ชื่อร้าน')),
                          const DataColumn(label: Text('คลัง Marketplace')),
                          const DataColumn(label: Text('Warehouse ID')),
                          const DataColumn(label: Text('SAP WhsCode')),
                          DataColumn(
                            label: Row(
                              children: [
                                const Text('ชื่อคลัง SAP'),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'ชื่อคลังตามรหัส SAP ที่แมปไว้',
                                  child: Icon(Icons.info_outline, size: 14, color: Pal.muted),
                                ),
                              ],
                            ),
                          ),
                          const DataColumn(label: Text('Stock')),
                          const DataColumn(label: Text('สถานะ')),
                          const DataColumn(label: Text('อัปเดตล่าสุด')),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(
                              cells: [
                                DataCell(
                                  r.channel == null ? const Text('-') : ChannelLabel(channel: r.channel!, maxLabelWidth: 90),
                                ),
                                DataCell(_cell(140, Text(_shopLabel(r), maxLines: 1, overflow: TextOverflow.ellipsis))),
                                DataCell(_cell(130, Text(r.warehouseName.isEmpty || r.warehouseName == '-' ? 'MARKETPLACE' : r.warehouseName))),
                                DataCell(_cell(110, Text(r.warehouseId.isEmpty ? '-' : r.warehouseId))),
                                DataCell(_sapDrop(r)),
                                DataCell(_cell(120, Text(_sapName(r.sapWhsCode)))),
                                DataCell(_cell(70, Text('${r.stock}'))),
                                DataCell(_status(r)),
                                DataCell(_cell(130, Text(r.updatedAt == null ? '-' : dtFmt.format(r.updatedAt!)))),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (rows.isEmpty && !busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ไม่พบคลังสินค้า')),
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

  String _shopLabel(StockRow r) {
    if (r.channel == null) {
      return r.shopName.isNotEmpty && r.shopName != '-' ? r.shopName : '-';
    }
    return ShopStore.instance.nameFor(channel: r.channel!, shopId: r.shopId, shopName: r.shopName);
  }

  String _sapName(String code) {
    if (code.isEmpty || code == '-') return '-';
    final w = warehouseByCode(code);
    if (w == null) return code;
    return w.name.isEmpty ? w.code : w.name;
  }

  Widget _sapDrop(StockRow r) {
    final codes = _sapCodes(r);
    final value = codes.contains(r.sapWhsCode) ? r.sapWhsCode : '';
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${r.key}-$value'),
        initialValue: value,
        isExpanded: true,
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('เลือกคลัง')),
          for (final c in codes)
            if (c.isNotEmpty) DropdownMenuItem(value: c, child: Text(warehouseLabel(c), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: storeBusy ? null : (v) => _setSap(r, v),
      ),
    );
  }

  bool get storeBusy => InventoryStore.instance.loading || InventoryStore.instance.saving;

  Widget _status(StockRow r) {
    ShopConn? shop;
    for (final s in ShopStore.instance.realShops) {
      if (r.channel != null && s.channel != r.channel) continue;
      if (r.shopId.isNotEmpty && r.shopId != '-' && (s.shopId == r.shopId || s.shop == r.shopId)) shop = s;
    }
    final on = shop?.connected ?? r.status.toLowerCase().contains('connect') || r.status.toLowerCase().contains('active') || r.status.toLowerCase().contains('live');
    if (on) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Pal.ok),
          const SizedBox(width: 6),
          Text('เชื่อมแล้ว', style: TextStyle(color: Pal.ok, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );
    }
    return const Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: Pal.err),
        SizedBox(width: 6),
        Text('ยังไม่เชื่อม', style: TextStyle(color: Pal.err, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _cell(double width, Widget child) {
    return SizedBox(width: width, child: Align(alignment: Alignment.centerLeft, child: child));
  }
}
