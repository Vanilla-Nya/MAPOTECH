import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

class FloatingSettings extends ConsumerStatefulWidget {
  const FloatingSettings({super.key});

  @override
  ConsumerState<FloatingSettings> createState() => _FloatingSettingsState();
}

class _FloatingSettingsState extends ConsumerState<FloatingSettings>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final activeColor = notifier.getPrimaryColor();
    final cardColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final borderColor = notifier.getBorderColor();

    // Custom background and text styles for Floating Action Button
    Color mainBtnBg;
    Color mainBtnFg = Colors.white;

    if (_isOpen) {
      mainBtnBg = state.appearance == 'dark' ? Colors.white : Colors.black;
      mainBtnFg = state.appearance == 'dark' ? Colors.black : Colors.white;
    } else {
      if (state.appearance == 'rev') {
        mainBtnBg = activeColor; // Light purple
      } else if (state.appearance == 'dark') {
        mainBtnBg = const Color(0xFF48C9B0); // Teal
      } else {
        mainBtnBg = const Color(0xFF1B4F42); // Dark green
      }
    }

    return Positioned(
      right: 24,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Options Panel (Visible when _isOpen is true)
          AnimatedOpacity(
            opacity: _isOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: AnimatedSlide(
                offset: _isOpen ? Offset.zero : const Offset(0, 0.2),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: state.appearance == 'dark'
                        ? const Color(0xFF161616)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // --- LANGUAGE ROW ---
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildChipButton(
                            label: 'IND',
                            isSelected: state.language == 'id',
                            activeColor: activeColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            state: state,
                            onTap: () => notifier.setLanguage('id'),
                          ),
                          const SizedBox(width: 8),
                          _buildChipButton(
                            label: 'ENG',
                            isSelected: state.language == 'en',
                            activeColor: activeColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            state: state,
                            onTap: () => notifier.setLanguage('en'),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: state.appearance == 'rev'
                                  ? const Color(0xFFF3E8FF)
                                  : (state.appearance == 'dark'
                                      ? const Color(0xFF2D2D2D)
                                      : Colors.grey[100]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.translate_rounded,
                              size: 16,
                              color: state.appearance == 'rev'
                                  ? activeColor
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // --- THEME ROW ---
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Light Theme Button
                          _buildThemeButton(
                            icon: Icons.sunny,
                            isSelected: state.appearance == 'light',
                            activeColor: activeColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            state: state,
                            onTap: () => notifier.updateAppearance('light'),
                          ),
                          const SizedBox(width: 8),

                          // Dark Theme Button
                          _buildThemeButton(
                            icon: Icons.nightlight_round,
                            isSelected: state.appearance == 'dark',
                            activeColor: activeColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            state: state,
                            onTap: () => notifier.updateAppearance('dark'),
                          ),
                          const SizedBox(width: 8),

                          // REV Purple Theme Button
                          _buildThemeButton(
                            icon: Icons.palette_rounded,
                            isSelected: state.appearance == 'rev',
                            activeColor: activeColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            state: state,
                            onTap: () => notifier.updateAppearance('rev'),
                          ),
                          const SizedBox(width: 8),

                          // Header Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: state.appearance == 'rev'
                                  ? const Color(0xFFF3E8FF)
                                  : (state.appearance == 'dark'
                                      ? const Color(0xFF2D2D2D)
                                      : Colors.grey[100]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.brush_rounded,
                              size: 16,
                              color: state.appearance == 'rev'
                                  ? activeColor
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- MAIN TOGGLE BUTTON ---
          GestureDetector(
            onTap: _toggleMenu,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedScale(
                scale: _isOpen ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: mainBtnBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: mainBtnBg.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      _isOpen ? Icons.close_rounded : Icons.settings_rounded,
                      color: mainBtnFg,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required LandingPageState state,
    required VoidCallback onTap,
  }) {
    Color bg;
    Color fg;
    BorderSide border;

    if (isSelected) {
      if (state.appearance == 'rev') {
        bg = const Color(0xFFF3E8FF); // light violet
        fg = const Color(0xFF8B5CF6); // purple text
        border = const BorderSide(color: Color(0xFFE9D5FF));
      } else {
        bg = const Color(0xFF48C9B0); // teal background
        fg = Colors.white;
        border = const BorderSide(color: Color(0xFF48C9B0));
      }
    } else {
      bg = state.appearance == 'dark' ? const Color(0xFF222222) : Colors.white;
      fg = state.appearance == 'dark' ? Colors.grey[400]! : Colors.grey[600]!;
      border = BorderSide(color: borderColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(border),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: bg.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButton({
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required LandingPageState state,
    required VoidCallback onTap,
  }) {
    Color bg;
    Color fg;
    BorderSide border;

    if (isSelected) {
      if (state.appearance == 'rev') {
        bg = const Color(0xFFF3E8FF); // light purple
        fg = const Color(0xFF8B5CF6); // deep purple icon
        border = const BorderSide(color: Color(0xFFE9D5FF));
      } else {
        bg = const Color(0xFF48C9B0); // teal active
        fg = Colors.white;
        border = const BorderSide(color: Color(0xFF48C9B0));
      }
    } else {
      bg = state.appearance == 'dark' ? const Color(0xFF222222) : Colors.white;
      fg = state.appearance == 'dark' ? Colors.grey[400]! : Colors.grey[600]!;
      border = BorderSide(color: borderColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(border),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: bg.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: fg, size: 18),
      ),
    );
  }
}
