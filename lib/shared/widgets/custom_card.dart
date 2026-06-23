import 'package:flutter/material.dart';

class CustomCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isGlassmorphic;
  final List<Color>? gradientColors;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const CustomCard({
    super.key,
    required this.child,
    this.onTap,
    this.isGlassmorphic = false,
    this.gradientColors,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(24.0),
    this.color,
    this.borderColor,
  });

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isHovered ? 1.03 : 1.0;
    final defaultBgColor = widget.color ?? Colors.white;
    final defaultBorderColor = widget.borderColor ?? Colors.grey[200]!;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.isGlassmorphic
                  ? defaultBgColor.withOpacity(0.85)
                  : (widget.gradientColors == null ? defaultBgColor : null),
              gradient: widget.gradientColors != null
                  ? LinearGradient(
                      colors: widget.gradientColors!,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: widget.isGlassmorphic
                    ? defaultBorderColor.withOpacity(0.4)
                    : defaultBorderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                  blurRadius: _isHovered ? 24 : 12,
                  offset: Offset(0, _isHovered ? 12 : 6),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
