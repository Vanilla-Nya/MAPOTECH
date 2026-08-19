import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/ai_chat_message.dart';

class MessageBubble extends StatelessWidget {
  final AIChatMessage message;
  final Function(String menuId)? onNavigate;

  const MessageBubble({
    super.key,
    required this.message,
    this.onNavigate,
  });

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
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
    final isUser = message.sender == MessageSender.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(context, isUser, theme),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender label
                Text(
                  isUser ? 'Anda' : 'MAPOTECH AI',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUser
                        ? theme.colorScheme.primary
                        : (isDark
                            ? const Color(0xFF48C9B0)
                            : const Color(0xFF0F9D58)),
                  ),
                ),
                const SizedBox(height: 4),

                // Bubble container
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : (isDark
                            ? const Color(0xFF1E242B)
                            : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.transparent
                          : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          height: 1.5,
                          color: isUser
                              ? Colors.white
                              : (isDark
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF1E293B)),
                        ),
                      ),
                      if (message.actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.actions.map((act) {
                            return InkWell(
                              onTap: () => onNavigate?.call(act.menuId),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getIconData(act.icon),
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      act.label,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Time
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isUser) _buildAvatar(context, isUser, theme),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildAvatar(BuildContext context, bool isUser, ThemeData theme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primary.withOpacity(0.2)
            : const Color(0xFF48C9B0).withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: isUser
              ? theme.colorScheme.primary.withOpacity(0.4)
              : const Color(0xFF48C9B0).withOpacity(0.5),
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        size: 16,
        color: isUser
            ? theme.colorScheme.primary
            : const Color(0xFF48C9B0),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
  }
}
