import 'package:flutter/material.dart';

class WebLayout extends StatelessWidget {
  final Widget child;
  final Widget? appBar;
  final Widget? footer;
  final Color? backgroundColor;
  final double maxContentWidth;

  const WebLayout({
    super.key,
    required this.child,
    this.appBar,
    this.footer,
    this.backgroundColor,
    this.maxContentWidth = 1200.0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFFDFDFC),
      appBar: appBar != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(80.0),
              child: appBar!,
            )
          : null,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
