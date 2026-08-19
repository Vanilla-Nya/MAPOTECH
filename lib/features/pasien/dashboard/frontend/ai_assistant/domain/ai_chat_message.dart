enum MessageSender { user, ai }

/// Represents a single navigable action button shown inside an AI message.
class AIChatAction {
  final String label;
  final String icon; // e.g. 'history', 'receipt_long', 'person_search', 'local_pharmacy', 'domain', 'home_work', 'qr_code_scanner', 'settings', 'person'
  final String menuId; // Target menu ID in MAPOTECH (e.g. 'dokter_search', 'puskesmas_search', 'prescription', etc.)

  const AIChatAction({
    required this.label,
    required this.icon,
    required this.menuId,
  });
}

class AIChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final List<AIChatAction> actions;

  AIChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.actions = const [],
  });
}
