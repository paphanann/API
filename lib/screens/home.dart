import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../dummy.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final cards = [
                StatCard(title: 'คำสั่งซื้อทั้งหมด', value: nFmt.format(Dummy.totalOrders), icon: Icons.description_outlined, color: const Color(0xFF2563EB)),
                StatCard(title: 'รอดำเนินการ', value: nFmt.format(Dummy.pendingOrders), icon: Icons.lock_clock_outlined, color: const Color(0xFFF97316)),
                StatCard(title: 'สำเร็จแล้ว', value: nFmt.format(Dummy.successOrders), icon: Icons.check_circle_outline, color: Pal.ok),
                StatCard(title: 'ช่องทางที่เชื่อมต่อ', value: '${Dummy.connected}', icon: Icons.hub_outlined, color: const Color(0xFF0F172A), dark: true),
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
              const line = Panel(title: 'สรุปคำสั่งซื้อ 7 วันล่าสุด', child: SizedBox(height: 280, child: _Trend()));
              const pie = Panel(title: 'สัดส่วนคำสั่งซื้อ', child: SizedBox(height: 280, child: _Share()));
              if (c.maxWidth < 980) {
                return const Column(children: [line, SizedBox(height: 16), pie]);
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: line),
                  SizedBox(width: 16),
                  Expanded(flex: 2, child: pie),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            _Dot(color: Pal.shopee, text: 'Shopee'),
            SizedBox(width: 16),
            _Dot(color: Pal.tiktok, text: 'TikTok Shop'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 40,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 10,
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
                    interval: 10,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 11, color: Pal.muted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= Dummy.weekLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(Dummy.weekLabels[i], style: const TextStyle(fontSize: 11, color: Pal.muted)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => Pal.sidebar)),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < Dummy.shopeeWeek.length; i++) FlSpot(i.toDouble(), Dummy.shopeeWeek[i])],
                  isCurved: true,
                  color: Pal.shopee,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true, color: Pal.shopee.withValues(alpha: 0.08)),
                ),
                LineChartBarData(
                  spots: [for (var i = 0; i < Dummy.tiktokWeek.length; i++) FlSpot(i.toDouble(), Dummy.tiktokWeek[i])],
                  isCurved: true,
                  color: Pal.tiktok,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true, color: Pal.tiktok.withValues(alpha: 0.05)),
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
  const _Share();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 52,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(value: 60, color: Pal.shopee, title: '60%', radius: 42, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                PieChartSectionData(value: 40, color: Pal.tiktok, title: '40%', radius: 42, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Dot(color: Pal.shopee, text: 'Shopee  60%'),
            SizedBox(height: 12),
            _Dot(color: Pal.tiktok, text: 'TikTok Shop  40%'),
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
