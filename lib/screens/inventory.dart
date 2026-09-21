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
      if (mounted) InventoryStore.instance.load();
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

  List<StockRow> _filtered() {
    final q = _q.toLowerCase();
    return InventoryStore.instance.rows.where((r) {
      if (_ch != 'all' && r.channel?.name != _ch) return false;
      if (!inDayRange(r.updatedAt, _from, _to)) return false;
      if (q.isEmpty) return true;
      return r.warehouseName.toLowerCase().contains(q) ||
          r.warehouseId.toLowerCase().contains(q) ||
          r.sapWhsCode.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([InventoryStore.instance, MarketplaceSyncStore.instance]),
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
                'คลังสินค้าของ Shopee, Lazada และ TikTok',
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
                          width: 180,
                          onChanged: (v) => setState(() {
                            _ch = v ?? 'all';
                            _page = 1;
                          }),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                          ],
                        ),
                        DateRangeField(from: _from, to: _to, onTap: _pickRange),
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            onSubmitted: (_) => _searchTap(),
                            decoration: const InputDecoration(
                              hintText: 'ค้นหาชื่อคลัง Warehouse ID หรือ SAP WhsCode',
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
                      minWidth: 1280,
                      child: DataTable(
                        headingRowColor: tableHeadBg,
                        headingTextStyle: tableHead,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 64,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('Platform')),
                          DataColumn(label: Text('ชื่อคลัง')),
                          DataColumn(label: Text('Warehouse ID')),
                          DataColumn(label: Text('SAP WhsCode')),
                          DataColumn(label: Text('Stock')),
                          DataColumn(label: Text('Default')),
                          DataColumn(label: Text('สถานะ')),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(
                              cells: [
                                DataCell(
                                  r.channel == null
                                      ? const Text('-')
                                      : ChannelLabel(channel: r.channel!),
                                ),
                                DataCell(_cell(200, Text(r.warehouseName, maxLines: 2, overflow: TextOverflow.ellipsis))),
                                DataCell(_cell(150, Text(r.warehouseId))),
                                DataCell(_cell(130, Text(r.sapWhsCode))),
                                DataCell(_cell(80, Text('${r.stock}'))),
                                DataCell(
                                  r.isDefault
                                      ? pill('Default', const Color(0xFF15803D), Pal.okBg)
                                      : const Text('-'),
                                ),
                                DataCell(warehouseStatusPill(r.status)),
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

  Widget _cell(double width, Widget child) {
    return SizedBox(width: width, child: Align(alignment: Alignment.centerLeft, child: child));
  }
}
