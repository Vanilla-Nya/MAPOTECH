import 'package:flutter/material.dart';

class EntityChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isSoon;
  final VoidCallback onTap;

  const EntityChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isSoon = false,
    required this.onTap,
  });

  @override
  State<EntityChip> createState() => _EntityChipState();
}

class _EntityChipState extends State<EntityChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final activeTextColor = Theme.of(context).colorScheme.secondary;
    final inactiveColor = Colors.grey[500]!;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : (_isHovered
                    ? activeColor.withOpacity(0.1)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.grey[300]!
                  : Colors.transparent,
              width: 1.0,
            ),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? activeTextColor : inactiveColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (widget.isSoon) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SOON',
                    style: TextStyle(
                      color: activeTextColor,
                      fontSize: 6,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
