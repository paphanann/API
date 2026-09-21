import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';

/// ข้อความสถานะที่หน้าบ้านอ่านได้ — ไม่โชว์ JSON
List<String> systemStatusLines({bool? autoSync}) {
  final shops = [for (final c in Channel.values) ShopStore.instance.byChannel(c)];
  final logs = [...SyncLogStore.instance.logs]..sort((a, b) => b.time.compareTo(a.time));
  final latest = logs.isEmpty ? null : logs.first;
  DateTime? lastSync = latest?.time;
  for (final s in shops) {
    if (s.lastSync != null && (lastSync == null || s.lastSync!.isAfter(lastSync))) {
      lastSync = s.lastSync;
    }
  }

  final statusText = latest == null
      ? '-'
      : latest.status == SyncStatus.success
          ? 'สำเร็จ'
          : latest.status == SyncStatus.error
              ? 'ผิดพลาด'
              : 'รอดำเนินการ';
  final noNew = latest != null &&
      latest.status == SyncStatus.success &&
      latest.orderCount == 0 &&
      latest.productCount == 0;

  return [
    'การเชื่อมต่อ',
    for (final s in shops) _connText(s),
    '',
    'Auto Sync: ${autoSync == null ? '-' : (autoSync ? 'เปิด' : 'ปิด')}',
    'Sync ล่าสุด: ${lastSync == null ? '-' : timeFmt.format(lastSync)}',
    'สถานะ: $statusText',
    if (noNew) 'ไม่มีข้อมูลใหม่',
  ];
}

String _connText(ShopConn s) {
  if (s.connected) return '${s.channel.label} เชื่อมต่อแล้ว';
  if (s.needsReauth) return '${s.channel.label} ต้องเชื่อมต่อใหม่';
  return '${s.channel.label} ยังไม่เชื่อมต่อ';
}

Future<void> showSystemStatusSnack(BuildContext context, {bool reload = true}) async {
  if (reload) {
    await Future.wait([
      ShopStore.instance.load(),
      SyncLogStore.instance.load(),
    ]);
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1F2937),
      duration: const Duration(seconds: 6),
      content: Text(systemStatusLines().join('\n')),
    ),
  );
}

class SyncStatusBody extends StatefulWidget {
  const SyncStatusBody({super.key, this.autoSync, this.onDark = false});

  final bool? autoSync;
  final bool onDark;

  @override
  State<SyncStatusBody> createState() => _SyncStatusBodyState();
}

class _SyncStatusBodyState extends State<SyncStatusBody> {
  bool? _auto;

  @override
  void initState() {
    super.initState();
    _auto = widget.autoSync;
    if (_auto == null) {
      Api.getSettings().then((s) {
        if (mounted) setState(() => _auto = s.autoSync);
      }).catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(covariant SyncStatusBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoSync != null) _auto = widget.autoSync;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.onDark ? Colors.white : Pal.text;
    final dim = widget.onDark ? Colors.white70 : Pal.muted;
    return ListenableBuilder(
      listenable: Listenable.merge([ShopStore.instance, SyncLogStore.instance]),
      builder: (context, _) {
        final lines = systemStatusLines(autoSync: _auto);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines.length; i++)
              if (lines[i].isEmpty)
                const SizedBox(height: 10)
              else
                Padding(
                  padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 4),
                  child: Text(
                    lines[i],
                    style: TextStyle(
                      fontSize: i == 0 ? 15 : 14,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
                      color: i == 0 ? fg : (lines[i] == 'ไม่มีข้อมูลใหม่' ? dim : fg),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
