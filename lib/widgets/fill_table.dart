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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final parentW = widget.viewportWidth ?? (box.maxWidth.isFinite ? box.maxWidth : 0.0);
        final minW = parentW > widget.minWidth ? parentW : widget.minWidth;
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
                child: _HScrollBar(controller: _scroll, viewWidth: parentW <= 0 ? minW : parentW, contentWidth: minW),
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.hasClients) {
          return const SizedBox(height: 16);
        }
        final pos = controller.position;
        final fallback = (contentWidth - viewWidth).clamp(0.0, double.infinity);
        final max = pos.hasContentDimensions ? pos.maxScrollExtent : fallback;
        final offset = pos.hasPixels && max > 0 ? pos.pixels.clamp(0.0, max) : 0.0;
        return LayoutBuilder(
          builder: (context, bar) {
            final trackW = bar.maxWidth.isFinite ? bar.maxWidth : 0.0;
            if (trackW <= 0) return const SizedBox(height: 16);
            final ratio = contentWidth <= 0 ? 1.0 : (viewWidth / contentWidth).clamp(0.0, 1.0);
            final thumbW = (trackW * ratio).clamp(48.0, trackW);
            final travel = (trackW - thumbW).clamp(0.0, double.infinity);
            final thumbL = max == 0 ? 0.0 : travel * (offset / max);

            void jumpAt(double localX) {
              final x = (localX - thumbW / 2).clamp(0.0, travel);
              final next = travel == 0 ? 0.0 : max * (x / travel);
              if (controller.hasClients) controller.jumpTo(next);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) => jumpAt(e.localPosition.dx),
              onHorizontalDragUpdate: (e) => jumpAt(e.localPosition.dx),
              child: SizedBox(
                height: 16,
                width: trackW.isFinite ? trackW : 0,
                child: Stack(
                  clipBehavior: Clip.none,
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
                      width: thumbW.isFinite ? thumbW : 48,
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
      },
    );
  }
}
