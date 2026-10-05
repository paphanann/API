import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/ui.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OrderStore.instance.loadOne(widget.id);
      if (ProductStore.instance.products.isEmpty) ProductStore.instance.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([OrderStore.instance, ProductStore.instance]),
      builder: (context, _) => _body(context, OrderStore.instance.byId(widget.id)),
    );
  }

  Widget _body(BuildContext context, Order? o) {
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
            SizedBox(width: 170, child: Text(k, style: const TextStyle(color: Pal.muted))),
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
              final wide = c.maxWidth >= 900;
              final left = Panel(
                expand: wide,
                title: 'ข้อมูลลูกค้า',
                child: Column(
                  children: [
                    kv('ชื่อลูกค้า', Text(o.customer, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('เบอร์โทร', Text(o.phone, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('ที่อยู่จัดส่ง', Text(o.address, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              final shipName = o.shipping.trim();
              final shipText = shipName.isEmpty || shipName == '-' ? 'ยังไม่ระบุ' : shipName;
              final right = Panel(
                expand: wide,
                title: 'ข้อมูลคำสั่งซื้อ',
                child: Column(
                  children: [
                    kv('Marketplace', ChannelLabel(channel: o.channel)),
                    kv('Order ID (Marketplace)', Text(o.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('วันที่สั่งซื้อ', Text(dtFmt.format(o.createdAt), style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('ช่องทางชำระเงิน', Text(o.payment.isEmpty || o.payment == '-' ? '-' : o.payment, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv('สถานะการจัดส่ง', Text(o.shippingStatus, style: const TextStyle(fontWeight: FontWeight.w600))),
                    kv(
                      'ขนส่ง',
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 18, color: Pal.muted),
                          const SizedBox(width: 6),
                          Text(shipText, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (!wide) {
                return Column(children: [left, const SizedBox(height: 16), right]);
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: left), const SizedBox(width: 16), Expanded(child: right)],
                ),
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
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 72,
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('รูป')),
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
                              DataCell(_thumb(_lineImage(o, l))),
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
                  child: Column(
                    children: [
                      _sumRow('ราคาสินค้า', o.itemsTotal),
                      _sumRow('ส่วนลด', o.discount),
                      _sumRow('ค่าส่ง', o.shippingFee),
                      const SizedBox(height: 8),
                      _sumRow('ยอดรวมทั้งสิ้น', o.total, emphasize: true),
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

Widget _sumRow(String label, double amount, {bool emphasize = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasize ? Pal.text : Pal.muted,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 120,
          child: Text(
            baht.format(amount),
            textAlign: TextAlign.right,
            style: emphasize
                ? const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Pal.primary)
                : const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

String _lineImage(Order o, OrderLine l) {
  final own = l.imageUrl.trim();
  if (own.isNotEmpty && own != '-') return own;
  final sku = l.sku.trim().toLowerCase();
  final name = l.name.trim().toLowerCase();
  for (final p in ProductStore.instance.products) {
    if (p.channel != o.channel) continue;
    if (p.sku.toLowerCase() == sku || p.displayId.toLowerCase() == sku) {
      if (p.imageUrl.isNotEmpty && p.imageUrl != '-') return p.imageUrl;
    }
    for (final v in p.variants) {
      if (v.sku.toLowerCase() == sku || v.modelId.toLowerCase() == sku) {
        if (v.imageUrl.isNotEmpty && v.imageUrl != '-') return v.imageUrl;
        if (p.imageUrl.isNotEmpty && p.imageUrl != '-') return p.imageUrl;
      }
    }
    if (name.isNotEmpty && p.name.toLowerCase() == name && p.imageUrl.isNotEmpty && p.imageUrl != '-') {
      return p.imageUrl;
    }
  }
  return '';
}

Widget _thumb(String url) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 44,
      height: 44,
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
