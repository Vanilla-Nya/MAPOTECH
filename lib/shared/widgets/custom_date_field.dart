import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standard custom date field picker matching MAPOTECH custom component style.
class CustomDateField extends StatelessWidget {
  final String? label;
  final String hintText;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final bool allowClear;
  final IconData prefixIcon;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final String? errorText;

  const CustomDateField({
    super.key,
    this.label,
    this.hintText = 'Pilih Tanggal',
    required this.selectedDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.allowClear = true,
    this.prefixIcon = Icons.calendar_today_rounded,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.errorText,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: firstDate ?? DateTime(1920),
      lastDate: lastDate ?? DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: isDark ? const Color(0xFF1E1E24) : Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

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
    final subCol = isDark ? const Color(0xFF8E8EA0) : const Color(0xFF6B7280);

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
        InkWell(
          onTap: enabled ? () => _pickDate(context) : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
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
                Icon(prefixIcon, size: 18, color: subCol),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedDate != null ? _formatDate(selectedDate!) : hintText,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: selectedDate != null ? FontWeight.w600 : FontWeight.w500,
                      color: selectedDate != null
                          ? textCol
                          : subCol.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                if (selectedDate != null && allowClear && enabled)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 16, color: subCol),
                    onPressed: () => onDateSelected(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
              ],
            ),
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
