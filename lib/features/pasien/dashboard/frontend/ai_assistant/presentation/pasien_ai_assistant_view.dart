import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import '../domain/ai_chat_message.dart';
import 'ai_chat_provider.dart';
import 'widgets/message_bubble.dart';

class PasienAiAssistantView extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;

  const PasienAiAssistantView({
    super.key,
    this.onNavigate,
  });

  @override
  ConsumerState<PasienAiAssistantView> createState() =>
      _PasienAiAssistantViewState();
}

class _PasienAiAssistantViewState extends ConsumerState<PasienAiAssistantView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(text);
    _messageController.clear();
    setState(() {});
  }

  void _handleQuickAction(String action) {
    _messageController.text = action;
    _handleSendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final chatState = ref.watch(aiChatProvider);

    final isDark = state.appearance == 'dark';
    final primaryColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();

    final messages = chatState.messages;
    final isTyping = chatState.isTyping;
    final quickActions = chatState.quickActions;

    // Find the latest AI message
    final latestAIMessage = messages
        .where((m) => m.sender == MessageSender.ai)
        .lastOrNull;

    return Stack(
      children: [
        // Background Ambient Glow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(isDark ? 0.08 : 0.04),
                  isDark ? const Color(0xFF0F1318) : const Color(0xFFF8FAFC),
                  const Color(0xFF48C9B0).withOpacity(isDark ? 0.06 : 0.03),
                ],
              ),
            ),
          ),
        ),

        // Main Content Column
        Column(
          children: [
            // Top App Bar / Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.85),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MAPOTECH AI ASSISTANT',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F9D58).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF0F9D58).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0F9D58),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Gemini 2.5 Flash',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F9D58),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tanya gejala, info resep, cari dokter, klinik & apotek',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Reset Chat button
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: textColor.withOpacity(0.7),
                    ),
                    tooltip: 'Reset Percakapan',
                    onPressed: () {
                      ref.read(aiChatProvider.notifier).resetChat();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Percakapan telah direset.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  // Chat History Modal button
                  IconButton(
                    icon: Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: primaryColor,
                    ),
                    tooltip: 'Riwayat Percakapan',
                    onPressed: () => _showHistoryBottomSheet(context),
                  ),
                ],
              ),
            ),

            // Top Section: Interactive Game Dialog Response Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildLatestAIResponse(
                      context,
                      latestAIMessage,
                      isTyping,
                      primaryColor,
                      textColor,
                      isDark,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Section: Quick prompts + Text Input Field
            _buildBottomArea(
              context,
              isTyping,
              quickActions,
              primaryColor,
              cardColor,
              textColor,
              borderColor,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLatestAIResponse(
    BuildContext context,
    AIChatMessage? message,
    bool isTyping,
    Color primaryColor,
    Color textColor,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stylized Name Tag (Honkai/Cyberpunk style)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'MAPOTECH AI',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ).animate().slideX(begin: -0.1, end: 0).fadeIn(duration: 300.ms),

        const SizedBox(height: 4),

        // Futuristic Glassmorphism Dialog Box
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 820),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141920).withOpacity(0.92)
                : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: primaryColor.withOpacity(isDark ? 0.35 : 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTyping)
                _buildTypingIndicator(primaryColor, isDark)
              else if (message != null)
                _TypewriterText(
                  text: message.text,
                  style: GoogleFonts.outfit(
                    height: 1.6,
                    fontSize: 16,
                    color: isDark
                        ? Colors.white.withOpacity(0.95)
                        : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                )
              else
                Text(
                  "Menghubungkan ke MAPOTECH AI...",
                  style: GoogleFonts.outfit(
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),

              // Action Navigation Buttons
              if (!isTyping && message != null && message.actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildActionButtons(context, message.actions, primaryColor),
              ],

              const SizedBox(height: 16),

              // Bottom row inside dialog: timestamp + history link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (message != null)
                    Text(
                      _formatDateTime(message.timestamp),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    )
                  else
                    const SizedBox(),
                  InkWell(
                    onTap: () => _showHistoryBottomSheet(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Semua Pesan',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(begin: const Offset(0.98, 0.98)).fadeIn(duration: 350.ms),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    List<AIChatAction> actions,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: primaryColor.withOpacity(0.2),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'REKOMENDASI MENU & AKSI',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: primaryColor,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: primaryColor.withOpacity(0.2),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.map((act) {
            return _AINavigationButton(
              action: act,
              onTap: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(act.menuId);
                }
              },
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypingIndicator(Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 16,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'MAPOTECH AI sedang mengetik...',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          _buildDot(0, primaryColor),
          _buildDot(1, primaryColor),
          _buildDot(2, primaryColor),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildDot(int index, Color primaryColor) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          duration: 500.ms,
          delay: (index * 160).ms,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.4, 1.4),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          duration: 500.ms,
          begin: const Offset(1.4, 1.4),
          end: const Offset(0.8, 0.8),
          curve: Curves.easeInOut,
        );
  }

  Widget _buildBottomArea(
    BuildContext context,
    bool isTyping,
    List<String> quickActions,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Action Suggestion Chips
          if (!isTyping)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickActions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final actionText = quickActions[index];
                  return ActionChip(
                    label: Text(
                      actionText,
                      style: GoogleFonts.outfit(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: isDark
                        ? primaryColor.withOpacity(0.12)
                        : primaryColor.withOpacity(0.08),
                    side: BorderSide(
                      color: primaryColor.withOpacity(0.25),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _handleQuickAction(actionText),
                  );
                },
              ),
            ).animate().fadeIn().slideX(begin: 0.05, end: 0),

          const SizedBox(height: 12),

          // Message Input Field
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Tanyakan gejala, obat, atau cari fasilitas kesehatan...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: textColor.withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                    ),
                    style: GoogleFonts.outfit(fontSize: 14, color: textColor),
                    onSubmitted: (_) => _handleSendMessage(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _handleSendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _messageController.text.trim().isEmpty
                          ? textColor.withOpacity(0.1)
                          : primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: _messageController.text.trim().isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: _messageController.text.trim().isEmpty
                          ? textColor.withOpacity(0.4)
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryBottomSheet(BuildContext context) {
    final messages = ref.read(aiChatProvider).messages;
    final state = ref.read(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isDark = state.appearance == 'dark';
    final cardColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Riwayat Chat AI',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${messages.length} pesan',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(
                      message: messages[index],
                      onNavigate: (menuId) {
                        Navigator.pop(context);
                        widget.onNavigate?.call(menuId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typewriter Text Effect Widget
// ─────────────────────────────────────────────────────────────────────────────
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _TypewriterText({required this.text, this.style});

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = "";
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant _TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _displayedText = "";
    _currentIndex = 0;
    _animate();
  }

  void _animate() async {
    if (!mounted) return;
    if (_currentIndex < widget.text.length) {
      setState(() {
        _displayedText += widget.text[_currentIndex];
        _currentIndex++;
      });
      Future.delayed(const Duration(milliseconds: 15), _animate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Action Navigation Button Widget
// ─────────────────────────────────────────────────────────────────────────────
class _AINavigationButton extends StatelessWidget {
  final AIChatAction action;
  final VoidCallback onTap;

  const _AINavigationButton({required this.action, required this.onTap});

  IconData _iconData() {
    switch (action.icon.toLowerCase()) {
      case 'history':
        return Icons.history_rounded;
      case 'medication':
      case 'receipt_long':
        return Icons.medication_rounded;
      case 'person_search':
        return Icons.person_search_rounded;
      case 'local_pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'domain':
      case 'business':
        return Icons.domain_rounded;
      case 'home_work':
        return Icons.home_work_rounded;
      case 'qr_code_scanner':
      case 'qr_scanner':
        return Icons.qr_code_scanner_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'dashboard':
        return Icons.dashboard_rounded;
      default:
        return Icons.arrow_forward_ios_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary,
                primary.withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconData(), color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 11,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
