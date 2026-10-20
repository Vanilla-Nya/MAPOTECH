import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Widget? customWidget;

  const CustomDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.customWidget,
  });
}

/// Standardized dropdown field component matching MAPOTECH custom input style.
class CustomDropdown<T> extends StatelessWidget {
  final String? label;
  final String hintText;
  final T? value;
  final List<CustomDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? prefix;
  final IconData? prefixIcon;
  final bool enabled;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? hintColor;
  final EdgeInsetsGeometry? contentPadding;
  final String? errorText;

  const CustomDropdown({
    super.key,
    this.label,
    this.hintText = 'Pilih salah satu...',
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefix,
    this.prefixIcon,
    this.enabled = true,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.hintColor,
    this.contentPadding,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = backgroundColor ??
        (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9FAFC));
    final defaultBorder = borderColor ??
        (isDark ? const Color(0xFF2E2E38) : const Color(0xFFE2E6ED));
    final textCol = textColor ??
        (isDark ? Colors.white : const Color(0xFF1A1A24));
    final subCol = hintColor ??
        (isDark ? const Color(0xFF8E8EA0) : const Color(0xFF6B7280));

    Widget? effectivePrefix;
    if (prefix != null) {
      effectivePrefix = prefix;
    } else if (prefixIcon != null) {
      effectivePrefix = Icon(prefixIcon, size: 18, color: subCol);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              label!,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textCol.withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
        Container(
          padding: contentPadding ??
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: defaultBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: errorText != null ? Colors.redAccent : defaultBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              if (effectivePrefix != null) ...[
                effectivePrefix,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      hintText,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: subCol.withValues(alpha: 0.65),
                      ),
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: subCol,
                      size: 20,
                    ),
                    dropdownColor: isDark ? const Color(0xFF22222A) : Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    ),
                    items: items.map((item) {
                      return DropdownMenuItem<T>(
                        value: item.value,
                        child: item.customWidget ??
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.icon != null) ...[
                                  Icon(item.icon, size: 16, color: subCol),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  item.label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textCol,
                                  ),
                                ),
                              ],
                            ),
                      );
                    }).toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6.0, top: 4.0),
            child: Text(
              errorText!,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
