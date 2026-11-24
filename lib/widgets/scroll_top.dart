import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Wraps a screen and floats a small "back to top" button over it once the
/// user has scrolled well down the main vertical list. Works with whatever
/// list is inside — it listens to scroll notifications instead of needing a
/// controller — and glides back up with an eased animation.
class ScrollTopOverlay extends StatefulWidget {
  final Widget child;
  final EdgeInsets margin;
  const ScrollTopOverlay({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(right: 16, bottom: 16),
  });

  @override
  State<ScrollTopOverlay> createState() => _ScrollTopOverlayState();
}

class _ScrollTopOverlayState extends State<ScrollTopOverlay> {
  bool _show = false;
  ScrollMetrics? _metrics;
  BuildContext? _scrollCtx;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _metrics = n.metrics;
    _scrollCtx = n.context;
    final show = n.metrics.pixels > 700;
    if (show != _show) setState(() => _show = show);
    return false;
  }

  void _toTop() {
    HapticFeedback.selectionClick();
    final ctx = _scrollCtx;
    if (ctx == null || !ctx.mounted) return;
    final pos = Scrollable.maybeOf(ctx)?.position;
    if (pos == null) return;
    final dist = (_metrics?.pixels ?? pos.pixels);
    final ms = (300 + dist / 8).clamp(300, 700).round();
    pos.animateTo(0, duration: Duration(milliseconds: ms), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: widget.margin.right,
            bottom: widget.margin.bottom,
            child: IgnorePointer(
              ignoring: !_show,
              child: AnimatedScale(
                scale: _show ? 1 : 0.6,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _show ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Material(
                    color: Surfaces.accent(dark),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toTop,
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(Icons.keyboard_arrow_up_rounded,
                            size: 24, color: Brand.deep),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
