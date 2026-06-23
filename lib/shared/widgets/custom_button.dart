import 'package:flutter/material.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isSecondary;
  final IconData? icon;
  final double? width;
  final double height;
  final bool isGradient;
  final List<Color>? gradientColors;
  final Color? primaryColor;
  final Color? textColor;
  final Color? borderColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isSecondary = false,
    this.icon,
    this.width,
    this.height = 50.0,
    this.isGradient = false,
    this.gradientColors,
    this.primaryColor,
    this.textColor,
    this.borderColor,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final defaultPrimaryColor = widget.primaryColor ?? const Color(0xFF48C9B0);
    final defaultTextColor = widget.textColor ?? const Color(0xFF1B4F42);
    final defaultBorderColor = widget.borderColor ?? Colors.grey[300]!;

    Color buttonColor;
    Color buttonTextColor;
    Border? border;

    if (widget.isSecondary) {
      buttonColor = _isHovered ? Colors.grey[100]! : Colors.transparent;
      buttonTextColor = defaultTextColor;
      border = Border.all(color: defaultBorderColor, width: 1.5);
    } else {
      buttonColor = defaultPrimaryColor;
      buttonTextColor = widget.textColor ?? Colors.white;
    }

    final double scale = _isPressed ? 0.95 : (_isHovered ? 1.05 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.isGradient ? null : buttonColor,
              gradient: widget.isGradient
                  ? LinearGradient(
                      colors: widget.gradientColors ??
                          [const Color(0xFF48C9B0), const Color(0xFF1B4F42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: border,
              boxShadow: [
                if (!widget.isSecondary)
                  BoxShadow(
                    color: defaultPrimaryColor.withOpacity(_isHovered ? 0.35 : 0.2),
                    blurRadius: _isHovered ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: buttonTextColor, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text,
                  style: TextStyle(
                    color: buttonTextColor,
                    fontWeight: FontWeight.w800,
                    fontSize: widget.height * 0.32,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
