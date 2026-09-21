import 'package:flutter/material.dart';

import '../app/theme.dart';

/// ผลเลือกปฏิทิน — null = ปิดโดยไม่เปลี่ยน, cleared = ล้างตัวกรอง
class CalendarPick {
  const CalendarPick.range(this.range) : cleared = false;
  const CalendarPick.clear() : range = null, cleared = true;

  final DateTimeRange? range;
  final bool cleared;
}

/// ปฏิทินช่วงวันที่ช่องเดียว — กดวันเริ่ม แล้วกดวันจบ มีพื้นหลังช่วงวันที่
Future<CalendarPick?> showSimpleCalendar({
  required BuildContext context,
  required DateTime from,
  required DateTime to,
}) {
  final first = DateTime(2020);
  final last = DateTime.now().add(const Duration(days: 365));
  var start = DateTime(from.year, from.month, from.day);
  var end = DateTime(to.year, to.month, to.day);
  var month = DateTime(start.year, start.month);
  var pickingEnd = false;

  String label(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  return showDialog<CalendarPick>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('เลือกวันที่', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        Text('${label(start)} - ${label(end)}', style: const TextStyle(color: Pal.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  _RangeMonthView(
                    month: month,
                    start: start,
                    end: end,
                    first: first,
                    last: last,
                    onPrev: () => setSt(() => month = DateTime(month.year, month.month - 1)),
                    onNext: () => setSt(() => month = DateTime(month.year, month.month + 1)),
                    onDay: (day) {
                      setSt(() {
                        if (!pickingEnd) {
                          start = day;
                          end = day;
                          pickingEnd = true;
                        } else {
                          if (day.isBefore(start)) {
                            end = start;
                            start = day;
                          } else {
                            end = day;
                          }
                          pickingEnd = false;
                        }
                        month = DateTime(day.year, day.month);
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, const CalendarPick.clear()),
                          child: const Text('ล้างตัวกรอง'),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, CalendarPick.range(DateTimeRange(start: start, end: end))),
                          child: const Text('ตกลง'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

const _thMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

class _RangeMonthView extends StatelessWidget {
  const _RangeMonthView({
    required this.month,
    required this.start,
    required this.end,
    required this.first,
    required this.last,
    required this.onDay,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final DateTime start;
  final DateTime end;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = firstOfMonth.weekday % 7; // อาทิตย์เป็นช่องแรก
    final today = _d(DateTime.now());
    final minMonth = DateTime(first.year, first.month);
    final maxMonth = DateTime(last.year, last.month);
    final canPrev = DateTime(month.year, month.month).isAfter(minMonth);
    final canNext = DateTime(month.year, month.month).isBefore(maxMonth);
    final rangeStart = start.isBefore(end) ? start : end;
    final rangeEnd = start.isBefore(end) ? end : start;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_thMonths[month.month - 1]} ${month.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              IconButton(
                onPressed: canPrev ? onPrev : null,
                icon: const Icon(Icons.chevron_left, size: 22),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: canNext ? onNext : null,
                icon: const Icon(Icons.chevron_right, size: 22),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'])
                Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < 6; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(row * 7 + col, lead, daysInMonth, today, rangeStart, rangeEnd)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int slot, int lead, int daysInMonth, DateTime today, DateTime rangeStart, DateTime rangeEnd) {
    final dayNum = slot - lead + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 40);
    }
    final day = DateTime(month.year, month.month, dayNum);
    final enabled = !day.isBefore(first) && !day.isAfter(last);
    final inRange = !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
    final isStart = day == rangeStart;
    final isEnd = day == rangeEnd;
    final isEdge = isStart || isEnd;
    final span = inRange && rangeStart != rangeEnd;

    return SizedBox(
      height: 40,
      child: InkWell(
        onTap: enabled ? () => onDay(day) : null,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (span)
              Container(
                height: 32,
                margin: EdgeInsets.only(left: isStart ? 18 : 0, right: isEnd ? 18 : 0),
                decoration: BoxDecoration(
                  color: Pal.primarySoft,
                  borderRadius: BorderRadius.horizontal(
                    left: isStart ? const Radius.circular(16) : Radius.zero,
                    right: isEnd ? const Radius.circular(16) : Radius.zero,
                  ),
                ),
              ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isEdge ? Pal.primary : null,
                shape: BoxShape.circle,
                border: !isEdge && day == today ? Border.all(color: Pal.primary) : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isEdge || day == today ? FontWeight.w700 : FontWeight.w500,
                  color: !enabled
                      ? Pal.faint
                      : isEdge
                          ? Colors.white
                          : Pal.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
