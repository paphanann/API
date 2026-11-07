import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
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

class LastSyncActions extends StatelessWidget {
  const LastSyncActions({
    super.key,
    required this.lastSync,
    required this.syncing,
    required this.onSync,
  });

  final DateTime? lastSync;
  final bool syncing;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        LastSyncLabel(lastSync: lastSync),
        const SizedBox(height: 6),
        LastSyncButton(syncing: syncing, onSync: onSync),
      ],
    );
  }
}

class LastSyncLabel extends StatelessWidget {
  const LastSyncLabel({super.key, required this.lastSync});

  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    return Text(
      lastSync == null ? 'Sync ล่าสุด : -' : 'Sync ล่าสุด : ${dtFmt.format(lastSync!)}',
      style: const TextStyle(color: Pal.muted, fontSize: 13),
    );
  }
}

class LastSyncButton extends StatelessWidget {
  const LastSyncButton({super.key, required this.syncing, required this.onSync});

  final bool syncing;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: syncing ? null : onSync,
        icon: syncing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync_rounded, size: 18),
        label: Text(syncing ? 'กำลัง Sync...' : 'Sync Now'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Pal.text,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Pal.line),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
    );
  }
}

DateTime? lastMarketplaceSyncAt() {
  DateTime? last;
  for (final s in ShopStore.instance.realShops) {
    final t = s.lastSync;
    if (t != null && (last == null || t.isAfter(last))) last = t;
  }
  for (final l in SyncLogStore.instance.logs) {
    if (l.status != SyncStatus.success && l.status != SyncStatus.partial) continue;
    if (last == null || l.time.isAfter(last)) last = l.time;
  }
  return last;
}

class TopBarLastSync extends StatelessWidget {
  const TopBarLastSync({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ShopStore.instance,
        SyncLogStore.instance,
      ]),
      builder: (context, _) => LastSyncLabel(lastSync: lastMarketplaceSyncAt()),
    );
  }
}

class HeaderSyncActions extends StatelessWidget {
  const HeaderSyncActions({super.key, this.onDone, this.showLabel = true});

  final Future<void> Function()? onDone;
  final bool showLabel;

  Future<void> _syncNow(BuildContext context) async {
    try {
      await MarketplaceSyncStore.instance.syncNow(force: false);
      await Future.wait([
        ShopStore.instance.load(),
        DashStore.instance.load(keepFilter: true),
      ]);
      if (onDone != null) await onDone!();
      if (!context.mounted) return;
      await showSystemStatusSnack(context, reload: false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MarketplaceSyncStore.instance,
        ShopStore.instance,
        SyncLogStore.instance,
      ]),
      builder: (context, _) {
        final syncing = MarketplaceSyncStore.instance.syncing;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LastSyncButton(syncing: syncing, onSync: syncing ? null : () => _syncNow(context)),
            if (showLabel) ...[
              const SizedBox(width: 12),
              LastSyncLabel(lastSync: lastMarketplaceSyncAt()),
            ],
          ],
        );
      },
    );
  }
}
