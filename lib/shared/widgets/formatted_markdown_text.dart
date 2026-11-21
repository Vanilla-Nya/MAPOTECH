import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Komponen Custom UI untuk mem-parse dan merender teks Markdown (terutama **bold**, *italic*, list, dan header)
/// yang dihasilkan oleh model LLM (Gemini / MAPOTECH AI / VitaScale Reasoning)
/// agar tidak menampilkan teks mentah seperti tanda bintang ganda `**`.
class FormattedMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? boldStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool selectable;
  final Color? accentColor;

  const FormattedMarkdownText({
    super.key,
    required this.text,
    this.style,
    this.boldStyle,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.selectable = false,
    this.accentColor,
  });

  /// Helper untuk membersihkan tanda markdown mentah (** atau *) jika hanya butuh teks polos
  static String clean(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll('***', '')
        .replaceAll('**', '')
        .replaceAll('___', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[*•-]\s+', multiLine: true), '• ')
        .trim();
  }

  /// Membangun daftar InlineSpan dari teks markdown
  static List<InlineSpan> buildSpans(
    String rawText,
    TextStyle baseStyle, {
    TextStyle? boldStyle,
    Color? accentColor,
  }) {
    if (rawText.isEmpty) return const [];

    final spans = <InlineSpan>[];
    final lines = rawText.split('\n');

    final effectiveBoldStyle = boldStyle ??
        baseStyle.copyWith(
          fontWeight: FontWeight.w800,
          color: baseStyle.color,
        );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Baris kosong
      if (line.trim().isEmpty) {
        if (i < lines.length - 1) {
          spans.add(TextSpan(text: '\n\n', style: baseStyle));
        }
        continue;
      }

      // Deteksi Header Markdown: ### atau ## atau #
      if (line.startsWith('### ') || line.startsWith('## ') || line.startsWith('# ')) {
        final headingLevel = line.startsWith('### ')
            ? 3
            : (line.startsWith('## ') ? 2 : 1);
        final headingText = line.replaceFirst(RegExp(r'^#{1,3}\s+'), '');
        final headingFontSize = (baseStyle.fontSize ?? 14.0) + (headingLevel == 1 ? 4.0 : (headingLevel == 2 ? 2.5 : 1.5));

        spans.add(
          TextSpan(
            text: headingText,
            style: effectiveBoldStyle.copyWith(
              fontSize: headingFontSize,
              color: accentColor ?? baseStyle.color,
              height: 1.5,
            ),
          ),
        );
      }
      // Deteksi Bullet List (*, -, atau •)
      else if (RegExp(r'^\s*[*•-]\s+').hasMatch(line)) {
        final content = line.replaceFirst(RegExp(r'^\s*[*•-]\s+'), '');
        spans.add(
          TextSpan(
            text: '• ',
            style: effectiveBoldStyle.copyWith(
              color: accentColor ?? const Color(0xFF1ABC9C),
            ),
          ),
        );
        _parseInlineSpans(content, baseStyle, effectiveBoldStyle, spans);
      }
      // Deteksi Numbered List (misal: 1., 2.)
      else if (RegExp(r'^\s*\d+\.\s+').hasMatch(line)) {
        final match = RegExp(r'^\s*(\d+\.)\s+').firstMatch(line)!;
        final numPrefix = match.group(1)!;
        final content = line.substring(match.end);

        spans.add(
          TextSpan(
            text: '$numPrefix ',
            style: effectiveBoldStyle.copyWith(
              color: accentColor ?? const Color(0xFF1ABC9C),
            ),
          ),
        );
        _parseInlineSpans(content, baseStyle, effectiveBoldStyle, spans);
      }
      // Paragraf / Kalimat Biasa
      else {
        _parseInlineSpans(line, baseStyle, effectiveBoldStyle, spans);
      }

      // Tambahkan newline antar baris kecuali baris terakhir
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return spans;
  }

  /// Mem-parse formatting inline seperti **bold**, *italic*, dan `code`
  static void _parseInlineSpans(
    String line,
    TextStyle baseStyle,
    TextStyle boldStyle,
    List<InlineSpan> target,
  ) {
    // Tangani kemungkinan unclosed ** pada saat typewriter streaming berlangsung
    String safeLine = line;
    final doubleAsteriskCount = RegExp(r'\*\*').allMatches(safeLine).length;
    if (doubleAsteriskCount % 2 != 0) {
      safeLine = '$safeLine**'; // Otomatis menutup agar tidak bocor karakter mentah
    }

    // Pola regex untuk inline markdown:
    // Group 1: ***bold italic***
    // Group 2: **bold**
    // Group 3: *italic*
    // Group 4: `inline code`
    final regex = RegExp(
      r'(\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`)',
      dotAll: true,
    );

    int lastIndex = 0;
    for (final match in regex.allMatches(safeLine)) {
      if (match.start > lastIndex) {
        final plainSnippet = safeLine.substring(lastIndex, match.start).replaceAll('**', '');
        if (plainSnippet.isNotEmpty) {
          target.add(
            TextSpan(
              text: plainSnippet,
              style: baseStyle,
            ),
          );
        }
      }

      final fullMatch = match.group(0)!;
      if (fullMatch.startsWith('***') && fullMatch.endsWith('***')) {
        final content = match.group(2) ?? '';
        target.add(
          TextSpan(
            text: content,
            style: boldStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        final content = match.group(3) ?? '';
        target.add(
          TextSpan(
            text: content,
            style: boldStyle,
          ),
        );
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
        final content = match.group(4) ?? '';
        target.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        final content = match.group(5) ?? '';
        target.add(
          TextSpan(
            text: ' $content ',
            style: GoogleFonts.firaCode(
              fontSize: (baseStyle.fontSize ?? 13.0) * 0.9,
              color: boldStyle.color,
              backgroundColor: Colors.black.withOpacity(0.06),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < safeLine.length) {
      final trailingSnippet = safeLine.substring(lastIndex).replaceAll('**', '');
      if (trailingSnippet.isNotEmpty) {
        target.add(
          TextSpan(
            text: trailingSnippet,
            style: baseStyle,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? GoogleFonts.outfit(fontSize: 14, height: 1.5);
    final spans = buildSpans(
      text,
      effectiveStyle,
      boldStyle: boldStyle,
      accentColor: accentColor,
    );

    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
        maxLines: maxLines,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
