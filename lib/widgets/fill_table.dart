import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ตารางเลื่อนข้างได้ — มีแถบเลื่อนล่าง และลากด้วยเมาส์ได้บนเว็บ
class FillTable extends StatefulWidget {
  const FillTable({super.key, required this.child, this.minWidth = 0, this.viewportWidth});

  final Widget child;
  final double minWidth;
  final double? viewportWidth;

  @override
  State<FillTable> createState() => _FillTableState();
}

class _FillTableState extends State<FillTable> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final parentW = widget.viewportWidth ?? (box.maxWidth.isFinite ? box.maxWidth : 0.0);
        if (parentW <= 0) {
          return const IgnorePointer(child: SizedBox(width: 1, height: 1));
        }
        final minW = math.max(widget.minWidth, parentW);
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                primary: false,
                child: SizedBox(width: minW, child: widget.child),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: _HScrollBar(controller: _scroll, viewWidth: parentW, contentWidth: minW),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HScrollBar extends StatelessWidget {
  const _HScrollBar({
    required this.controller,
    required this.viewWidth,
    required this.contentWidth,
  });

  final ScrollController controller;
  final double viewWidth;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    if (viewWidth <= 0 || contentWidth <= 0) {
      return const IgnorePointer(child: SizedBox(height: 16));
    }
    if (!controller.hasClients) {
      return const IgnorePointer(child: SizedBox(height: 16));
    }
    final pos = controller.position;
        final fallback = (contentWidth - viewWidth).clamp(0.0, double.infinity).toDouble();
        final max = pos.hasContentDimensions ? pos.maxScrollExtent : fallback;
        final offset = pos.hasPixels && max > 0 ? pos.pixels.clamp(0.0, max).toDouble() : 0.0;
        return LayoutBuilder(
          builder: (context, bar) {
            final trackW = bar.maxWidth.isFinite ? bar.maxWidth : 0.0;
            if (trackW <= 0) {
              return const IgnorePointer(child: SizedBox(height: 16));
            }
            final ratio = (viewWidth / contentWidth).clamp(0.0, 1.0).toDouble();
            final rawThumb = trackW * ratio;
            final thumbW = rawThumb.clamp(math.min(24.0, trackW), trackW).toDouble();
            final travel = (trackW - thumbW).clamp(0.0, double.infinity).toDouble();
            final thumbL = max == 0 ? 0.0 : travel * (offset / max);

            void jumpAt(double localX) {
              final x = (localX - thumbW / 2).clamp(0.0, travel).toDouble();
              final next = travel == 0 ? 0.0 : max * (x / travel);
              if (controller.hasClients) controller.jumpTo(next);
            }

        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTapDown: (e) => jumpAt(e.localPosition.dx),
          onHorizontalDragUpdate: (e) => jumpAt(e.localPosition.dx),
          child: SizedBox(
            height: 16,
            width: trackW,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 4,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbL.isFinite ? thumbL : 0,
                  top: 3,
                  width: thumbW.isFinite ? thumbW : 24,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
