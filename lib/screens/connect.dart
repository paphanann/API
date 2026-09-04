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
                Text('3. Set up system — ตั้งค่า Shop ID / Partner และโหมด API'),
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
    String mask(String raw) {
      if (raw == '-' || raw.length <= 8) return raw;
      const keep = 4;
      final star = raw.length - keep * 2;
      return '${raw.substring(0, keep)}${'*' * star}${raw.substring(raw.length - keep)}';
    }

    String when(DateTime? t) => t == null ? '-' : dtSec.format(t);

    Widget row(String k, String v, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color ?? Pal.text,
                ),
              ),
            ),
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
              Expanded(
                child: Text(s.channel.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          connPill(s.status),
          const SizedBox(height: 16),
          row('ร้านค้า', s.shop),
          row(s.idLabel, s.shopId),
          row('Partner ID', s.partnerId),
          row('โหมด API', s.mode),
          row('Access Token', mask(s.accessToken)),
          row('Refresh Token', mask(s.refreshToken)),
          row('เชื่อมต่อครั้งล่าสุด', when(s.lastConnected)),
          row('ซิงก์ข้อมูลล่าสุด', when(s.lastSync)),
          row('สถานะการเชื่อมต่อ', s.health, color: s.health == 'ปกติ' ? Pal.primary : null),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('ตั้งค่า ${s.channel.label}'),
                    content: Text(
                      s.status == ConnStatus.waiting
                          ? 'เริ่มต้นการเชื่อมต่อ API ของ ${s.channel.label}'
                          : 'จัดการ Token, Shop ID และโหมด API ของ ${s.channel.label}',
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
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('ตั้งค่า'),
            ),
          ),
        ],
      ),
    );
  }
}
