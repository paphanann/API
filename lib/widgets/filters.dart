import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';

enum DatePeriod { today, last7, last30, custom }

extension DatePeriodX on DatePeriod {
  String get label {
    switch (this) {
      case DatePeriod.today:
        return 'วันนี้';
      case DatePeriod.last7:
        return '7 วันล่าสุด';
      case DatePeriod.last30:
        return '30 วันล่าสุด';
      case DatePeriod.custom:
        return 'กำหนดเอง';
    }
  }
}

(DateTime from, DateTime to) rangeOfPeriod(DatePeriod period) {
  final today = dateOnly(DateTime.now());
  switch (period) {
    case DatePeriod.today:
      return (today, today);
    case DatePeriod.last7:
      return (today.subtract(const Duration(days: 6)), today);
    case DatePeriod.last30:
      return (today.subtract(const Duration(days: 29)), today);
    case DatePeriod.custom:
      return (today.subtract(const Duration(days: 29)), today);
  }
}

DatePeriod periodOfRange(DateTime? from, DateTime? to) {
  if (from == null || to == null) return DatePeriod.custom;
  final today = dateOnly(DateTime.now());
  final f = dateOnly(from);
  final t = dateOnly(to);
  if (t != today) return DatePeriod.custom;
  if (f == today) return DatePeriod.today;
  if (f == today.subtract(const Duration(days: 6))) return DatePeriod.last7;
  if (f == today.subtract(const Duration(days: 29))) return DatePeriod.last30;
  return DatePeriod.custom;
}

class PeriodField extends StatelessWidget {
  const PeriodField({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 160,
  });

  final DatePeriod value;
  final ValueChanged<DatePeriod> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Drop<DatePeriod>(
      label: 'ช่วงเวลา',
      value: value,
      width: width,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: [
        for (final p in DatePeriod.values) DropdownMenuItem(value: p, child: Text(p.label)),
      ],
    );
  }
}

class DateRangeField extends StatelessWidget {
  const DateRangeField({
    super.key,
    required this.from,
    required this.to,
    required this.onTap,
    this.width = 268,
    this.label = 'ช่วงวันที่',
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;
  final double width;
  final String label;

  @override
  Widget build(BuildContext context) {
    final has = from != null && to != null;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32),
                contentPadding: EdgeInsets.fromLTRB(8, 8, 12, 8),
              ),
              child: Text(
                !has
                    ? 'ทั้งหมด'
                    : dateOnly(from!) == dateOnly(to!)
                        ? dayFmt.format(from!)
                        : '${dayFmt.format(from!)} - ${dayFmt.format(to!)}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: has ? null : Pal.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Drop<T> extends StatelessWidget {
  const Drop({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            key: ValueKey('$label-$value-${items.length}'),
            initialValue: items.any((e) => e.value == value) ? value : null,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckOption {
  const CheckOption(this.value, this.label);

  final String value;
  final String label;
}

/// เมนูช่องติ๊กที่เลือกได้หลายรายการ เมนูไม่ปิดตอนกดติ๊ก
class MultiDrop extends StatelessWidget {
  const MultiDrop({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.width = 180,
    this.allValue = 'all',
  });

  final String label;
  final Set<String> selected;
  final List<CheckOption> options;
  final ValueChanged<Set<String>> onChanged;
  final double width;
  final String allValue;

  String get _summary {
    final picked = [
      for (final option in options)
        if (option.value != allValue && selected.contains(option.value)) option.label,
    ];
    if (picked.isEmpty) {
      for (final option in options) {
        if (option.value == allValue) return option.label;
      }
      return 'ทั้งหมด';
    }
    return picked.join(', ');
  }

  bool _on(CheckOption option) => option.value == allValue ? selected.isEmpty : selected.contains(option.value);

  void _toggle(CheckOption option) {
    if (option.value == allValue) {
      onChanged({});
      return;
    }
    final next = {...selected};
    if (!next.add(option.value)) next.remove(option.value);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          MenuAnchor(
            crossAxisUnconstrained: false,
            alignmentOffset: const Offset(0, 4),
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
              elevation: const WidgetStatePropertyAll(8),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              minimumSize: WidgetStatePropertyAll(Size(width, 0)),
              maximumSize: WidgetStatePropertyAll(Size(width, 320)),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
            ),
            menuChildren: [
              for (final option in options)
                MenuItemButton(
                  closeOnActivate: false,
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                    minimumSize: WidgetStatePropertyAll(Size(width, 36)),
                    overlayColor: WidgetStatePropertyAll(Pal.primary.withValues(alpha: 0.06)),
                  ),
                  onPressed: () => _toggle(option),
                  child: Row(
                    children: [
                      IgnorePointer(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: _on(option),
                            onChanged: (_) {},
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: Pal.text),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            builder: (context, controller, child) {
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => controller.isOpen ? controller.close() : controller.open(),
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                    suffixIcon: Icon(controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Pal.muted),
                    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24),
                  ),
                  child: Text(_summary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class Pages extends StatelessWidget {
  const Pages({super.key, required this.page, required this.total, required this.onTap});

  final int page;
  final int total;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final shown = <int>[];
    for (var i = 1; i <= total && i <= 5; i++) {
      shown.add(i);
    }

    Widget btn(Widget child, VoidCallback? tap, {bool on = false}) {
      return Material(
        color: on ? Pal.primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: on ? Pal.primary : Pal.line),
        ),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 34, height: 34, child: Center(child: child)),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        btn(Icon(Icons.chevron_left, size: 18, color: page > 1 ? Pal.text : Pal.faint), page > 1 ? () => onTap(page - 1) : null),
        const SizedBox(width: 6),
        for (final n in shown) ...[
          btn(
            Text('$n', style: TextStyle(color: n == page ? Colors.white : Pal.text, fontWeight: FontWeight.w600, fontSize: 13)),
            () => onTap(n),
            on: n == page,
          ),
          const SizedBox(width: 6),
        ],
        if (total > 5) ...[
          const Text('…', style: TextStyle(color: Pal.muted)),
          const SizedBox(width: 6),
          btn(Text('$total', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), () => onTap(total)),
          const SizedBox(width: 6),
        ],
        btn(Icon(Icons.chevron_right, size: 18, color: page < total ? Pal.text : Pal.faint), page < total ? () => onTap(page + 1) : null),
      ],
    );
  }
}

const tableHead = TextStyle(fontWeight: FontWeight.w700, color: Pal.muted, fontSize: 13);
const tableHeadBg = WidgetStatePropertyAll(Color(0xFFF8FAFC));
