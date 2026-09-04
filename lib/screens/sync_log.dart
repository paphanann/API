import 'package:flutter/material.dart';

import '../dummy.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/ui.dart';

class SyncLogScreen extends StatefulWidget {
  const SyncLogScreen({super.key});

  @override
  State<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends State<SyncLogScreen> {
  String _ch = 'all';
  String _st = 'all';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final rows = Dummy.logs.where((l) {
      final chOk = _ch == 'all' || l.channel.name == _ch;
      final stOk = _st == 'all' || l.status.name == _st;
      return chOk && stOk;
    }).toList();

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
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('ทั้งหมด'),
                    ),
                    ...Channel.values.map(
                      (c) =>
                          DropdownMenuItem(value: c.name, child: Text(c.label)),
                    ),
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
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('ค้นหา'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FillTable(
              child: DataTable(
                headingRowColor: tableHeadBg,
                headingTextStyle: tableHead,
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
                ],
                rows: [
                  for (final l in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(dtFmt.format(l.time))),
                        DataCell(ChannelLabel(channel: l.channel)),
                        DataCell(
                          Text(
                            l.orderNo,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(l.action)),
                        DataCell(syncPill(l.status)),
                        DataCell(Text(l.msg)),
                        DataCell(Text(l.docEntry ?? '-')),
                        DataCell(Text(l.docNum ?? '-')),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Pages(
              page: _page,
              total: 8,
              onTap: (p) => setState(() => _page = p),
            ),
          ],
        ),
      ),
    );
  }
}
