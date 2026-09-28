import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../stores/stores.dart';

OverlayEntry? _toast;

Future<void> showSystemStatusSnack(BuildContext context, {bool reload = true}) async {
  if (reload) {
    await Future.wait([
      ShopStore.instance.load(),
      SyncLogStore.instance.load(),
    ]);
  }
  if (!context.mounted) return;
  _showSyncToast(context);
}

void _showSyncToast(BuildContext context) {
  _toast?.remove();
  _toast = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Pal.okBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 18, color: Pal.ok),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sync สำเร็จ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Pal.text)),
                    SizedBox(height: 2),
                    Text('อัปเดตข้อมูลเรียบร้อยแล้ว', style: TextStyle(fontSize: 12, color: Pal.muted)),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    entry.remove();
                    if (_toast == entry) _toast = null;
                  },
                  icon: const Icon(Icons.close_rounded, size: 18, color: Pal.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(entry);
  _toast = entry;
  Future<void>.delayed(const Duration(seconds: 4), () {
    if (_toast != entry) return;
    entry.remove();
    _toast = null;
  });
}
