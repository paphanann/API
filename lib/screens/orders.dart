import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dummy.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _ch = 'all';
  String _st = 'all';
  int _page = 1;

  List<Order> get _rows {
    return Dummy.orders.where((o) {
      final chOk = _ch == 'all' || o.channel.name == _ch;
      final stOk = _st == 'all' || o.status.name == _st;
      return chOk && stOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Panel(
        title: 'รายการคำสั่งซื้อ',
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
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'success', child: Text('Success')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Canceled')),
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
                    DataColumn(label: Text('Order No.')),
                    DataColumn(label: Text('Platform')),
                    DataColumn(label: Text('ลูกค้า')),
                    DataColumn(label: Text('วันที่')),
                    DataColumn(label: Text('ยอดรวม')),
                    DataColumn(label: Text('สถานะ')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: [
                    for (final o in _rows)
                      DataRow(
                        cells: [
                          DataCell(Text(o.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(ChannelLabel(channel: o.channel)),
                          DataCell(Text(o.customer)),
                          DataCell(Text(dtFmt.format(o.createdAt))),
                          DataCell(Text(baht.format(o.total), style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(orderPill(o.status)),
                          DataCell(TextButton(onPressed: () => context.go('/orders/${o.id}'), child: const Text('ดูรายละเอียด'))),
                        ],
                      ),
                  ],
              ),
            ),
            const SizedBox(height: 16),
            Pages(page: _page, total: 32, onTap: (p) => setState(() => _page = p)),
          ],
        ),
      ),
    );
  }
}
