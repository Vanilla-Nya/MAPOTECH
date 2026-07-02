import 'package:flutter/material.dart';

/// A premium animated switcher that cross-fades pages seamlessly
/// (no blank frames or "blinks") while using [AnimatedSize] and a custom
/// positioning layout builder to prevent layout stutters or viewport jumps.
class AnimatedPortalSwitcher extends StatelessWidget {
  final Widget child;
  final String switcherKey;

  const AnimatedPortalSwitcher({
    super.key,
    required this.child,
    required this.switcherKey,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        reverseDuration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              // Render outgoing pages as Positioned so they don't affect the container height.
              // This allows AnimatedSize to capture the incoming page's height immediately and animate to it.
              ...previousChildren.map((oldChild) {
                return Positioned(top: 0, left: 0, right: 0, child: oldChild);
              }),
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isEntering = child.key == ValueKey(switcherKey);

          if (isEntering) {
            // Entering child: Slide up + Spring scale + Fade in
            final slideAnimation =
                Tween<Offset>(
                  begin: const Offset(0.0, 0.03),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
                  ),
                );

            final scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(
                  0.0,
                  1.0,
                  curve: Curves.easeOutBack,
                ), // Premium spring overshoot
              ),
            );

            final opacityAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
            );

            return FadeTransition(
              opacity: opacityAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: SlideTransition(position: slideAnimation, child: child),
              ),
            );
          } else {
            // Exiting child: Fade out and slide down slightly (no scale to prevent visual overlapping clutter)
            final slideAnimation =
                Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 1.0, curve: Curves.easeInCubic),
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slideAnimation, child: child),
            );
          }
        },
        child: KeyedSubtree(key: ValueKey(switcherKey), child: child),
      ),
    );
  }
}
