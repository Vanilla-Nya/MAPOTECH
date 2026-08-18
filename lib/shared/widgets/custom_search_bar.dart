import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean, reusable search bar input field with search icon, clear button, and adaptive styling.
class CustomSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? iconColor;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText = 'Cari...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.hintColor,
    this.iconColor,
    this.height = 48.0,
    this.borderRadius = 14.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0),
    this.prefix,
    this.suffix,
    this.autofocus = false,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late TextEditingController _internalController;
  bool _isSelfManaged = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _internalController = widget.controller!;
      _hasText = _internalController.text.isNotEmpty;
    } else {
      _internalController = TextEditingController(text: widget.initialValue ?? '');
      _isSelfManaged = true;
      _hasText = _internalController.text.isNotEmpty;
    }
    _internalController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _internalController.text.isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() {
        _hasText = has;
      });
    }
  }

  @override
  void dispose() {
    _internalController.removeListener(_onTextChanged);
    if (_isSelfManaged) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD));
    final border = widget.borderColor ??
        (isDark ? const Color(0xFF2B2B30) : const Color(0xFFECEEF2));
    final textCol = widget.textColor ??
        (isDark ? Colors.white : const Color(0xFF1B0C3C));
    final subCol = widget.hintColor ??
        (isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A));
    final iconCol = widget.iconColor ?? subCol;

    return Container(
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          widget.prefix ??
              Icon(
                Icons.search_rounded,
                size: 18,
                color: iconCol,
              ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _internalController,
              autofocus: widget.autofocus,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subCol.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
          if (_hasText)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: subCol),
              onPressed: () {
                _internalController.clear();
                if (widget.onChanged != null) {
                  widget.onChanged!('');
                }
                if (widget.onClear != null) {
                  widget.onClear!();
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
          if (widget.suffix != null) widget.suffix!,
        ],
      ),
    );
  }
}
