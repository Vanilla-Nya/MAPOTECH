import 'package:flutter/material.dart';

/// Types of entrance transitions supported by [AnimatedEntrance]
enum EntranceAnimationType {
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  scale,
  fade,
}

/// A premium entrance animation wrapper that animates its child on load.
/// Perfect for cascading/staggered visual elements in dashboard grids or page layouts.
class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final EntranceAnimationType type;
  final Duration duration;
  final Duration delay;
  final double offset;
  final Curve curve;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.type = EntranceAnimationType.slideUp,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.offset = 24.0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Slide offset settings
    Offset slideStart;
    switch (widget.type) {
      case EntranceAnimationType.slideUp:
        slideStart = Offset(0.0, widget.offset);
        break;
      case EntranceAnimationType.slideDown:
        slideStart = Offset(0.0, -widget.offset);
        break;
      case EntranceAnimationType.slideLeft:
        slideStart = Offset(widget.offset, 0.0);
        break;
      case EntranceAnimationType.slideRight:
        slideStart = Offset(-widget.offset, 0.0);
        break;
      default:
        slideStart = Offset.zero;
    }

    _slideAnimation = Tween<Offset>(
      begin: slideStart,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );

    // Scale animation starts at 0.92 for spring overshoot Curve.easeOutBack (SIWE-like)
    _scaleAnimation = Tween<double>(
      begin: widget.type == EntranceAnimationType.scale ? 0.92 : 1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.type == EntranceAnimationType.scale ? Curves.easeOutBack : widget.curve,
      ),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget result = child!;

        // Apply slide animation if appropriate
        if (widget.type == EntranceAnimationType.slideUp ||
            widget.type == EntranceAnimationType.slideDown ||
            widget.type == EntranceAnimationType.slideLeft ||
            widget.type == EntranceAnimationType.slideRight) {
          result = Transform.translate(
            offset: _slideAnimation.value,
            child: result,
          );
        }

        // Apply scale animation if appropriate
        if (widget.type == EntranceAnimationType.scale) {
          result = Transform.scale(
            scale: _scaleAnimation.value,
            child: result,
          );
        }

        // Apply fade animation
        result = Opacity(
          opacity: _opacityAnimation.value,
          child: result,
        );

        return result;
      },
      child: widget.child,
    );
  }
}

/// A premium custom dialog route that animates dialog entry with a springy SIWE-like scale & fade transition
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0xAA000000),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation1, animation2) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack, // Springy bounce overshoot curve
        ),
      );
      final opacityAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: opacityAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}
