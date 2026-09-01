import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dummy.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final o = Dummy.orderById(id);
    if (o == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ไม่พบคำสั่งซื้อ'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => context.go('/orders'), child: const Text('กลับไปรายการ')),
          ],
        ),
      );
    }

    Widget kv(String k, Widget v) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(k, style: const TextStyle(color: Pal.muted))),
            Expanded(child: v),
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
              IconButton(onPressed: () => context.go('/orders'), icon: const Icon(Icons.arrow_back_rounded)),
              Text(o.id, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              orderPill(o.status),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final left = Panel(
                title: 'ข้อมูลลูกค้า',
                child: Column(
                  children: [
                    kv('ชื่อลูกค้า', Text(o.customer, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('เบอร์โทร', Text(o.phone, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('ที่อยู่จัดส่ง', Text(o.address, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              final right = Panel(
                title: 'ข้อมูลคำสั่งซื้อ',
                child: Column(
                  children: [
                    kv('แพลตฟอร์ม', ChannelLabel(channel: o.channel)),
                    kv('วันเวลา', Text(dtFmt.format(o.createdAt), style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('ช่องทางชำระเงิน', Text(o.payment, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('ขนส่ง', Text(o.shipping, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (c.maxWidth < 900) {
                return Column(children: [left, const SizedBox(height: 16), right]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: left), const SizedBox(width: 16), Expanded(child: right)],
              );
            },
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'รายการสินค้า',
            pad: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FillTable(
                  child: DataTable(
                      headingRowColor: tableHeadBg,
                      headingTextStyle: tableHead,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 64,
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('สินค้า')),
                        DataColumn(label: Text('จำนวน')),
                        DataColumn(label: Text('ราคา/หน่วย')),
                        DataColumn(label: Text('รวม')),
                      ],
                      rows: [
                        for (final l in o.lines)
                          DataRow(
                            cells: [
                              DataCell(Text(l.sku)),
                              DataCell(Text(l.name)),
                              DataCell(Text('${l.qty}')),
                              DataCell(Text(baht.format(l.price))),
                              DataCell(Text(baht.format(l.amount), style: const TextStyle(fontWeight: FontWeight.w600))),
                            ],
                          ),
                      ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('ยอดรวมทั้งสิ้น', style: TextStyle(color: Pal.muted)),
                      const SizedBox(width: 24),
                      Text(baht.format(o.total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Pal.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
