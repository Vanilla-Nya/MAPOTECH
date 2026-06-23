import 'package:flutter/material.dart';

class MobileLayout extends StatelessWidget {
  final Widget child;
  final Widget? appBar;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const MobileLayout({
    super.key,
    required this.child,
    this.appBar,
    this.drawer,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFFDFDFC),
      drawer: drawer,
      appBar: appBar != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(60.0),
              child: appBar!,
            )
          : null,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: child,
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
