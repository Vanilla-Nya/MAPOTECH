import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/ai_chat_message.dart';
import '../application/ai_assistant_service.dart';

class AIChatState {
  final List<AIChatMessage> messages;
  final bool isTyping;
  final List<String> quickActions;

  const AIChatState({
    required this.messages,
    this.isTyping = false,
    this.quickActions = const [
      'Cari Dokter Praktik',
      'Lihat Resep Obat Saya',
      'Cari Apotek Terdekat',
      'Cari Puskesmas',
      'Scan QR Code',
      'Konsultasi Gejala Batuk & Demam',
    ],
  });

  AIChatState copyWith({
    List<AIChatMessage>? messages,
    bool? isTyping,
    List<String>? quickActions,
  }) {
    return AIChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      quickActions: quickActions ?? this.quickActions,
    );
  }
}

final aiChatProvider =
    StateNotifierProvider<AIChatNotifier, AIChatState>((ref) {
  final service = ref.watch(aiAssistantServiceProvider);
  return AIChatNotifier(service);
});

class AIChatNotifier extends StateNotifier<AIChatState> {
  final AIAssistantService _service;

  AIChatNotifier(this._service)
      : super(
          AIChatState(
            messages: [
              AIChatMessage(
                text:
                    "Halo! Saya MAPOTECH AI, asisten kesehatan pribadi Anda. Ada yang bisa saya bantu hari ini? Anda bisa menanyakan gejala kesehatan, mencari dokter, apotek, atau mengecek resep obat.",
                sender: MessageSender.ai,
                timestamp: DateTime.now(),
                actions: [
                  const AIChatAction(
                    label: 'Cari Dokter',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                  const AIChatAction(
                    label: 'Resep Obat',
                    icon: 'medication',
                    menuId: 'prescription',
                  ),
                  const AIChatAction(
                    label: 'Cari Apotek',
                    icon: 'local_pharmacy',
                    menuId: 'apotek_search',
                  ),
                ],
              ),
            ],
          ),
        );

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = AIChatMessage(
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );

    // Fetch response from Gemini service
    final response = await _service.getResponse(trimmed);

    final aiMessage = AIChatMessage(
      text: response.text,
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      actions: response.actions,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isTyping: false,
    );
  }

  Future<void> startChildNutritionConsultation({
    required String childName,
    required String age,
    required String bb,
    required String tb,
    required String statusGizi,
    required String nutritionPlan,
    String? customQuestion,
  }) async {
    final questionText = customQuestion ??
        "Halo MAPOTECH AI, saya ingin berkonsultasi mengenai menu makanan & kebutuhan gizi untuk anak saya $childName (Usia: $age, BB: $bb, TB: $tb, Status Gizi: $statusGizi). Berdasarkan rekam medis ini, apa saja rekomendasi menu makanan harian, variasi protein hewani (seperti telur/ikan/ayam), dan tips pemberian makan yang tepat untuknya?";

    final userMessage = AIChatMessage(
      text: questionText,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final nutritionQuickActions = [
      'Menu protein hewani untuk $childName',
      'Cara mengatasi anak susah makan (GTM)',
      'Jadwal & tekstur makanan sesuai usia',
      'Cemilan sehat penambah berat badan',
      'Cari Dokter Anak terdekat',
    ];

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      quickActions: nutritionQuickActions,
    );

    final promptForAi =
        "Pasien berkonsultasi tentang gizi anak:\n"
        "- Nama Anak: $childName\n"
        "- Usia: $age\n"
        "- Berat Badan: $bb\n"
        "- Tinggi Badan: $tb\n"
        "- Status Gizi: $statusGizi\n"
        "- Rekomendasi Faskes Sebelumnya: $nutritionPlan\n\n"
        "Pertanyaan orang tua: $questionText";

    final response = await _service.getResponse(promptForAi);

    final aiMessage = AIChatMessage(
      text: response.text,
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      actions: response.actions.isNotEmpty
          ? response.actions
          : [
              const AIChatAction(
                label: 'Data Anak',
                icon: 'child_care',
                menuId: 'children',
              ),
              const AIChatAction(
                label: 'Cari Dokter Anak',
                icon: 'person_search',
                menuId: 'dokter_search',
              ),
            ],
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isTyping: false,
    );
  }

  void resetChat() {
    state = AIChatState(
      messages: [
        AIChatMessage(
          text:
              "Percakapan telah direset. Ada yang bisa saya bantu terkait kesehatan atau layanan MAPOTECH?",
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }
}
