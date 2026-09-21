import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/sync_status.dart';
import '../widgets/ui.dart';

class SyncLogScreen extends StatefulWidget {
  const SyncLogScreen({super.key});

  @override
  State<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends State<SyncLogScreen> {
  static const _pageSize = 10;

  String _ch = 'all';
  String _st = 'all';
  int _page = 1;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _to = today;
    _from = today.subtract(const Duration(days: 7));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SyncLogStore.instance.load();
    });
  }

  List<SyncRow> _rows() {
    return SyncLogStore.instance.logs.where((l) {
      if (_ch != 'all' && l.channel.name != _ch) return false;
      if (_st != 'all' && l.status.name != _st) return false;
      if (!inDayRange(l.time, _from, _to)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickRange() async {
    final today = dateOnly(DateTime.now());
    final picked = await showSimpleCalendar(
      context: context,
      from: _from ?? today.subtract(const Duration(days: 7)),
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

  Future<void> _syncNow() async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      if (!mounted) return;
      await showSystemStatusSnack(context);
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
      listenable: Listenable.merge([SyncLogStore.instance, MarketplaceSyncStore.instance]),
      builder: (context, _) {
        final store = SyncLogStore.instance;
        final syncStore = MarketplaceSyncStore.instance;
        final all = _rows();
        final pages = (all.length / _pageSize).ceil().clamp(1, 9999);
        if (_page > pages) _page = pages;
        final start = (_page - 1) * _pageSize;
        final rows = all.skip(start).take(_pageSize).toList();
        final busy = store.loading || syncStore.syncing;
        final fromN = all.isEmpty ? 0 : start + 1;
        final toN = start + rows.length;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Panel(
            title: 'ประวัติการซิงก์ข้อมูล',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    DateRangeField(from: _from, to: _to, onTap: _pickRange),
                    Drop<String>(
                      label: 'แพลตฟอร์ม',
                      value: _ch,
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
                      onChanged: (v) => setState(() {
                        _st = v ?? 'all';
                        _page = 1;
                      }),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(value: 'success', child: Text('Success')),
                        DropdownMenuItem(value: 'error', child: Text('Error')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      ],
                    ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                setState(() => _page = 1);
                                SyncLogStore.instance.load();
                              },
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
                  Material(
                    color: Pal.errBg,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(store.error!, style: const TextStyle(color: Pal.err)),
                    ),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 16),
                FillTable(
                  minWidth: 1400,
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 72,
                    columns: const [
                      DataColumn(label: Text('เวลา')),
                      DataColumn(label: Text('Platform')),
                      DataColumn(label: Text('Order No.')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('สถานะ')),
                      DataColumn(label: Text('ข้อความ')),
                      DataColumn(label: SizedBox(width: 120, child: Text('SAP DocEntry', softWrap: false))),
                      DataColumn(label: SizedBox(width: 110, child: Text('SAP DocNum', softWrap: false))),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final l in rows)
                        DataRow(
                          cells: [
                            DataCell(Text(dtFmt.format(l.time), maxLines: 1, softWrap: false)),
                            DataCell(ChannelLabel(channel: l.channel)),
                            DataCell(Text(
                              l.orderNo,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            )),
                            DataCell(Text(l.action, maxLines: 1, softWrap: false)),
                            DataCell(syncPill(l.status)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: Text(l.msg, maxLines: 3, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(SizedBox(width: 120, child: Text(l.docEntry ?? '-', maxLines: 1, softWrap: false))),
                            DataCell(SizedBox(width: 110, child: Text(l.docNum ?? '-', maxLines: 1, softWrap: false))),
                            DataCell(
                              TextButton(
                                onPressed: () => context.go('/sync-log/${Uri.encodeComponent(l.routeId)}'),
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
                    child: Center(child: Text('ไม่พบประวัติการซิงก์')),
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
        );
      },
    );
  }
}

class ErrorDetailScreen extends StatefulWidget {
  const ErrorDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<ErrorDetailScreen> createState() => _ErrorDetailScreenState();
}

class _ErrorDetailScreenState extends State<ErrorDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (SyncLogStore.instance.logs.isEmpty) {
      SyncLogStore.instance.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncLogStore.instance,
      builder: (context, _) {
        final row = SyncLogStore.instance.byRouteId(Uri.decodeComponent(widget.id));
        if (row == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ไม่พบรายละเอียดข้อผิดพลาด'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => context.go('/sync-log'), child: const Text('กลับ Sync Log')),
              ],
            ),
          );
        }

        Widget kv(String k, String v) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 160, child: Text(k, style: const TextStyle(color: Pal.muted))),
                Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => context.go('/sync-log'), icon: const Icon(Icons.arrow_back_rounded)),
                  const Text('Error Detail', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  syncPill(row.status),
                ],
              ),
              const SizedBox(height: 16),
              Panel(
                title: 'รายละเอียดข้อผิดพลาด',
                child: Column(
                  children: [
                    kv('เวลา', dtSec.format(row.time)),
                    kv('Platform', row.channel.label),
                    kv('Order No.', row.orderNo),
                    kv('Action', row.action),
                    kv('ข้อความ', row.msg),
                    kv('SAP DocEntry', row.docEntry ?? '-'),
                    kv('SAP DocNum', row.docNum ?? '-'),
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

