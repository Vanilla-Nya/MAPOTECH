import 'package:flutter/material.dart';

class ViewportOverlay extends StatefulWidget {
  final bool show;
  final WidgetBuilder builder;

  const ViewportOverlay({
    super.key,
    required this.show,
    required this.builder,
  });

  @override
  State<ViewportOverlay> createState() => _ViewportOverlayState();
}

class _ViewportOverlayState extends State<ViewportOverlay> {
  final _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.show) {
          _controller.show();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ViewportOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.show) {
            _controller.show();
          } else {
            _controller.hide();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    if (_controller.isShowing) {
      _controller.hide();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) => widget.builder(context),
      child: const SizedBox.shrink(),
    );
  }
}
