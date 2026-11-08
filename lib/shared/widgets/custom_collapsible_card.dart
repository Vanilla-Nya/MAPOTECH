import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable Collapsible Card Widget for MAPOTECH.
/// 
/// Provides a unified, responsive expandable/collapsible container with smooth animations,
/// custom header, optional preview badge, and chevron indicator.
/// 
/// Adheres to Rule 1 (Custom UI Mandiri) and Rule 6 (Uniformity) of Rule.md.
class CustomCollapsibleCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? previewBadge;
  final String expandLabel;
  final String collapseLabel;
  final Color? cardBgColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? subtitleColor;
  final Color? accentColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry contentPadding;
  final ValueChanged<bool>? onExpansionChanged;

  const CustomCollapsibleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.child,
    this.initiallyExpanded = false,
    this.previewBadge,
    this.expandLabel = 'Buka Detail',
    this.collapseLabel = 'Tutup Detail',
    this.cardBgColor,
    this.borderColor,
    this.textColor,
    this.subtitleColor,
    this.accentColor,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(20.0),
    this.contentPadding = const EdgeInsets.only(top: 16.0),
    this.onExpansionChanged,
  });

  @override
  State<CustomCollapsibleCard> createState() => _CustomCollapsibleCardState();
}

class _CustomCollapsibleCardState extends State<CustomCollapsibleCard> {
  late bool _isExpanded;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant CustomCollapsibleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded &&
        widget.initiallyExpanded != _isExpanded) {
      setState(() {
        _isExpanded = widget.initiallyExpanded;
      });
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = widget.cardBgColor ?? (isDark ? const Color(0xFF1E1E26) : Colors.white);
    final defaultBorder = widget.borderColor ?? (isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0));
    final defaultText = widget.textColor ?? (isDark ? Colors.white : const Color(0xFF1E293B));
    final defaultSubtitle = widget.subtitleColor ?? (isDark ? Colors.grey[400]! : const Color(0xFF64748B));
    final accent = widget.accentColor ?? const Color(0xFF1ABC9C);
    final effectiveIconColor = widget.iconColor ?? accent;

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: _isHovered ? accent.withValues(alpha: 0.5) : defaultBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: _isHovered ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar (Clickable)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleExpansion,
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: effectiveIconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 20,
                          color: effectiveIconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: defaultText,
                                    letterSpacing: 0.4,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.previewBadge != null && !isMobile) ...[
                                const SizedBox(width: 10),
                                widget.previewBadge!,
                              ],
                            ],
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: defaultSubtitle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.previewBadge != null && isMobile) ...[
                      widget.previewBadge!,
                      const SizedBox(width: 6),
                    ],
                    // Action Pill Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isExpanded
                            ? accent.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF282836) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: _isExpanded
                              ? accent.withValues(alpha: 0.4)
                              : defaultBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMobile) ...[
                            Text(
                              _isExpanded ? widget.collapseLabel : widget.expandLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isExpanded ? accent : defaultSubtitle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: _isExpanded ? accent : defaultSubtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Animated Collapsible Content Body
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Padding(
                      padding: widget.contentPadding,
                      child: widget.child,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

