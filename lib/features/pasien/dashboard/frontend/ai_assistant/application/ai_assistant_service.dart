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
  String? _currentLanguage;

  static const String _fallbackApiKey = 'AIzaSyBWARZtPoJ44Tscl2W-SXZyBZ6MpMZX1SI';

  void resetSession({String language = 'id'}) {
    _isInitialized = false;
    _chat = null;
    _model = null;
    _currentLanguage = null;
    _initModel(language: language);
  }

  void _initModel({String language = 'id'}) {
    if (_isInitialized && _model != null && _chat != null && _currentLanguage == language) {
      return;
    }

    final apiKey = (dotenv.env['GEMINI_API_KEY'] != null &&
            dotenv.env['GEMINI_API_KEY']!.isNotEmpty)
        ? dotenv.env['GEMINI_API_KEY']!
        : _fallbackApiKey;

    final isEn = language == 'en';
    final languageDirective = isEn
        ? '''
MANDATORY RESPONSE LANGUAGE: ENGLISH
The user interface is set to ENGLISH. You MUST ALWAYS write all your responses, clinical tips, child nutrition recommendations, and instructions strictly in ENGLISH.
All navigation button labels in the "actions" field MUST also be in ENGLISH (e.g. "View Growth Chart", "Find Pediatrician", "Find Puskesmas", "My Prescriptions", "Find Pharmacy").
'''
        : '''
BAHASA RESPON: WAJIB BAHASA INDONESIA
Pengguna memilih BAHASA INDONESIA di aplikasi MAPOTECH. Anda HARUS SELALU menuliskan seluruh jawaban, penjelasan gejala, dan saran menu makanan dalam Bahasa Indonesia yang ramah, sopan, dan mudah dipahami orang tua. DILARANG KERAS merespons dalam Bahasa Inggris.
Semua label tombol pada array "actions" WAJIB menggunakan Bahasa Indonesia (contoh: "Lihat Rekam Medis", "Cari Dokter Spesialis Anak", "Jadwal Posyandu", "Cari Puskesmas", "Resep Obat", "Cari Apotek").
''';

    // Use gemini-2.5-flash as primary model
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system('''
You are MAPOTECH AI, a smart, polite, empathetic, and highly capable healthcare assistant inside the MAPOTECH app for patients.
You help users with health information, first aid guidance, symptom explanations, child nutrition, growth monitoring, and direct navigation inside the MAPOTECH platform.

$languageDirective

STRICT ROLE BOUNDARY & DOMAIN RESTRICTIONS:
- You are exclusively a medical, healthcare, child nutrition, dietary guidance, and MAPOTECH navigation assistant.
- You CANNOT and MUST NOT generate software code, debug programming languages (e.g., Flutter, Dart, Python, JavaScript, C++, Java, HTML, CSS, SQL), write algorithms, or assist with IT/coding/technical software development queries.
- If the user asks for code, programming solutions, hacking, or tech topics, you MUST politely refuse:
  ${isEn ? '"Sorry, I am the MAPOTECH healthcare and nutrition assistant. I cannot assist with computer programming, software code, or technical IT issues. I am here to help you with child nutrition, healthy meal recommendations, prescriptions, and MAPOTECH healthcare facilities. How may I assist your family\'s health today?"' : '"Maaf, saya adalah asisten kesehatan dan nutrisi MAPOTECH. Saya tidak dapat membantu terkait pembuatan kode program atau coding. Saya siap membantu Anda seputar konsultasi gizi anak & balita, rekomendasi menu makanan sehat, resep obat, jadwal imunisasi, serta layanan faskes MAPOTECH. Ada yang bisa saya bantu terkait kesehatan buah hati Anda?"'}
- When a user asks about child nutrition or food recommendations with child clinical parameters (name, age, weight, height, status gizi), provide empathetic, highly practical, and evidence-based Indonesian culinary meal plans (e.g., 1 butir telur per hari, ikan air tawar/laut lokal seperti lele/kembung, hati ayam, tempe/tahu, sayur bayam/kelor/wortel, porsi makan seimbang dan tekstur sesuai usia dari Buku KIA Kemenkes 2024).

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
- "dokter_search" : ${isEn ? "Find doctor / private practice" : "Cari Dokter & Praktik Mandiri"} -> icon: "person_search"
- "puskesmas_search" : ${isEn ? "Find public health center" : "Cari Puskesmas Terdekat"} -> icon: "domain"
- "pustu_search" : ${isEn ? "Find village health post" : "Cari Pustu / Ponkesdes"} -> icon: "home_work"
- "apotek_search" : ${isEn ? "Find pharmacies & buy medicine" : "Cari Apotek Terdekat"} -> icon: "local_pharmacy"
- "prescription" : ${isEn ? "View active electronic prescriptions" : "Resep Obat Saya"} -> icon: "medication"
- "children" : ${isEn ? "View children health records & AI recommendations" : "Data Anak & Balita"} -> icon: "child_care"
- "history" : ${isEn ? "Medical history & records" : "Riwayat Medis & Transaksi"} -> icon: "history"
- "qr_scanner" : ${isEn ? "Scan QR Code Dokter/Apotek" : "Scan QR Code Dokter/Apotek"} -> icon: "qr_code_scanner"
- "profile" : ${isEn ? "Patient profile & personal data" : "Profil Pasien"} -> icon: "person"
- "settings" : ${isEn ? "App settings & preferences" : "Pengaturan"} -> icon: "settings"
- "dashboard" : ${isEn ? "Patient home dashboard" : "Beranda Utama"} -> icon: "dashboard"

Valid icon names: person_search, domain, home_work, local_pharmacy, medication, child_care, history, qr_code_scanner, person, settings, dashboard.
If no navigation action is needed, leave the "actions" array empty: [].
Do NOT wrap the JSON in ```json ... ```. Return only the raw JSON.
'''),
    );

    _chat = _model!.startChat();
    _currentLanguage = language;
    _isInitialized = true;
  }

  Future<AIResponse> getResponse(String message, {String language = 'id'}) async {
    try {
      _initModel(language: language);

      final promptPrefix = language == 'en'
          ? "[LANGUAGE INSTRUCTION: MUST RESPOND IN ENGLISH. Action button labels in English.]\n"
          : "[INSTRUKSI BAHASA: WAJIB MENJAWAB DALAM BAHASA INDONESIA. Label tombol aksi dalam Bahasa Indonesia.]\n";

      final response = await _chat!.sendMessage(Content.text('$promptPrefix$message'));
      final jsonText = response.text?.trim() ?? '{}';

      // Clean up markdown block if model wraps it
      final cleanJsonText = jsonText
          .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'^```\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*```$', caseSensitive: false), '')
          .trim();

      final Map<String, dynamic> data = jsonDecode(cleanJsonText);
      final String defaultGreeting = language == 'en'
          ? "Hello! How can I help you with your health or MAPOTECH services today?"
          : "Halo! Ada yang bisa saya bantu terkait kesehatan atau layanan MAPOTECH?";
      final String replyText = data['text'] ?? defaultGreeting;
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

        final defaultLabel = language == 'en' ? 'Open Menu' : 'Buka Halaman';
        return AIChatAction(
          label: a['label'] ?? defaultLabel,
          icon: a['icon'] ?? 'arrow_forward',
          menuId: menuId,
        );
      }).toList();

      return AIResponse(text: replyText, actions: actions);
    } catch (e) {
      debugPrint('AIAssistantService error with gemini-2.5-flash: $e');
      // Fallback attempt with gemini-1.5-flash if needed
      try {
        final apiKey = (dotenv.env['GEMINI_API_KEY'] != null &&
                dotenv.env['GEMINI_API_KEY']!.isNotEmpty)
            ? dotenv.env['GEMINI_API_KEY']!
            : _fallbackApiKey;

        final isEn = language == 'en';
        final fallbackModel = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
          systemInstruction: Content.system('''
You are MAPOTECH AI, a smart, polite healthcare & child nutrition assistant in MAPOTECH app.
STRICT RESTRICTION: You CANNOT write code or answer software programming queries. If asked about code/programming, politely refuse and redirect to child nutrition or healthcare.
${isEn ? 'Respond in English with ONLY raw JSON:' : 'Respond in Indonesian with ONLY raw JSON:'}
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
Available menuIds: dokter_search, puskesmas_search, pustu_search, apotek_search, prescription, children, history, qr_scanner, profile, settings, dashboard.
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
        final String replyText = data['text'] ??
            (isEn ? "Hello! How can I help you today?" : "Halo! Ada yang bisa saya bantu?");
        final List<dynamic> actionsJson = data['actions'] ?? [];
        final List<AIChatAction> actions = actionsJson.map((a) {
          return AIChatAction(
            label: a['label'] ?? (isEn ? 'Open Page' : 'Buka Halaman'),
            icon: a['icon'] ?? 'arrow_forward',
            menuId: a['menuId']?.toString() ?? 'dashboard',
          );
        }).toList();

        return AIResponse(text: replyText, actions: actions);
      } catch (fallbackError) {
        debugPrint('AIAssistantService fallback error: $fallbackError');
        return AIResponse(
          text: language == 'en'
              ? "Sorry, the AI assistant is currently experiencing a connection issue. Please try again shortly."
              : "Maaf, saat ini asisten AI sedang mengalami kendala koneksi atau konfigurasi. Mohon coba sesaat lagi.",
        );
      }
    }
  }
}
