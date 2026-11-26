import 'package:flutter/material.dart';

/// An ultra-premium widget that wraps any mockup/device visual,
/// applying interactive 3D perspective tilts on hover and a subtle
/// automatic floating 3D tilt animation when idle.
class ThreeDimensionalDeviceWrapper extends StatefulWidget {
  final Widget child;
  final bool animate;

  const ThreeDimensionalDeviceWrapper({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<ThreeDimensionalDeviceWrapper> createState() =>
      _ThreeDimensionalDeviceWrapperState();
}

class _ThreeDimensionalDeviceWrapperState
    extends State<ThreeDimensionalDeviceWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _hoverX = 0.0;
  double _hoverY = 0.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
    _animation = Tween<double>(
      begin: -0.015,
      end: 0.015,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _hoverX = 0.0;
        _hoverY = 0.0;
      }),
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final size = box.size;
        final localPos = box.globalToLocal(event.position);
        setState(() {
          // Normalize coordinates to range [-1.0, 1.0]
          _hoverX = (localPos.dx / size.width) * 2 - 1;
          _hoverY = (localPos.dy / size.height) * 2 - 1;
        });
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Subtle automatic float/tilt + mouse hover perspective feedback
          final double tiltX = _isHovered ? _hoverY * -0.15 : _animation.value;
          final double tiltY = _isHovered
              ? _hoverX * 0.15
              : -0.12 + _animation.value; // Elegant permanent 3D angle
          final double tiltZ = _isHovered ? _hoverX * _hoverY * 0.04 : -0.03;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: _isHovered ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, hoverProgress, child) {
              final shadowOffsetMultiplier = 1.0 + (hoverProgress * 0.5);
              final shadowBlurMultiplier = 1.0 + (hoverProgress * 0.6);

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0008) // premium low perspective distortion
                  ..rotateX(tiltX)
                  ..rotateY(tiltY)
                  ..rotateZ(tiltZ),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:
                          _isHovered ? 0.22 : 0.14,
                        ),
                        blurRadius: 36 * shadowBlurMultiplier,
                        offset: Offset(
                          _isHovered
                              ? _hoverX * -12
                              : -18 * shadowOffsetMultiplier,
                          _isHovered
                              ? _hoverY * 18
                              : 22 * shadowOffsetMultiplier,
                        ),
                      ),
                    ],
                  ),
                  child: widget.child,
                ),
              );
            },
            child: widget.child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
