import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/application/pasien_children_service.dart';
import '../domain/ai_chat_message.dart';
import 'ai_chat_provider.dart';
import 'widgets/message_bubble.dart';

class PasienAiAssistantView extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;

  const PasienAiAssistantView({super.key, this.onNavigate});

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
    final isEn = state.language == 'en';
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
                  primaryColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  isDark ? const Color(0xFF0F1318) : const Color(0xFFF8FAFC),
                  const Color(0xFF48C9B0).withValues(alpha: isDark ? 0.06 : 0.03),
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
                color: cardColor.withValues(alpha: 0.85),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
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
                                color: const Color(
                                  0xFF0F9D58,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(
                                    0xFF0F9D58,
                                  ).withValues(alpha: 0.3),
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
                          isEn
                              ? 'Ask symptoms, prescriptions, find doctors, clinics & pharmacies'
                              : 'Tanya gejala, info resep, cari dokter, klinik & apotek',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.6),
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
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    tooltip: isEn ? 'Reset Conversation' : 'Reset Percakapan',
                    onPressed: () {
                      ref.read(aiChatProvider.notifier).resetChat();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEn
                                ? 'Conversation has been reset.'
                                : 'Percakapan telah direset.',
                          ),
                          duration: const Duration(seconds: 1),
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
                    tooltip: isEn
                        ? 'Conversation History'
                        : 'Riwayat Percakapan',
                    onPressed: () => _showHistoryBottomSheet(context),
                  ),
                ],
              ),
            ),

            // Baris Seleksi & Indikator Data Pasien/Anak Terpilih untuk Prompt AI
            _buildActiveContextBar(
              context: context,
              activeChild: chatState.activeChildContext,
              primaryColor: primaryColor,
              textColor: textColor,
              cardColor: cardColor,
              borderColor: borderColor,
              isDark: isDark,
              isEn: isEn,
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
                      isEn,
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
              isEn,
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
    bool isEn,
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
              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.35),
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
                    ? const Color(0xFF141920).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(
                  color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isTyping)
                    _buildTypingIndicator(primaryColor, isDark, isEn)
                  else if (message != null)
                    _TypewriterText(
                      text: message.text,
                      style: GoogleFonts.outfit(
                        height: 1.6,
                        fontSize: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.95)
                            : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    )
                  else
                    Text(
                      isEn
                          ? "Connecting to MAPOTECH AI..."
                          : "Menghubungkan ke MAPOTECH AI...",
                      style: GoogleFonts.outfit(
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),

                  // Action Navigation Buttons
                  if (!isTyping &&
                      message != null &&
                      message.actions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildActionButtons(
                      context,
                      message.actions,
                      primaryColor,
                      isEn,
                    ),
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
                                isEn ? 'All Messages' : 'Semua Pesan',
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
            )
            .animate()
            .scale(begin: const Offset(0.98, 0.98))
            .fadeIn(duration: 350.ms),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    List<AIChatAction> actions,
    Color primaryColor,
    bool isEn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: primaryColor.withValues(alpha: 0.2),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                isEn
                    ? 'RECOMMENDED ACTIONS & NAVIGATION'
                    : 'REKOMENDASI MENU & AKSI',
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
                color: primaryColor.withValues(alpha: 0.2),
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

  Widget _buildTypingIndicator(Color primaryColor, bool isDark, bool isEn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy_rounded, size: 16, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            isEn
                ? 'MAPOTECH AI is typing...'
                : 'MAPOTECH AI sedang mengetik...',
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
    bool isEn,
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
                        ? primaryColor.withValues(alpha: 0.12)
                        : primaryColor.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: primaryColor.withValues(alpha: 0.25),
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
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
                      hintText: isEn
                          ? 'Ask symptoms, medications, or find healthcare facilities...'
                          : 'Tanyakan gejala, obat, atau cari fasilitas kesehatan...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.4),
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
                          ? textColor.withValues(alpha: 0.1)
                          : primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: _messageController.text.trim().isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: _messageController.text.trim().isEmpty
                          ? textColor.withValues(alpha: 0.4)
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
    final isEn = state.language == 'en';
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
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
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
                  color: textColor.withValues(alpha: 0.2),
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
                        const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          isEn ? 'AI Chat History' : 'Riwayat Chat AI',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isEn
                          ? '${messages.length} message${messages.length == 1 ? '' : 's'}'
                          : '${messages.length} pesan',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.6),
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

  // ───────────────────────────────────────────────────────────────────────────
  // Active User / Child Context Selector Bar for AI Prompt
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildActiveContextBar({
    required BuildContext context,
    required ActiveChildContext? activeChild,
    required Color primaryColor,
    required Color textColor,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
    required bool isEn,
  }) {
    if (activeChild != null) {
      final isAllFamily = activeChild.childId == 'all_family_kk' ||
          activeChild.childName.toLowerCase().contains('semua anggota keluarga') ||
          activeChild.childName.toLowerCase().contains('entire family');

      final contextIcon = isAllFamily
          ? Icons.family_restroom_rounded
          : (activeChild.isSelf ? Icons.person_rounded : Icons.child_care_rounded);

      final contextColor = isAllFamily
          ? const Color(0xFF9B59B6)
          : (activeChild.isSelf ? const Color(0xFF3498DB) : const Color(0xFF1ABC9C));

      return Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: contextColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: contextColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: contextColor.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: contextColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                contextIcon,
                size: 20,
                color: contextColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: contextColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAllFamily
                                  ? (isEn ? 'ALL FAMILY CONTEXT' : 'KONTEKS 1 KK LENGKAP')
                                  : (isEn ? 'ACTIVE PROMPT CONTEXT' : 'KONTEKS DATA TERPILIH'),
                              style: GoogleFonts.outfit(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          activeChild.childName,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildContextChip(activeChild.age, textColor, isDark),
                      _buildContextChip(
                        'BB: ${activeChild.bb}',
                        textColor,
                        isDark,
                      ),
                      _buildContextChip(
                        'TB: ${activeChild.tb}',
                        textColor,
                        isDark,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF27AE60).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          activeChild.statusGizi,
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF27AE60),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Switch Child / Clear Context Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1ABC9C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showSelectChildDialog(context),
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: Color(0xFF1ABC9C),
                  ),
                  label: Text(
                    isEn
                        ? 'Switch'
                        : (activeChild.isSelf ? 'Ganti Profil' : 'Ganti Pasien'),
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1ABC9C),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: textColor.withValues(alpha: 0.6),
                  tooltip: isEn ? 'Clear context' : 'Lepas konteks pasien',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    final user = ref.read(landingPageProvider).loggedInUser;
                    final ownerName = (user?['name'] as String?) ??
                        (user?['nama_lengkap'] as String?);
                    ref
                        .read(aiChatProvider.notifier)
                        .clearActiveChild(accountOwnerName: ownerName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEn
                              ? 'Patient context cleared. General assistant mode active.'
                              : 'Konteks pasien dinonaktifkan. Mode AI umum aktif.',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: isDark ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.child_care_rounded, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEn
                  ? 'Consulting for child nutrition? Select child profile to attach medical records to prompt.'
                  : 'Konsultasi gizi balita? Pilih data anak agar prompt AI otomatis membaca rekam medisnya.',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: primaryColor,
            ),
            onPressed: () => _showSelectChildDialog(context),
            icon: const Icon(Icons.add_rounded, size: 14),
            label: Text(
              isEn ? 'Select Child' : 'Pilih Data Anak',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextChip(String text, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          color: textColor.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSelectChildDialog(BuildContext context) {
    final notifier = ref.read(landingPageProvider.notifier);
    final user = ref.read(landingPageProvider).loggedInUser;
    final isEn = ref.read(landingPageProvider).language == 'en';
    final cardBgColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final textColor = notifier.getTextColor();
    final primaryColor = notifier.getPrimaryColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selfContext = user != null
        ? PasienChildrenService.createSelfContext(user, isEn: isEn)
        : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 22,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Select Patient / Child for AI Context'
                          : 'Pilih Pasien / Anak untuk Konteks AI',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    Text(
                      isEn
                          ? 'Only members registered in your Family Card (KK) are displayed.'
                          : 'Hanya anggota yang terdaftar di Kartu Keluarga (KK) Anda yang ditampilkan.',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: FutureBuilder<List<PasienChildModel>>(
              future: PasienChildrenService.fetchFamilyChildrenForUser(user),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        const SizedBox(height: 14),
                        Text(
                          isEn
                              ? 'Checking registered family members...'
                              : 'Memeriksa data anggota keluarga terdaftar...',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final familyChildren = snapshot.data ?? [];

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 0. OPSI KONSULTASI SELURUH ANGGOTA KELUARGA (1 KK)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF9B59B6).withValues(alpha: 0.12),
                              const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF9B59B6).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            final allCtx = PasienChildrenService.createAllFamilyContext(
                              user,
                              familyChildren,
                              isEn: isEn,
                            );
                            final ownerName = (user?['name'] as String?) ??
                                (user?['nama_lengkap'] as String?) ??
                                (isEn ? 'Parent' : 'Bunda/Ayah');
                            ref.read(aiChatProvider.notifier).selectChildContext(
                                  childContext: allCtx,
                                  accountOwnerName: ownerName,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEn
                                      ? 'Active prompt context set to Entire Family (1 KK).'
                                      : 'Konteks prompt AI beralih ke Semua Anggota Keluarga (1 KK).',
                                ),
                                backgroundColor: const Color(0xFF9B59B6),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.family_restroom_rounded,
                                    size: 22,
                                    color: Color(0xFF9B59B6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              isEn
                                                  ? 'Entire Family (All Members)'
                                                  : 'Semua Anggota Keluarga (1 KK)',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isEn ? 'ALL' : 'SEMUA',
                                              style: GoogleFonts.outfit(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF9B59B6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isEn
                                            ? 'Holistic consultation covering maternal health, toddler nutrition, and whole household'
                                            : 'Konsultasi kesehatan holistik untuk Ayah, Ibu, Balita, dan seluruh anggota keluarga',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          color: textColor.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 1. Jika ADA anak yang terdaftar di keluarga
                      if (familyChildren.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            isEn
                                ? 'CHILDREN IN YOUR FAMILY (${familyChildren.length}):'
                                : 'ANAK TERDAFTAR DI KELUARGA (${familyChildren.length}):',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        ...familyChildren.map((c) {
                          final last = c.lastVisit;
                          final name = c.name;
                          final age = c.ageLabel;
                          final bb = '${last?.weightKg ?? 12.0} kg';
                          final tb = '${last?.heightCm ?? 85.0} cm';
                          final status =
                              last?.statusGizi ?? 'Gizi Baik (Normal)';
                          final plan =
                              last?.nutritionPlan ??
                              'Tingkatkan variasi protein hewani harian sesuai Buku KIA 2024.';
                          final faskes =
                              last?.examiner ?? 'Fasilitas Kesehatan Terdaftar';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                final childCtx = ActiveChildContext(
                                  childName: name,
                                  age: age,
                                  bb: bb,
                                  tb: tb,
                                  statusGizi: status,
                                  nutritionPlan: plan,
                                  childId: c.vitascaleProfile?.id ??
                                      c.familyMember['id']?.toString(),
                                  childNik: c.nik,
                                  isSelf: false,
                                );
                                final ownerName = (user?['name'] as String?) ??
                                    (user?['nama_lengkap'] as String?) ??
                                    (isEn ? 'Parent' : 'Bunda/Ayah');
                                ref
                                    .read(aiChatProvider.notifier)
                                    .selectChildContext(
                                      childContext: childCtx,
                                      accountOwnerName: ownerName,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEn
                                          ? 'Active prompt context set to $name.'
                                          : 'Konteks prompt AI berhasil dialihkan ke $name.',
                                    ),
                                    backgroundColor: primaryColor,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.child_care_rounded,
                                        size: 20,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF27AE60,
                                                  ).withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xFF27AE60,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$age • BB: $bb • TB: $tb',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              color: textColor.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            faskes,
                                            style: GoogleFonts.outfit(
                                              fontSize: 9.5,
                                              color: primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],

                      // 2. Jika BELUM ADA ANAK terdaftar di keluarga:
                      //    Tampilkan banner setup keluarga di profil ("need to setting up first to family")
                      if (familyChildren.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE67E22,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(
                                0xFFE67E22,
                              ).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFE67E22,
                                      ).withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.family_restroom_rounded,
                                      size: 18,
                                      color: Color(0xFFE67E22),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isEn
                                          ? 'No Children in Family Card'
                                          : 'Belum Ada Anak di Kartu Keluarga (KK)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFE67E22),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isEn
                                    ? 'To consult about child nutrition & growth with medical records, you need to set up your family members in Profile first.'
                                    : 'Untuk konsultasi gizi & tumbuh kembang anak beserta rekam medisnya, Anda perlu mendaftarkan anggota keluarga di menu Profil terlebih dahulu.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: textColor.withValues(alpha: 0.75),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    if (widget.onNavigate != null) {
                                      widget.onNavigate!('profile');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE67E22),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(
                                    Icons.settings_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    isEn
                                        ? 'Set Up Family in Profile'
                                        : 'Atur Keluarga di Profil',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 3. Pasien Akun Mandiri / Pengguna Itu Sendiri ("just only one")
                      if (selfContext != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            isEn
                                ? (familyChildren.isEmpty
                                      ? 'SELECT REGISTERED PATIENT (YOURSELF):'
                                      : 'OR SELECT YOUR OWN PROFILE:')
                                : (familyChildren.isEmpty
                                      ? 'PILIH PASIEN TERDAFTAR (DIRI SENDIRI):'
                                      : 'ATAU PILIH PROFIL ANDA SENDIRI:'),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              final ownerName = (user?['name'] as String?) ??
                                  (user?['nama_lengkap'] as String?) ??
                                  (isEn ? 'User' : 'Pengguna');
                              ref
                                  .read(aiChatProvider.notifier)
                                  .selectChildContext(
                                    childContext: selfContext,
                                    accountOwnerName: ownerName,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEn
                                        ? 'Active prompt context set to ${selfContext.childName}.'
                                        : 'Konteks prompt AI beralih ke ${selfContext.childName}.',
                                  ),
                                  backgroundColor: primaryColor,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF3498DB,
                                      ).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 20,
                                      color: Color(0xFF3498DB),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                selfContext.childName,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF3498DB,
                                                ).withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isEn ? 'Self' : 'Akun Saya',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(
                                                    0xFF3498DB,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${selfContext.age} • BB: ${selfContext.bb} • TB: ${selfContext.tb}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            color: textColor.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isEn
                                              ? 'General Patient Health & Consultation Mode'
                                              : 'Mode Konsultasi Kesehatan Umum Pasien',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            color: const Color(0xFF3498DB),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Color(0xFF3498DB),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isEn ? 'Cancel' : 'Batal',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        );
      },
    );
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
  Timer? _timer;

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _timer?.cancel();
    _displayedText = "";
    _currentIndex = 0;

    if (widget.text.isEmpty) return;

    // Smooth chunking: 3 characters every 18ms prevents frame thrashing and semantics dirty tree assertions
    const chunkSize = 3;
    _timer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentIndex < widget.text.length) {
        final nextIndex = (_currentIndex + chunkSize).clamp(
          0,
          widget.text.length,
        );
        setState(() {
          _currentIndex = nextIndex;
          _displayedText = widget.text.substring(0, _currentIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _skipToEnd() {
    if (_currentIndex < widget.text.length) {
      _timer?.cancel();
      setState(() {
        _currentIndex = widget.text.length;
        _displayedText = widget.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ExcludeSemantics completely protects the Flutter accessibility engine from rapid dirty tree states during typing,
    // while Semantics provides screen readers with the full text immediately.
    return GestureDetector(
      onTap: _skipToEnd,
      child: Semantics(
        label: widget.text,
        child: ExcludeSemantics(
          child: FormattedMarkdownText(
            text: _displayedText,
            style: widget.style,
            boldStyle: widget.style?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
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
              colors: [primary, primary.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
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
