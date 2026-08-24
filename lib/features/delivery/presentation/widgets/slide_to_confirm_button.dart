import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Horizontal slide-to-confirm control for irreversible delivery actions.
class SlideToConfirmButton extends StatefulWidget {
  const SlideToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.loading = false,
    this.height = 56,
    this.backgroundColor,
    this.foregroundColor,
    this.thumbColor,
    this.thumbIconColor,
  });

  final String label;
  final VoidCallback? onConfirmed;
  final bool enabled;
  final bool loading;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? thumbColor;
  final Color? thumbIconColor;

  @override
  State<SlideToConfirmButton> createState() => _SlideToConfirmButtonState();
}

class _SlideToConfirmButtonState extends State<SlideToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  double _snapFrom = 0;
  late final AnimationController _reset;

  static const double _thumbPad = 4;
  static const double _completeFraction = 0.82;

  bool get _interactive =>
      widget.enabled && !widget.loading && widget.onConfirmed != null;

  @override
  void initState() {
    super.initState();
    _reset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _dx = _snapFrom * (1 - Curves.easeOut.transform(_reset.value));
        });
      });
  }

  @override
  void didUpdateWidget(SlideToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.loading && oldWidget.loading) {
      _dx = 0;
    }
  }

  @override
  void dispose() {
    _reset.dispose();
    super.dispose();
  }

  double _maxDx(double trackWidth) {
    final thumb = widget.height - _thumbPad * 2;
    return (trackWidth - thumb - _thumbPad * 2).clamp(0, double.infinity);
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDx) {
    if (!_interactive) return;
    if (_reset.isAnimating) _reset.stop();
    setState(() {
      _dx = (_dx + details.delta.dx).clamp(0, maxDx);
    });
  }

  void _onDragEnd(double maxDx) {
    if (!_interactive) return;
    if (maxDx > 0 && _dx / maxDx >= _completeFraction) {
      HapticFeedback.mediumImpact();
      setState(() => _dx = maxDx);
      widget.onConfirmed?.call();
      return;
    }
    _snapFrom = _dx;
    _reset.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Colors.orange.shade700;
    final fg = widget.foregroundColor ?? Colors.white;
    final thumb = widget.thumbColor ?? Colors.white;
    final iconColor = widget.thumbIconColor ?? Colors.orange.shade700;
    final active = _interactive;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxDx = _maxDx(width);
        final thumbSize = widget.height - _thumbPad * 2;
        final progress = maxDx == 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);

        return Opacity(
          opacity: active || widget.loading ? 1 : 0.45,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
            child: GestureDetector(
              onHorizontalDragUpdate: active
                  ? (d) => _onDragUpdate(d, maxDx)
                  : null,
              onHorizontalDragEnd: active ? (_) => _onDragEnd(maxDx) : null,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: thumbSize + 12),
                      child: Opacity(
                        opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                        child: Text(
                          widget.loading ? '' : widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _thumbPad + _dx,
                    top: _thumbPad,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: thumb,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: widget.loading
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: iconColor,
                              ),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: iconColor,
                              size: 28,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
