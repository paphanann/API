import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../app/theme.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DashStore.instance.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DashStore.instance,
      builder: (context, _) {
        final store = DashStore.instance;
        final d = store.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (store.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Pal.errBg,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(store.error!, style: const TextStyle(color: Pal.err)),
                    ),
                  ),
                ),
              if (store.loading) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(minHeight: 3)),
              LayoutBuilder(
                builder: (context, c) {
                  final cards = [
                    StatCard(title: 'คำสั่งซื้อทั้งหมด', value: nFmt.format(d.totalOrders), icon: Icons.description_outlined, color: const Color(0xFF2563EB)),
                    StatCard(title: 'รอดำเนินการ', value: nFmt.format(d.pendingOrders), icon: Icons.lock_clock_outlined, color: const Color(0xFFF97316)),
                    StatCard(title: 'สำเร็จแล้ว', value: nFmt.format(d.successOrders), icon: Icons.check_circle_outline, color: Pal.ok),
                    StatCard(title: 'ช่องทางที่เชื่อมต่อ', value: '${d.connected}', icon: Icons.hub_outlined, color: const Color(0xFF0F172A), dark: true),
                  ];
                  final w = c.maxWidth.isFinite && c.maxWidth > 0
                      ? (c.maxWidth >= 640 ? (c.maxWidth - 16) / 2 : c.maxWidth)
                      : 320.0;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final card in cards) SizedBox(width: w, child: card)],
                  );
                },
              ),
              const SizedBox(height: 20),
              Panel(title: 'สรุปคำสั่งซื้อ 7 วันล่าสุด', child: SizedBox(height: 280, child: _Trend(d))),
              const SizedBox(height: 16),
              Panel(title: 'สัดส่วนคำสั่งซื้อ', child: SizedBox(height: 280, child: _Share(d))),
            ],
          ),
        );
      },
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend(this.d);

  final DashData d;

  @override
  Widget build(BuildContext context) {
    final series = <(List<double>, Color)>[
      (d.shopeeWeek, Pal.shopee),
      (d.tiktokWeek, Pal.tiktok),
      (d.lazadaWeek, Pal.lazada),
    ].where((s) => s.$1.isNotEmpty).toList();
    final values = [for (final s in series) ...s.$1].where((v) => v.isFinite);
    final peak = values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = peak < 10 ? 10.0 : peak * 1.2;
    return Column(
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _Dot(color: Pal.shopee, text: 'Shopee'),
            _Dot(color: Pal.tiktok, text: 'TikTok Shop'),
            _Dot(color: Pal.lazada, text: 'Lazada'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          width: double.infinity,
          child: series.isEmpty
              ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)))
              : CustomPaint(
                  painter: _TrendPainter(
                    labels: d.weekLabels,
                    series: series,
                    maxY: maxY,
                  ),
                ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.labels,
    required this.series,
    required this.maxY,
  });

  final List<String> labels;
  final List<(List<double>, Color)> series;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const bottom = 28.0;
    const top = 8.0;
    const right = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0 || !maxY.isFinite || maxY <= 0) return;

    final grid = Paint()
      ..color = Pal.line
      ..strokeWidth = 1;
    const rows = 4;
    for (var i = 0; i <= rows; i++) {
      final y = top + h * i / rows;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: (maxY * (1 - i / rows)).round().toString(),
          style: const TextStyle(fontSize: 11, color: Pal.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    final n = series.map((s) => s.$1.length).fold<int>(0, (a, b) => a > b ? a : b);
    if (n == 0) return;

    Offset at(int i, double raw) {
      final v = raw.isFinite ? raw.clamp(0, maxY) : 0.0;
      final x = n == 1 ? left + w / 2 : left + w * i / (n - 1);
      final y = top + h * (1 - v / maxY);
      return Offset(x, y);
    }

    for (final s in series) {
      if (s.$1.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < s.$1.length; i++) {
        final p = at(i, s.$1[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    final count = labels.isEmpty ? n : math.min(labels.length, n);
    for (var i = 0; i < count; i++) {
      final text = labels.isEmpty ? '${i + 1}' : labels[i];
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 11, color: Pal.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (n == 1 ? left + w / 2 : left + w * i / (n - 1)) - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0, size.width - tp.width), top + h + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.labels != labels || old.series != series || old.maxY != maxY;
}

class _Share extends StatelessWidget {
  const _Share(this.d);

  final DashData d;

  @override
  Widget build(BuildContext context) {
    final slices = <(double, Color, String)>[
      (d.shopeeShare, Pal.shopee, 'Shopee'),
      (d.tiktokShare, Pal.tiktok, 'TikTok Shop'),
      (d.lazadaShare, Pal.lazada, 'Lazada'),
    ].where((e) => e.$1.isFinite && e.$1 > 0).toList();
    if (slices.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)));
    }
    return Row(
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(painter: _PiePainter(slices)),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < slices.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _Dot(color: slices[i].$2, text: '${slices[i].$3}  ${slices[i].$1.toStringAsFixed(0)}%'),
            ],
          ],
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices);

  final List<(double, Color, String)> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    if (r < 8) return;
    final total = slices.fold<double>(0, (a, b) => a + b.$1);
    if (!total.isFinite || total <= 0) return;

    var start = -math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    for (final s in slices) {
      final sweep = (s.$1 / total) * 2 * math.pi;
      canvas.drawArc(rect, start, sweep - 0.02, true, Paint()..color = s.$2);
      start += sweep;
    }
    canvas.drawCircle(center, r * 0.55, Paint()..color = Colors.white);

    start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.$1 / total) * 2 * math.pi;
      if (sweep > 0.4) {
        final mid = start + sweep / 2;
        final labelR = r * 0.78;
        final tp = TextPainter(
          text: TextSpan(
            text: '${s.$1.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(center.dx + math.cos(mid) * labelR - tp.width / 2, center.dy + math.sin(mid) * labelR - tp.height / 2),
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.slices != slices;
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
