import 'package:flutter/services.dart';

/// Formats a numeric value to a Indonesian Rupiah formatted string (dot separated).
/// Example: 1000000 -> 1.000.000
String formatPrice(num value) {
  return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
}

/// Parses a formatted price string containing dot separators back to a double.
/// Example: 1.000.000 -> 1000000.0
double parseFormattedPrice(String text) {
  final clean = text.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), '');
  return double.tryParse(clean) ?? 0.0;
}

/// A text input formatter that formats numerical input with dot separators as the user types.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Only allow digits
    final String cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final double val = double.tryParse(cleanText) ?? 0;
    final String formatted = formatPrice(val);

    // Calculate relative cursor position after formatting
    int cursorPosition = newValue.selection.end;
    int digitCountBeforeCursor = 0;
    for (int i = 0; i < cursorPosition && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitCountBeforeCursor++;
      }
    }

    int newCursorPosition = 0;
    int digitCount = 0;
    while (newCursorPosition < formatted.length && digitCount < digitCountBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[newCursorPosition])) {
        digitCount++;
      }
      newCursorPosition++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}
