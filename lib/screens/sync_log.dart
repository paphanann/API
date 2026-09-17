import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SyncLogScreen extends StatefulWidget {
  const SyncLogScreen({super.key});

  @override
  State<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends State<SyncLogScreen> {
  String _ch = 'all';
  String _st = 'all';

  @override
  void initState() {
    super.initState();
    SyncLogStore.instance.load();
  }

  List<SyncRow> _rows() {
    return SyncLogStore.instance.logs.where((l) {
      final chOk = _ch == 'all' || l.channel.name == _ch;
      final stOk = _st == 'all' || l.status.name == _st;
      return chOk && stOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncLogStore.instance,
      builder: (context, _) {
        final store = SyncLogStore.instance;
        final rows = _rows();
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
                    Drop<String>(
                      label: 'แพลตฟอร์ม',
                      value: _ch,
                      onChanged: (v) => setState(() => _ch = v ?? 'all'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        ...Channel.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))),
                      ],
                    ),
                    Drop<String>(
                      label: 'สถานะ',
                      value: _st,
                      onChanged: (v) => setState(() => _st = v ?? 'all'),
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
                        onPressed: store.loading ? null : () => SyncLogStore.instance.load(),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('ค้นหา'),
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
                if (store.loading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 16),
                FillTable(
                  child: DataTable(
                    headingRowColor: tableHeadBg,
                    headingTextStyle: tableHead,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('เวลา')),
                      DataColumn(label: Text('Platform')),
                      DataColumn(label: Text('Order No.')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('สถานะ')),
                      DataColumn(label: Text('ข้อความ')),
                      DataColumn(label: Text('SAP DocEntry')),
                      DataColumn(label: Text('SAP DocNum')),
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
                                child: Text(l.msg, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(Text(l.docEntry ?? '-', maxLines: 1, softWrap: false)),
                            DataCell(Text(l.docNum ?? '-', maxLines: 1, softWrap: false)),
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
                if (rows.isEmpty && !store.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('ไม่พบประวัติการซิงก์')),
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

