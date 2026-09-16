import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../stores.dart';
import '../theme.dart';
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
    DashStore.instance.load();
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
                  if (c.maxWidth >= 1100) {
                    return Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  }
                  final w = c.maxWidth >= 640 ? (c.maxWidth - 16) / 2 : c.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final card in cards) SizedBox(width: w, child: card)],
                  );
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) {
                  final line = Panel(title: 'สรุปคำสั่งซื้อ 7 วันล่าสุด', child: SizedBox(height: 280, child: _Trend(d)));
                  final pie = Panel(title: 'สัดส่วนคำสั่งซื้อ', child: SizedBox(height: 280, child: _Share(d)));
                  if (c.maxWidth < 980) {
                    return Column(children: [line, const SizedBox(height: 16), pie]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: line),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: pie),
                    ],
                  );
                },
              ),
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
    final series = [d.shopeeWeek, d.tiktokWeek, d.lazadaWeek];
    final n = series.map((s) => s.length).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = [for (final s in series) ...s].fold<double>(0, (a, b) => a > b ? a : b);
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
        Expanded(
          child: n == 0
              ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)))
              : LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY < 10 ? 10 : maxY * 1.2,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(color: Pal.line, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 11, color: Pal.muted)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= d.weekLabels.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(d.weekLabels[i], style: const TextStyle(fontSize: 11, color: Pal.muted)),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => Pal.sidebar)),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < d.shopeeWeek.length; i++) FlSpot(i.toDouble(), d.shopeeWeek[i])],
                        isCurved: true,
                        color: Pal.shopee,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: Pal.shopee.withValues(alpha: 0.08)),
                      ),
                      LineChartBarData(
                        spots: [for (var i = 0; i < d.tiktokWeek.length; i++) FlSpot(i.toDouble(), d.tiktokWeek[i])],
                        isCurved: true,
                        color: Pal.tiktok,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: Pal.tiktok.withValues(alpha: 0.05)),
                      ),
                      LineChartBarData(
                        spots: [for (var i = 0; i < d.lazadaWeek.length; i++) FlSpot(i.toDouble(), d.lazadaWeek[i])],
                        isCurved: true,
                        color: Pal.lazada,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: Pal.lazada.withValues(alpha: 0.05)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
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
    ].where((e) => e.$1 > 0).toList();
    if (slices.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)));
    }
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 52,
              startDegreeOffset: -90,
              sections: [
                for (final e in slices)
                  PieChartSectionData(
                    value: e.$1,
                    color: e.$2,
                    title: '${e.$1.toStringAsFixed(0)}%',
                    radius: 42,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
        Column(
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
