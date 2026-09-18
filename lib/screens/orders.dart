import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
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
    final today = _dateOnly(DateTime.now());
    _to = today;
    _from = today.subtract(const Duration(days: 30));
    OrderStore.instance.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  bool get _hasDateFilter => _from != null && _to != null;

  Future<void> _searchTap() async {
    setState(() {
      _q = _search.text.trim();
      _page = 1;
    });
    final platform = _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;
    await OrderStore.instance.load(platform: platform);
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
      await OrderStore.instance.load(platform: platform);
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
    final today = _dateOnly(DateTime.now());
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
        _from = _dateOnly(picked.range!.start);
        _to = _dateOnly(picked.range!.end);
      }
      _page = 1;
    });
  }

  List<Order> _filtered() {
    final q = _q.toLowerCase();
    return OrderStore.instance.orders.where((o) {
      if (_ch != 'all' && o.channel.name != _ch) return false;
      if (_st != 'all' && o.status.name != _st) return false;
      if (_hasDateFilter) {
        final day = _dateOnly(o.createdAt);
        if (day.isBefore(_from!) || day.isAfter(_to!)) return false;
      }
      if (q.isNotEmpty && !o.id.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([OrderStore.instance, MarketplaceSyncStore.instance]),
      builder: (context, _) {
        final store = OrderStore.instance;
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
              const Text('คำสั่งซื้อ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'รายการคำสั่งซื้อจาก Shopee, Lazada และ TikTok',
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
                            DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
                            DropdownMenuItem(value: 'success', child: Text('สำเร็จ')),
                            DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
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
                              hintText: 'ค้นหาเลขคำสั่งซื้อ',
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
                      child: DataTable(
                        headingRowColor: tableHeadBg,
                        headingTextStyle: tableHead,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 64,
                        columns: const [
                          DataColumn(label: Text('Order No.')),
                          DataColumn(label: Text('Platform')),
                          DataColumn(label: Text('วันที่')),
                          DataColumn(label: Text('ยอดรวม')),
                          DataColumn(label: Text('สถานะ')),
                          DataColumn(label: Text('SAP DocNum')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: [
                          for (final o in rows)
                            DataRow(
                              cells: [
                                DataCell(Text(o.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(ChannelLabel(channel: o.channel)),
                                DataCell(Text(dtFmt.format(o.createdAt))),
                                DataCell(Text(baht.format(o.total), style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(orderPill(o.status)),
                                DataCell(Text(o.sapDocNum ?? '-')),
                                DataCell(
                                  TextButton(
                                    onPressed: () => context.go('/orders/${Uri.encodeComponent(o.id)}'),
                                    child: const Text('ดูรายละเอียด'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (rows.isEmpty && !busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ไม่พบคำสั่งซื้อ')),
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
}
