import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../widgets/ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _ch = 'all';
  String _st = 'all';

  @override
  void initState() {
    super.initState();
    OrderStore.instance.load();
  }

  Future<void> _search() async {
    final platform = _ch == 'all' ? null : Channel.values.byName(_ch).apiPlatform;
    await OrderStore.instance.load(platform: platform);
  }

  List<Order> _rows() {
    return OrderStore.instance.orders.where((o) {
      final chOk = _ch == 'all' || o.channel.name == _ch;
      final stOk = _st == 'all' || o.status.name == _st;
      return chOk && stOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OrderStore.instance,
      builder: (context, _) {
        final store = OrderStore.instance;
        final rows = _rows();
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
                        onPressed: store.loading ? null : _search,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('ค้นหา'),
                      ),
                    ),
                  ],
                ),
                if (store.error != null) ...[
                  const SizedBox(height: 12),
                  Text(store.error!, style: const TextStyle(color: Color(0xFFDC2626))),
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
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('Order No.')),
                      DataColumn(label: Text('Platform')),
                      DataColumn(label: Text('ลูกค้า')),
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
                            DataCell(Text(o.customer)),
                            DataCell(Text(dtFmt.format(o.createdAt))),
                            DataCell(Text(baht.format(o.total), style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(orderPill(o.status)),
                            DataCell(Text(o.sapDocNum ?? '-')),
                            DataCell(TextButton(onPressed: () => context.go('/orders/${o.id}'), child: const Text('ดูรายละเอียด'))),
                          ],
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty && !store.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('ไม่พบคำสั่งซื้อ')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
