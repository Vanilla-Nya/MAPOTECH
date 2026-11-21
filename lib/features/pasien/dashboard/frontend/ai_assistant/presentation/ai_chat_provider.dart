import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/shared/l10n/app_translations.dart';
import '../domain/ai_chat_message.dart';
import '../application/ai_assistant_service.dart';

class ActiveChildContext {
  final String childName;
  final String age;
  final String bb;
  final String tb;
  final String statusGizi;
  final String nutritionPlan;
  final String? childId;
  final String? childNik;
  final bool isSelf;

  const ActiveChildContext({
    required this.childName,
    required this.age,
    required this.bb,
    required this.tb,
    required this.statusGizi,
    required this.nutritionPlan,
    this.childId,
    this.childNik,
    this.isSelf = false,
  });

  Map<String, dynamic> toMap() => {
    'childName': childName,
    'age': age,
    'bb': bb,
    'tb': tb,
    'statusGizi': statusGizi,
    'nutritionPlan': nutritionPlan,
    'childId': childId,
    'childNik': childNik,
    'isSelf': isSelf,
  };
}

class AIChatState {
  final List<AIChatMessage> messages;
  final bool isTyping;
  final List<String> quickActions;
  final ActiveChildContext? activeChildContext;

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
    this.activeChildContext,
  });

  AIChatState copyWith({
    List<AIChatMessage>? messages,
    bool? isTyping,
    List<String>? quickActions,
    ActiveChildContext? activeChildContext,
    bool clearChildContext = false,
  }) {
    return AIChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      quickActions: quickActions ?? this.quickActions,
      activeChildContext:
          clearChildContext ? null : (activeChildContext ?? this.activeChildContext),
    );
  }
}

final aiChatProvider =
    StateNotifierProvider<AIChatNotifier, AIChatState>((ref) {
  final service = ref.watch(aiAssistantServiceProvider);
  return AIChatNotifier(service, ref);
});

class AIChatNotifier extends StateNotifier<AIChatState> {
  final AIAssistantService _service;
  final Ref _ref;

  AIChatNotifier(this._service, this._ref)
      : super(
          _createInitialState(_ref.read(appLanguageProvider) == 'en'),
        ) {
    // Listen for language changes dynamically from Settings
    _ref.listen<String>(appLanguageProvider, (previous, next) {
      if (previous != next) {
        onLanguageChanged(next);
      }
    });
  }

  void onLanguageChanged(String newLang) {
    final isEn = newLang == 'en';
    _service.resetSession(language: newLang);

    // 1. Update quick action chips based on context and language
    List<String> updatedQuickActions;
    if (state.activeChildContext != null) {
      final c = state.activeChildContext!;
      final isSelf = c.isSelf ||
          c.childName.toLowerCase().contains('(self)') ||
          c.childName.toLowerCase().contains('(saya)');

      if (isSelf) {
        updatedQuickActions = isEn
            ? const [
                'Daily balanced nutrition guide',
                'Tips for maintaining ideal weight & BP',
                'Consult health symptoms & complaints',
                'Daily hydration & physical activity needs',
                'Find Nearby Healthcare Clinic',
              ]
            : const [
                'Panduan pola makan gizi seimbang harian',
                'Tips menjaga berat badan & tekanan darah ideal',
                'Konsultasi keluhan gejala kesehatan',
                'Kebutuhan cairan & aktivitas fisik harian',
                'Cari Fasilitas Kesehatan terdekat',
              ];
      } else {
        updatedQuickActions = isEn
            ? [
                'Daily meal plan for ${c.childName}',
                'Tips for appetite & picky eating (GTM)',
                'Meal texture & portion for age ${c.age}',
                'Healthy weight gain snacks for ${c.childName}',
                'Find Pediatrician nearby',
              ]
            : [
                'Menu gizi seimbang untuk ${c.childName}',
                'Cara mengatasi anak susah makan (GTM)',
                'Tekstur & porsi makan usia ${c.age}',
                'Cemilan sehat penambah berat badan',
                'Cari Dokter Anak terdekat',
              ];
      }
    } else {
      updatedQuickActions = isEn
          ? const [
              'Find Doctor Practice',
              'View My Prescriptions',
              'Find Nearby Pharmacy',
              'Find Puskesmas',
              'Scan QR Code',
              'Cough & Fever Consultation',
            ]
          : const [
              'Cari Dokter Praktik',
              'Lihat Resep Obat Saya',
              'Cari Apotek Terdekat',
              'Cari Puskesmas',
              'Scan QR Code',
              'Konsultasi Gejala Batuk & Demam',
            ];
    }

    // 2. If messages only contain initial message or template greeting, translate it!
    List<AIChatMessage> updatedMessages = List.from(state.messages);
    if (updatedMessages.isNotEmpty &&
        updatedMessages.length == 1 &&
        updatedMessages.first.sender == MessageSender.ai) {
      if (state.activeChildContext != null) {
        final c = state.activeChildContext!;
        final isSelf = c.isSelf ||
            c.childName.toLowerCase().contains('(self)') ||
            c.childName.toLowerCase().contains('(saya)');
        final owner = isEn ? 'there' : 'Bunda/Ayah';

        final greetingText = isSelf
            ? (isEn
                ? "Hello $owner!\n\nYou are currently in **Personal Health Consultation Mode** (Weight: ${c.bb}, Height: ${c.tb}, Health Status: ${c.statusGizi}).\n\nWhat health questions, symptoms, or medical guidance would you like to consult with AI today? Feel free to type your question below or pick a suggested topic."
                : "Halo $owner!\n\nAnda saat ini berada dalam **Mode Konsultasi Kesehatan Pribadi** (BB: ${c.bb}, TB: ${c.tb}, Status: ${c.statusGizi}).\n\nAda keluhan, gejala kesehatan, atau informasi medis apa yang ingin Anda tanyakan ke AI hari ini? Silakan ketik pertanyaan Anda di bawah atau pilih rekomendasi topik yang tersedia.")
            : (isEn
                ? "Hello $owner!\n\nYou have selected health records for **${c.childName}** (Age: ${c.age}, Weight: ${c.bb}, Height: ${c.tb}, Nutritional Status: ${c.statusGizi}).\n\nWhat would you like to ask or consult about **${c.childName}** today? You can ask about meal planning, protein intake, picky eating (GTM), or any symptoms."
                : "Halo $owner!\n\nAnda telah memilih data rekam medis anak: **${c.childName}** (Usia: ${c.age}, BB: ${c.bb}, TB: ${c.tb}, Status Gizi: ${c.statusGizi}).\n\nApa yang ingin Anda tanyakan atau konsultasikan mengenai gizi, makanan, atau tumbuh kembang **${c.childName}** hari ini? Silakan ketik pertanyaan Anda di bawah atau pilih salah satu rekomendasi topik.");

        updatedMessages = [
          AIChatMessage(
            text: greetingText,
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
            actions: isSelf
                ? (isEn
                    ? const [
                        AIChatAction(
                          label: 'Find Clinic / Doctor',
                          icon: 'person_search',
                          menuId: 'dokter_search',
                        ),
                        AIChatAction(
                          label: 'My Prescriptions',
                          icon: 'medication',
                          menuId: 'prescription',
                        ),
                      ]
                    : const [
                        AIChatAction(
                          label: 'Cari Faskes / Dokter',
                          icon: 'person_search',
                          menuId: 'dokter_search',
                        ),
                        AIChatAction(
                          label: 'Resep Obat Saya',
                          icon: 'medication',
                          menuId: 'prescription',
                        ),
                      ])
                : (isEn
                    ? const [
                        AIChatAction(
                          label: 'Child Records',
                          icon: 'child_care',
                          menuId: 'children',
                        ),
                        AIChatAction(
                          label: 'Find Pediatrician',
                          icon: 'person_search',
                          menuId: 'dokter_search',
                        ),
                      ]
                    : const [
                        AIChatAction(
                          label: 'Data Rekam Anak',
                          icon: 'child_care',
                          menuId: 'children',
                        ),
                        AIChatAction(
                          label: 'Cari Dokter Anak',
                          icon: 'person_search',
                          menuId: 'dokter_search',
                        ),
                      ]),
          ),
        ];
      } else {
        updatedMessages = [
          AIChatMessage(
            text: isEn
                ? "Hello! I am MAPOTECH AI, your personal healthcare assistant. How can I assist you today? You can ask about health symptoms, find doctors, pharmacies, or check your prescriptions."
                : "Halo! Saya MAPOTECH AI, asisten kesehatan pribadi Anda. Ada yang bisa saya bantu hari ini? Anda bisa menanyakan gejala kesehatan, mencari dokter, apotek, atau mengecek resep obat.",
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
            actions: isEn
                ? const [
                    AIChatAction(
                      label: 'Find Doctor',
                      icon: 'person_search',
                      menuId: 'dokter_search',
                    ),
                    AIChatAction(
                      label: 'My Prescriptions',
                      icon: 'medication',
                      menuId: 'prescription',
                    ),
                    AIChatAction(
                      label: 'Find Pharmacy',
                      icon: 'local_pharmacy',
                      menuId: 'apotek_search',
                    ),
                  ]
                : const [
                    AIChatAction(
                      label: 'Cari Dokter',
                      icon: 'person_search',
                      menuId: 'dokter_search',
                    ),
                    AIChatAction(
                      label: 'Resep Obat',
                      icon: 'medication',
                      menuId: 'prescription',
                    ),
                    AIChatAction(
                      label: 'Cari Apotek',
                      icon: 'local_pharmacy',
                      menuId: 'apotek_search',
                    ),
                  ],
          ),
        ];
      }
    }

    state = state.copyWith(
      quickActions: updatedQuickActions,
      messages: updatedMessages,
    );
  }

  static AIChatState _createInitialState(bool isEn) {
    return AIChatState(
      messages: [
        AIChatMessage(
          text: isEn
              ? "Hello! I am MAPOTECH AI, your personal healthcare assistant. How can I assist you today? You can ask about health symptoms, find doctors, pharmacies, or check your prescriptions."
              : "Halo! Saya MAPOTECH AI, asisten kesehatan pribadi Anda. Ada yang bisa saya bantu hari ini? Anda bisa menanyakan gejala kesehatan, mencari dokter, apotek, atau mengecek resep obat.",
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
          actions: isEn
              ? const [
                  AIChatAction(
                    label: 'Find Doctor',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                  AIChatAction(
                    label: 'My Prescriptions',
                    icon: 'medication',
                    menuId: 'prescription',
                  ),
                  AIChatAction(
                    label: 'Find Pharmacy',
                    icon: 'local_pharmacy',
                    menuId: 'apotek_search',
                  ),
                ]
              : const [
                  AIChatAction(
                    label: 'Cari Dokter',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                  AIChatAction(
                    label: 'Resep Obat',
                    icon: 'medication',
                    menuId: 'prescription',
                  ),
                  AIChatAction(
                    label: 'Cari Apotek',
                    icon: 'local_pharmacy',
                    menuId: 'apotek_search',
                  ),
                ],
        ),
      ],
      quickActions: isEn
          ? const [
              'Find Doctor Practice',
              'View My Prescriptions',
              'Find Nearby Pharmacy',
              'Find Puskesmas',
              'Scan QR Code',
              'Cough & Fever Consultation',
            ]
          : const [
              'Cari Dokter Praktik',
              'Lihat Resep Obat Saya',
              'Cari Apotek Terdekat',
              'Cari Puskesmas',
              'Scan QR Code',
              'Konsultasi Gejala Batuk & Demam',
            ],
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final lang = _ref.read(appLanguageProvider);
    final isEn = lang == 'en';

    final userMessage = AIChatMessage(
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );

    // Sertakan konteks data anak / dewasa terpilih ke dalam prompt jika aktif
    String promptForAi = trimmed;
    if (state.activeChildContext != null) {
      final c = state.activeChildContext!;
      final isSelf = c.isSelf ||
          c.childName.toLowerCase().contains('(self)') ||
          c.childName.toLowerCase().contains('(saya)');

      if (isSelf) {
        promptForAi = isEn
            ? "User consulting regarding personal health:\n"
              "- Name: ${c.childName}\n"
              "- Weight: ${c.bb}\n"
              "- Height: ${c.tb}\n"
              "- Health Status: ${c.statusGizi}\n\n"
              "User query: $trimmed"
            : "Pasien berkonsultasi mengenai kesehatan pribadi (dewasa):\n"
              "- Nama: ${c.childName}\n"
              "- Berat Badan: ${c.bb}\n"
              "- Tinggi Badan: ${c.tb}\n"
              "- Status Kesehatan: ${c.statusGizi}\n\n"
              "Pertanyaan pasien: $trimmed";
      } else {
        promptForAi = isEn
            ? "User consulting with active child health record:\n"
              "- Child Name: ${c.childName}\n"
              "- Age: ${c.age}\n"
              "- Weight: ${c.bb}\n"
              "- Height: ${c.tb}\n"
              "- Nutritional Status: ${c.statusGizi}\n"
              "- Previous Healthcare Recommendation: ${c.nutritionPlan}\n\n"
              "Parent query: $trimmed"
            : "Pasien berkonsultasi dengan data konteks anak aktif:\n"
              "- Nama Anak: ${c.childName}\n"
              "- Usia: ${c.age}\n"
              "- Berat Badan: ${c.bb}\n"
              "- Tinggi Badan: ${c.tb}\n"
              "- Status Gizi: ${c.statusGizi}\n"
              "- Rekomendasi/Intervensi Faskes: ${c.nutritionPlan}\n\n"
              "Pertanyaan orang tua: $trimmed";
      }
    }

    // Fetch response from Gemini service with explicit active user language
    final response = await _service.getResponse(promptForAi, language: lang);

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
    final lang = _ref.read(appLanguageProvider);
    final isEn = lang == 'en';

    final questionText = customQuestion ??
        (isEn
            ? "Hello MAPOTECH AI, I would like to consult regarding meal plans and nutritional needs for my child $childName (Age: $age, Weight: $bb, Height: $tb, Nutritional Status: $statusGizi). Based on these medical records, what are your daily meal recommendations, animal protein variations (such as egg/fish/chicken), and feeding tips suitable for them?"
            : "Halo MAPOTECH AI, saya ingin berkonsultasi mengenai menu makanan & kebutuhan gizi untuk anak saya $childName (Usia: $age, BB: $bb, TB: $tb, Status Gizi: $statusGizi). Berdasarkan rekam medis ini, apa saja rekomendasi menu makanan harian, variasi protein hewani (seperti telur/ikan/ayam), dan tips pemberian makan yang tepat untuknya?");

    final userMessage = AIChatMessage(
      text: questionText,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final nutritionQuickActions = isEn
        ? [
            'Animal protein menu for $childName',
            'Tips for picky eating / feeding issues',
            'Age-appropriate meal texture & schedule',
            'Healthy calorie-dense weight gain snacks',
            'Find Pediatrician nearby',
          ]
        : [
            'Menu protein hewani untuk $childName',
            'Cara mengatasi anak susah makan (GTM)',
            'Jadwal & tekstur makanan sesuai usia',
            'Cemilan sehat penambah berat badan',
            'Cari Dokter Anak terdekat',
          ];

    final activeContext = ActiveChildContext(
      childName: childName,
      age: age,
      bb: bb,
      tb: tb,
      statusGizi: statusGizi,
      nutritionPlan: nutritionPlan,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      quickActions: nutritionQuickActions,
      activeChildContext: activeContext,
    );

    final promptForAi = isEn
        ? "Patient consulting about child nutrition:\n"
          "- Child Name: $childName\n"
          "- Age: $age\n"
          "- Weight: $bb\n"
          "- Height: $tb\n"
          "- Nutritional Status: $statusGizi\n"
          "- Previous Healthcare Clinic Guidance: $nutritionPlan\n\n"
          "Parent question: $questionText"
        : "Pasien berkonsultasi tentang gizi anak:\n"
          "- Nama Anak: $childName\n"
          "- Usia: $age\n"
          "- Berat Badan: $bb\n"
          "- Tinggi Badan: $tb\n"
          "- Status Gizi: $statusGizi\n"
          "- Rekomendasi Faskes Sebelumnya: $nutritionPlan\n\n"
          "Pertanyaan orang tua: $questionText";

    final response = await _service.getResponse(promptForAi, language: lang);

    final fallbackActions = isEn
        ? const [
            AIChatAction(
              label: 'Child Records',
              icon: 'child_care',
              menuId: 'children',
            ),
            AIChatAction(
              label: 'Find Pediatrician',
              icon: 'person_search',
              menuId: 'dokter_search',
            ),
          ]
        : const [
            AIChatAction(
              label: 'Data Anak',
              icon: 'child_care',
              menuId: 'children',
            ),
            AIChatAction(
              label: 'Cari Dokter Anak',
              icon: 'person_search',
              menuId: 'dokter_search',
            ),
          ];

    final aiMessage = AIChatMessage(
      text: response.text,
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      actions: response.actions.isNotEmpty ? response.actions : fallbackActions,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isTyping: false,
    );
  }

  void selectChildContext({
    required ActiveChildContext childContext,
    String? accountOwnerName,
  }) {
    final lang = _ref.read(appLanguageProvider);
    final isEn = lang == 'en';
    final owner = (accountOwnerName != null && accountOwnerName.trim().isNotEmpty)
        ? accountOwnerName.trim()
        : (isEn ? 'there' : 'Bunda/Ayah');

    final isSelf = childContext.isSelf ||
        childContext.childName.toLowerCase().contains('(self)') ||
        childContext.childName.toLowerCase().contains('(saya)');

    // 1. Context-specific quick actions
    final List<String> quickActions = isSelf
        ? (isEn
            ? [
                'Daily balanced nutrition guide',
                'Tips for maintaining ideal weight & BP',
                'Consult health symptoms & complaints',
                'Daily hydration & physical activity needs',
                'Find Nearby Healthcare Clinic',
              ]
            : [
                'Panduan pola makan gizi seimbang harian',
                'Tips menjaga berat badan & tekanan darah ideal',
                'Konsultasi keluhan gejala kesehatan',
                'Kebutuhan cairan & aktivitas fisik harian',
                'Cari Fasilitas Kesehatan terdekat',
              ])
        : (isEn
            ? [
                'Daily meal plan for ${childContext.childName}',
                'Tips for appetite & picky eating (GTM)',
                'Meal texture & portion for age ${childContext.age}',
                'Healthy weight gain snacks for ${childContext.childName}',
                'Find Pediatrician nearby',
              ]
            : [
                'Menu gizi seimbang untuk ${childContext.childName}',
                'Cara mengatasi anak susah makan (GTM)',
                'Tekstur & porsi makan usia ${childContext.age}',
                'Cemilan sehat penambah berat badan',
                'Cari Dokter Anak terdekat',
              ]);

    // 2. Local template greeting (ZERO GEMINI TOKENS USED!)
    final String greetingText = isSelf
        ? (isEn
            ? "Hello $owner!\n\nYou are currently in **Personal Health Consultation Mode** (Weight: ${childContext.bb}, Height: ${childContext.tb}, Health Status: ${childContext.statusGizi}).\n\nWhat health questions, symptoms, or medical guidance would you like to consult with AI today? Feel free to type your question below or pick a suggested topic."
            : "Halo $owner!\n\nAnda saat ini berada dalam **Mode Konsultasi Kesehatan Pribadi** (BB: ${childContext.bb}, TB: ${childContext.tb}, Status: ${childContext.statusGizi}).\n\nAda keluhan, gejala kesehatan, atau informasi medis apa yang ingin Anda tanyakan ke AI hari ini? Silakan ketik pertanyaan Anda di bawah atau pilih rekomendasi topik yang tersedia.")
        : (isEn
            ? "Hello $owner!\n\nYou have selected health records for **${childContext.childName}** (Age: ${childContext.age}, Weight: ${childContext.bb}, Height: ${childContext.tb}, Nutritional Status: ${childContext.statusGizi}).\n\nWhat would you like to ask or consult about **${childContext.childName}** today? You can ask about meal planning, protein intake, picky eating (GTM), or any symptoms."
            : "Halo $owner!\n\nAnda telah memilih data rekam medis anak: **${childContext.childName}** (Usia: ${childContext.age}, BB: ${childContext.bb}, TB: ${childContext.tb}, Status Gizi: ${childContext.statusGizi}).\n\nApa yang ingin Anda tanyakan atau konsultasikan mengenai gizi, makanan, atau tumbuh kembang **${childContext.childName}** hari ini? Silakan ketik pertanyaan Anda di bawah atau pilih salah satu rekomendasi topik.");

    final templateMessage = AIChatMessage(
      text: greetingText,
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      actions: isSelf
          ? (isEn
              ? const [
                  AIChatAction(
                    label: 'Find Clinic / Doctor',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                  AIChatAction(
                    label: 'My Prescriptions',
                    icon: 'medication',
                    menuId: 'prescription',
                  ),
                ]
              : const [
                  AIChatAction(
                    label: 'Cari Faskes / Dokter',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                  AIChatAction(
                    label: 'Resep Obat Saya',
                    icon: 'medication',
                    menuId: 'prescription',
                  ),
                ])
          : (isEn
              ? const [
                  AIChatAction(
                    label: 'Child Records',
                    icon: 'child_care',
                    menuId: 'children',
                  ),
                  AIChatAction(
                    label: 'Find Pediatrician',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                ]
              : const [
                  AIChatAction(
                    label: 'Data Rekam Anak',
                    icon: 'child_care',
                    menuId: 'children',
                  ),
                  AIChatAction(
                    label: 'Cari Dokter Anak',
                    icon: 'person_search',
                    menuId: 'dokter_search',
                  ),
                ]),
    );

    state = state.copyWith(
      activeChildContext: childContext,
      quickActions: quickActions,
      messages: [...state.messages, templateMessage],
      isTyping: false,
    );
  }

  void setActiveChild(ActiveChildContext? child, {String? accountOwnerName}) {
    if (child == null) {
      clearActiveChild(accountOwnerName: accountOwnerName);
      return;
    }
    selectChildContext(childContext: child, accountOwnerName: accountOwnerName);
  }

  void clearActiveChild({String? accountOwnerName}) {
    final isEn = _ref.read(appLanguageProvider) == 'en';
    final owner = (accountOwnerName != null && accountOwnerName.trim().isNotEmpty)
        ? accountOwnerName.trim()
        : (isEn ? 'there' : 'Bunda/Ayah');

    final defaultActions = isEn
        ? const [
            'Find Doctor Practice',
            'View My Prescriptions',
            'Find Nearby Pharmacy',
            'Find Puskesmas',
            'Scan QR Code',
            'Cough & Fever Consultation',
          ]
        : const [
            'Cari Dokter Praktik',
            'Lihat Resep Obat Saya',
            'Cari Apotek Terdekat',
            'Cari Puskesmas',
            'Scan QR Code',
            'Konsultasi Gejala Batuk & Demam',
          ];

    final resetMsg = AIChatMessage(
      text: isEn
          ? "Hello $owner!\n\nPatient context has been cleared. You are now in general healthcare assistant mode. How can I help you today?"
          : "Halo $owner!\n\nKonteks pasien telah dinonaktifkan. Anda sekarang berada dalam mode asisten kesehatan umum. Ada yang bisa saya bantu hari ini?",
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      actions: isEn
          ? const [
              AIChatAction(
                label: 'Find Doctor',
                icon: 'person_search',
                menuId: 'dokter_search',
              ),
              AIChatAction(
                label: 'Find Pharmacy',
                icon: 'local_pharmacy',
                menuId: 'apotek_search',
              ),
            ]
          : const [
              AIChatAction(
                label: 'Cari Dokter',
                icon: 'person_search',
                menuId: 'dokter_search',
              ),
              AIChatAction(
                label: 'Cari Apotek',
                icon: 'local_pharmacy',
                menuId: 'apotek_search',
              ),
            ],
    );

    state = state.copyWith(
      clearChildContext: true,
      quickActions: defaultActions,
      messages: [...state.messages, resetMsg],
      isTyping: false,
    );
  }

  void resetChat() {
    final isEn = _ref.read(appLanguageProvider) == 'en';
    state = AIChatState(
      messages: [
        AIChatMessage(
          text: isEn
              ? "Conversation has been reset. How may I assist you with your health or MAPOTECH services today?"
              : "Percakapan telah direset. Ada yang bisa saya bantu terkait kesehatan atau layanan MAPOTECH?",
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ),
      ],
      quickActions: isEn
          ? const [
              'Find Doctor Practice',
              'View My Prescriptions',
              'Find Nearby Pharmacy',
              'Find Puskesmas',
              'Scan QR Code',
              'Cough & Fever Consultation',
            ]
          : const [
              'Cari Dokter Praktik',
              'Lihat Resep Obat Saya',
              'Cari Apotek Terdekat',
              'Cari Puskesmas',
              'Scan QR Code',
              'Konsultasi Gejala Batuk & Demam',
            ],
      activeChildContext: state.activeChildContext,
    );
  }
}
