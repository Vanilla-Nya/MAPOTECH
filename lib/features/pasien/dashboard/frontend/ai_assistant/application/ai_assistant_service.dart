import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/ai_chat_message.dart';

final aiAssistantServiceProvider = Provider((ref) => AIAssistantService());

/// Result from the AI service — text + optional action buttons.
class AIResponse {
  final String text;
  final List<AIChatAction> actions;

  const AIResponse({required this.text, this.actions = const []});
}

class AIAssistantService {
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isInitialized = false;

  static const String _fallbackApiKey = 'AIzaSyBWARZtPoJ44Tscl2W-SXZyBZ6MpMZX1SI';

  void _initModel() {
    if (_isInitialized && _model != null && _chat != null) return;

    final apiKey = (dotenv.env['GEMINI_API_KEY'] != null &&
            dotenv.env['GEMINI_API_KEY']!.isNotEmpty)
        ? dotenv.env['GEMINI_API_KEY']!
        : _fallbackApiKey;

    // Use gemini-2.5-flash as primary model
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system('''
You are MAPOTECH AI, a smart, polite, empathetic, and highly capable healthcare assistant inside the MAPOTECH app for patients.
You help users with health information, first aid guidance, symptom explanations, and direct navigation inside the MAPOTECH platform.
Respond in Indonesian by default (or English if the user asks in English).

IMPORTANT: You MUST respond with ONLY a raw JSON object.
The JSON must follow this exact structure:
{
  "text": "Your conversational reply to the user here.",
  "actions": [
    {
      "label": "Button Label",
      "icon": "icon_name",
      "menuId": "target_menu_id"
    }
  ]
}

Available menu IDs for navigation actions (only include relevant ones that directly help the user take action):
- "dokter_search" : Cari Dokter & Praktik Mandiri (Find doctor / private practice) -> icon: "person_search"
- "puskesmas_search" : Cari Puskesmas Terdekat (Find public health center) -> icon: "domain"
- "pustu_search" : Cari Pustu / Ponkesdes (Find village health post) -> icon: "home_work"
- "apotek_search" : Cari Apotek Terdekat (Find pharmacies & buy medicine) -> icon: "local_pharmacy"
- "prescription" : Resep Obat Saya (View active electronic prescriptions) -> icon: "medication"
- "history" : Riwayat Medis & Transaksi (Medical history & records) -> icon: "history"
- "qr_scanner" : Scan QR Code Dokter/Apotek (Quick QR check-in & redemption) -> icon: "qr_code_scanner"
- "profile" : Profil Pasien (Patient profile & personal data) -> icon: "person"
- "settings" : Pengaturan (App settings & preferences) -> icon: "settings"
- "dashboard" : Beranda Utama (Patient home dashboard) -> icon: "dashboard"

Valid icon names: person_search, domain, home_work, local_pharmacy, medication, history, qr_code_scanner, person, settings, dashboard.
If no navigation action is needed, leave the "actions" array empty: [].
Do NOT wrap the JSON in ```json ... ```. Return only the raw JSON.
'''),
    );

    _chat = _model!.startChat();
    _isInitialized = true;
  }

  Future<AIResponse> getResponse(String message) async {
    try {
      _initModel();

      final response = await _chat!.sendMessage(Content.text(message));
      final jsonText = response.text?.trim() ?? '{}';

      // Clean up markdown block if model wraps it
      final cleanJsonText = jsonText
          .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'^```\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*```$', caseSensitive: false), '')
          .trim();

      final Map<String, dynamic> data = jsonDecode(cleanJsonText);
      final String replyText =
          data['text'] ?? "Halo! Ada yang bisa saya bantu terkait kesehatan atau layanan MAPOTECH?";
      final List<dynamic> actionsJson = data['actions'] ?? [];

      final List<AIChatAction> actions = actionsJson.map((a) {
        // Map fragmentIndex backwards compatibility if model sends numeric index
        String menuId = a['menuId']?.toString() ?? '';
        if (menuId.isEmpty && a['fragmentIndex'] != null) {
          final idx = a['fragmentIndex'];
          switch (idx) {
            case 1:
              menuId = 'dokter_search';
              break;
            case 2:
              menuId = 'prescription';
              break;
            case 4:
              menuId = 'history';
              break;
            case 5:
              menuId = 'profile';
              break;
            case 6:
              menuId = 'settings';
              break;
            case 8:
              menuId = 'apotek_search';
              break;
            default:
              menuId = 'dashboard';
          }
        }
        if (menuId.isEmpty) {
          menuId = 'dashboard';
        }

        return AIChatAction(
          label: a['label'] ?? 'Buka Halaman',
          icon: a['icon'] ?? 'arrow_forward',
          menuId: menuId,
        );
      }).toList();

      return AIResponse(text: replyText, actions: actions);
    } catch (e) {
      debugPrint('AIAssistantService error with gemini-2.5-flash: $e');
      // Fallback attempt with gemini-1.5-flash or gemini-2.0-flash if needed
      try {
        final apiKey = (dotenv.env['GEMINI_API_KEY'] != null &&
                dotenv.env['GEMINI_API_KEY']!.isNotEmpty)
            ? dotenv.env['GEMINI_API_KEY']!
            : _fallbackApiKey;

        final fallbackModel = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
          systemInstruction: Content.system('''
You are MAPOTECH AI, a smart, polite healthcare assistant in MAPOTECH app.
Respond in Indonesian with ONLY raw JSON:
{
  "text": "Your message",
  "actions": [
    {
      "label": "Button Label",
      "icon": "icon_name",
      "menuId": "dokter_search"
    }
  ]
}
Available menuIds: dokter_search, puskesmas_search, pustu_search, apotek_search, prescription, history, qr_scanner, profile, settings, dashboard.
'''),
        );
        final fallbackChat = fallbackModel.startChat();
        final response = await fallbackChat.sendMessage(Content.text(message));
        final cleanJson = (response.text ?? '{}')
            .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'^```\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*```$', caseSensitive: false), '')
            .trim();
        final Map<String, dynamic> data = jsonDecode(cleanJson);
        final String replyText = data['text'] ?? "Halo! Ada yang bisa saya bantu?";
        final List<dynamic> actionsJson = data['actions'] ?? [];
        final List<AIChatAction> actions = actionsJson.map((a) {
          return AIChatAction(
            label: a['label'] ?? 'Buka Halaman',
            icon: a['icon'] ?? 'arrow_forward',
            menuId: a['menuId']?.toString() ?? 'dashboard',
          );
        }).toList();

        return AIResponse(text: replyText, actions: actions);
      } catch (fallbackError) {
        debugPrint('AIAssistantService fallback error: $fallbackError');
        return const AIResponse(
          text:
              "Maaf, saat ini asisten AI sedang mengalami kendala koneksi atau konfigurasi. Mohon coba sesaat lagi.",
        );
      }
    }
  }
}
