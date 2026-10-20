import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standard custom text input field for MAPOTECH applications.
/// Adheres to REV Mode palette and consistent border, typography, and focus states.
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefix;
  final IconData? prefixIcon;
  final Widget? suffix;
  final IconData? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool isPill;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? textColor;
  final Color? hintColor;
  final EdgeInsetsGeometry? contentPadding;

  const CustomTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefix,
    this.prefixIcon,
    this.suffix,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onTap,
    this.borderRadius = 12.0,
    this.isPill = false,
    this.backgroundColor,
    this.borderColor,
    this.focusedBorderColor,
    this.textColor,
    this.hintColor,
    this.contentPadding,
  });

  /// Factory for pill-shaped input (e.g. search or compact tags)
  factory CustomTextField.pill({
    Key? key,
    TextEditingController? controller,
    String? hintText,
    Widget? prefix,
    IconData? prefixIcon,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      hintText: hintText,
      prefix: prefix,
      prefixIcon: prefixIcon,
      suffix: suffix,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      isPill: true,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      textColor: textColor,
    );
  }

  /// Factory for multi-line textarea / catatan
  factory CustomTextField.multiline({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hintText,
    int maxLines = 4,
    int minLines = 3,
    ValueChanged<String>? onChanged,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      label: label,
      hintText: hintText,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      textColor: textColor,
      keyboardType: TextInputType.multiline,
    );
  }

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscured;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword || widget.obscureText;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final defaultBg = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9FAFC));
    final defaultBorder = widget.borderColor ??
        (isDark ? const Color(0xFF2E2E38) : const Color(0xFFE2E6ED));
    final activeBorder = widget.focusedBorderColor ?? primaryColor;
    final textCol = widget.textColor ??
        (isDark ? Colors.white : const Color(0xFF1A1A24));
    final subCol = widget.hintColor ??
        (isDark ? const Color(0xFF8E8EA0) : const Color(0xFF6B7280));

    final actualRadius = widget.isPill ? 100.0 : widget.borderRadius;

    Widget? effectiveSuffix;
    if (widget.isPassword) {
      effectiveSuffix = IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
          color: subCol,
        ),
        onPressed: () {
          setState(() {
            _obscured = !_obscured;
          });
        },
        splashRadius: 18,
        tooltip: _obscured ? 'Tampilkan sandi' : 'Sembunyikan sandi',
      );
    } else if (widget.suffix != null) {
      effectiveSuffix = widget.suffix;
    } else if (widget.suffixIcon != null) {
      effectiveSuffix = Icon(widget.suffixIcon, size: 18, color: subCol);
    }

    Widget? effectivePrefix;
    if (widget.prefix != null) {
      effectivePrefix = widget.prefix;
    } else if (widget.prefixIcon != null) {
      effectivePrefix = Icon(widget.prefixIcon, size: 18, color: subCol);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              widget.label!,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _isFocused ? activeBorder : textCol.withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: defaultBg,
            borderRadius: BorderRadius.circular(actualRadius),
            border: Border.all(
              color: widget.errorText != null
                  ? Colors.redAccent
                  : (_isFocused ? activeBorder : defaultBorder),
              width: _isFocused ? 1.8 : 1.2,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: activeBorder.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            initialValue: widget.initialValue,
            focusNode: _focusNode,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            inputFormatters: widget.inputFormatters,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.enabled ? textCol : textCol.withValues(alpha: 0.5),
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subCol.withValues(alpha: 0.65),
              ),
              prefixIcon: effectivePrefix != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: effectivePrefix,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: effectiveSuffix != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: effectiveSuffix,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              border: InputBorder.none,
              contentPadding: widget.contentPadding ??
                  EdgeInsets.symmetric(
                    horizontal: widget.isPill ? 18.0 : 14.0,
                    vertical: widget.maxLines > 1 ? 14.0 : 12.0,
                  ),
              isDense: true,
              counterText: '',
            ),
          ),
        ),
        if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6.0, top: 4.0),
            child: Text(
              widget.errorText!,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ] else if (widget.helperText != null && widget.helperText!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6.0, top: 4.0),
            child: Text(
              widget.helperText!,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subCol,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
