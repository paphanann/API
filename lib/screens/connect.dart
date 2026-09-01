import 'package:flutter/material.dart';

import '../dummy.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth >= 1100
                  ? (c.maxWidth - 32) / 3
                  : c.maxWidth >= 720
                      ? (c.maxWidth - 16) / 2
                      : c.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [for (final s in Dummy.shops) SizedBox(width: w, child: _Card(s))],
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Pal.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สรุปขั้นตอนการเชื่อมต่อ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 10),
                Text('1. Authorize — อนุญาตสิทธิ์ร้านค้าบนแพลตฟอร์ม'),
                Text('2. Get Token — รับ Access Token จาก Open API'),
                Text('3. Set up system — ตั้งค่า Shop ID / Partner และโหมด Sandbox'),
                Text('4. Sync data — ดึงออเดอร์และส่งเข้า ERP/SAP'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.s);

  final ShopConn s;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChannelDot(channel: s.channel, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(s.channel.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 14),
          connPill(s.status),
          const SizedBox(height: 16),
          row('ร้านค้า', s.shop),
          row('Partner ID', s.partnerId),
          row('โหมด API', s.mode),
          row('ซิงก์ล่าสุด', s.lastSync == null ? '-' : dtFmt.format(s.lastSync!)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('ตั้งค่า ${s.channel.label}'),
                    content: Text(
                      s.status == ConnStatus.off
                          ? 'เริ่มต้นการเชื่อมต่อ API ของ ${s.channel.label}'
                          : 'จัดการ Token, Shop ID และโหมด Sandbox ของ ${s.channel.label}',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('บันทึก')),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Pal.primary,
                side: const BorderSide(color: Pal.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('ตั้งค่า'),
            ),
          ),
        ],
      ),
    );
  }
}
