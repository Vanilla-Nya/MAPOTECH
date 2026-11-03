import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../data/vitascale_api_service.dart';

/// Hasil analisis penalaran klinis (Clinical Reasoning) dari AI Reasoning Model
class VitaScaleReasoningResult {
  final String reasoningSummary;
  final List<String> chainOfThoughtSteps;
  final String riskAndEtiology;
  final String nutritionalIntervention;
  final String medicalProtocol;
  final String parentEducation;
  final DateTime generatedAt;
  final String modelUsed;

  const VitaScaleReasoningResult({
    required this.reasoningSummary,
    required this.chainOfThoughtSteps,
    required this.riskAndEtiology,
    required this.nutritionalIntervention,
    required this.medicalProtocol,
    required this.parentEducation,
    required this.generatedAt,
    this.modelUsed = 'gemini-2.5-flash',
  });

  factory VitaScaleReasoningResult.fromMap(Map<String, dynamic> map, {String model = 'gemini-2.5-flash'}) {
    final rawSteps = map['chain_of_thought_steps'];
    List<String> steps = [];
    if (rawSteps is List) {
      steps = rawSteps.map((e) => e.toString()).toList();
    }

    return VitaScaleReasoningResult(
      reasoningSummary: map['reasoning_summary']?.toString() ??
          'Analisis status pertumbuhan menunjukkan kesesuaian dengan parameter antropometri yang diinput.',
      chainOfThoughtSteps: steps.isNotEmpty
          ? steps
          : [
              'Memeriksa z-score dan kurva standar WHO 2006 untuk usia dan jenis kelamin balita.',
              'Mengevaluasi kesesuaian rasio berat terhadap tinggi badan (BB/TB).',
              'Menilai risiko defisit pertumbuhan linier jangka panjang (TB/U).',
            ],
      riskAndEtiology: map['risk_and_etiology']?.toString() ??
          'Perlu evaluasi asupan energi, protein hewani, dan riwayat infeksi saluran cerna atau pernapasan dalam 3 bulan terakhir.',
      nutritionalIntervention: map['nutritional_intervention']?.toString() ??
          'Tingkatkan asupan protein hewani harian (1 butir telur/hari, ikan, daging/hati ayam) dan pastikan variasi menu MP-ASI adekuat.',
      medicalProtocol: map['medical_protocol']?.toString() ??
          'Jadwalkan pemantauan berat dan tinggi badan dalam 14-30 hari di Puskesmas/Posyandu. Pantau bila terjadi weight faltering.',
      parentEducation: map['parent_education']?.toString() ??
          'Tetap berikan stimulasi tumbuh kembang yang hangat, jaga sanitasi air dan lingkungan, serta utamakan protein hewani di setiap porsi makan anak.',
      generatedAt: DateTime.now(),
      modelUsed: model,
    );
  }
}

/// Service untuk memanggil Reasoning Model (Gemini 2.5 Flash)
class VitaScaleReasoningService {
  static const String _fallbackApiKey = 'AIzaSyBWARZtPoJ44Tscl2W-SXZyBZ6MpMZX1SI';

  /// Menganalisis hasil klasifikasi MLP dengan model penalaran klinis
  static Future<VitaScaleReasoningResult> generateReasoning({
    required String childName,
    required String genderLabel,
    required double ageMonths,
    required double weightKg,
    required double heightCm,
    required HasilSmartGrowthBalita mlpResult,
    double? waistCm,
    double? lilaCm,
  }) async {
    final apiKey = (dotenv.env['GEMINI_API_KEY'] != null &&
            dotenv.env['GEMINI_API_KEY']!.isNotEmpty)
        ? dotenv.env['GEMINI_API_KEY']!
        : _fallbackApiKey;

    const modelName = 'gemini-2.5-flash';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3,
      ),
      systemInstruction: Content.system('''
Anda adalah Dokter Spesialis Anak Konsultan Tumbuh Kembang & Ahli Gizi Klinis di sistem MAPOTECH VitaScale.
Tugas Anda adalah melakukan Clinical Reasoning (Penalaran Klinis Berbasis Bukti) terhadap data balita dan hasil klasifikasi Machine Learning (Keras MLP).

Gunakan standar acuan:
1. Permenkes RI No. 2 Tahun 2020 tentang Standar Antropometri Anak
2. WHO Child Growth Standards (2006)
3. Pedoman Tatalaksana Gizi Buruk dan Pencegahan Stunting Kemenkes RI

WAJIB mengembalikan HANYA format JSON valid berikut:
{
  "reasoning_summary": "Ringkasan penalaran klinis dokter dalam 2-3 kalimat yang padat dan jelas mengenai status anak.",
  "chain_of_thought_steps": [
    "Langkah 1: Evaluasi usia dan jenis kelamin terhadap standar median berat dan panjang/tinggi badan.",
    "Langkah 2: Interpretasi hasil klasifikasi model MLP (kategori BB/TB dan TB/U) dengan tingkat keyakinannya.",
    "Langkah 3: Analisis diferensial korelasi antara massa tubuh saat ini (acute wasting) dan retardasi pertumbuhan linier kronis (chronic stunting)."
  ],
  "risk_and_etiology": "Analisis potensi penyebab utama (asupan gizi makro/mikronutrien, MP-ASI dini/terlambat, infeksi berulang diare/ISPA, sanitasi, alergi makanan).",
  "nutritionalIntervention": "Rencana intervensi gizi terperinci: target kalori/protein harian, jenis protein hewani spesifik (telur, hati, ikan, susu pertumbuhan), suplementasi mikronutrien (Zinc, Zat Besi, Taburia, Vit A), serta panduan tekstur makan.",
  "medical_protocol": "Protokol tindakan faskes: jadwal kontrol ulang (misal 2 minggu atau 1 bulan), indikasi rujukan ke RS/Dokter Spesialis Anak (tanda bahaya / red flags), dan evaluasi kurva pertumbuhan KMS.",
  "parent_education": "Pesan edukasi suportif dan bahasa awam yang mudah dipahami orang tua untuk diterapkan di rumah tanpa membuat panik."
}
'''),
    );

    final promptText = '''
Lakukan analisis Clinical Reasoning untuk data pengukuran balita berikut:

Profil Balita:
- Nama: $childName
- Jenis Kelamin: $genderLabel
- Usia: $ageMonths bulan
- Berat Badan: $weightKg kg
- Panjang/Tinggi Badan: $heightCm cm
${waistCm != null ? '- Lingkar Perut: $waistCm cm' : ''}
${lilaCm != null ? '- LiLA (Lingkar Lengan Atas): $lilaCm cm' : ''}

Hasil Prediksi Model Machine Learning VitaScale (Keras MLP):
- Kategori Status Gizi (BB/TB): ${mlpResult.kategoriGiziBbtb} (Keyakinan: ${mlpResult.confidenceBbtb.toStringAsFixed(1)}%)
- Kategori Status Stunting (TB/U): ${mlpResult.kategoriStuntingTbu} (Keyakinan: ${mlpResult.confidenceTbu.toStringAsFixed(1)}%)
- Status Berisiko Stunting: ${mlpResult.isStunting ? 'YA' : 'TIDAK'}
- Status Berisiko Gizi Buruk / Kurang: ${mlpResult.isGiziBurukAtauKurang ? 'YA' : 'TIDAK'}
- Distribusi Probabilitas BB/TB: ${mlpResult.probabilitasBbtb}
- Distribusi Probabilitas TB/U: ${mlpResult.probabilitasTbu}

Berikan alur penalaran klinis (Chain of Thought), identifikasi faktor risiko, rencana nutrisi protein hewani, protokol tindakan medis faskes, serta edukasi orang tua.
''';

    try {
      final response = await model.generateContent([Content.text(promptText)]);
      final rawText = response.text?.trim() ?? '{}';

      final cleanJson = rawText
          .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'^```\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*```$', caseSensitive: false), '')
          .trim();

      final Map<String, dynamic> parsed = jsonDecode(cleanJson);
      return VitaScaleReasoningResult.fromMap(parsed, model: modelName);
    } catch (e) {
      debugPrint('[VitaScaleReasoning] Error: $e');
      // Kembalikan fallback reasoning cerdas berbasis aturan klinis jika jaringan offline
      return _generateClinicalRuleBasedFallback(
        childName: childName,
        genderLabel: genderLabel,
        ageMonths: ageMonths,
        weightKg: weightKg,
        heightCm: heightCm,
        mlpResult: mlpResult,
      );
    }
  }

  /// Fallback cerdas berbasis protokol antropometri jika koneksi ke Gemini terhambat
  static VitaScaleReasoningResult _generateClinicalRuleBasedFallback({
    required String childName,
    required String genderLabel,
    required double ageMonths,
    required double weightKg,
    required double heightCm,
    required HasilSmartGrowthBalita mlpResult,
  }) {
    final isStunting = mlpResult.isStunting;
    final isGiziKurang = mlpResult.isGiziBurukAtauKurang;

    String summary;
    List<String> steps = [];
    String etiology;
    String nutrition;
    String protocol;
    String parent;

    if (isStunting || isGiziKurang) {
      summary = 'Hasil klasifikasi menunjukkan adanya indikasi $mlpResult.kategoriStuntingTbu (TB/U) '
          'dan $mlpResult.kategoriGiziBbtb (BB/TB). Diperlukan intervensi percepatan nutrisi protein hewani '
          'dan investigasi faktor infeksi penyerta.';
      steps = [
        'Model mendeteksi rasio berat badan terhadap panjang/tinggi (${weightKg}kg / ${heightCm}cm) berada di bawah ambang normal anak usia ${ageMonths.toStringAsFixed(0)} bulan.',
        'Pertumbuhan linier menunjukkan deviasi yang mengarah pada $mlpResult.kategoriStuntingTbu dengan keyakinan ${mlpResult.confidenceTbu.toStringAsFixed(1)}%.',
        'Penurunan proporsi massa otot dan lemak mengindikasikan defisit energi kronis atau asupan zat pembangun yang belum tercukupi.',
      ];
      etiology = 'Faktor risiko yang sering memicu: kualitas MP-ASI yang kurang padat energi & protein hewani, '
          'riwayat sakit berkala (batuk pilek, diare berulang), atau absorpsi nutrisi usus yang terganggu.';
      nutrition = 'Tingkatkan asupan protein hewani esensial: minimal 1 butir telur utuh per hari ditambah ikan berlemak/daging ayam/hati. '
          'Tambahkan suplementasi Zinc dan Zat Besi sesuai anjuran petugas kesehatan.';
      protocol = 'Jadwalkan kunjungan ulang evaluasi 14 hari ke depan di Puskesmas. '
          'Rujuk ke dokter spesialis anak bila berat badan tidak mengalami kenaikan minimal (KBM) dalam 2 kali penimbangan berturut-turut.';
      parent = 'Bunda/Ayah jangan berkecil hati. Periode emas ini masih sangat responsif terhadap perbaikan gizi. '
          'Fokuslah memberikan makanan padat protein hewani sebelum memberikan camilan berserat tinggi atau manis.';
    } else {
      summary = 'Status pertumbuhan $childName tergolong $mlpResult.kategoriGiziBbtb dan $mlpResult.kategoriStuntingTbu. '
          'Indikator antropometri berada dalam batas aman standar WHO.';
      steps = [
        'Panjang/tinggi badan ${heightCm}cm sesuai dengan median kurva pertumbuhan untuk balita usia ${ageMonths.toStringAsFixed(0)} bulan.',
        'Berat badan ${weightKg}kg proporsional dengan tinggi badan saat ini (${mlpResult.kategoriGiziBbtb}).',
        'Confidence model MLP mencapai ${mlpResult.confidenceBbtb.toStringAsFixed(1)}% untuk BB/TB dan ${mlpResult.confidenceTbu.toStringAsFixed(1)}% untuk TB/U.',
      ];
      etiology = 'Pertumbuhan berlangsung optimal tanpa tanda-tanda malnutrisi akut maupun kronis.';
      nutrition = 'Pertahankan pola gizi seimbang "Isi Piringku": variasi karbohidrat kompleks, protein hewani beragam, '
          'sayur, buah, serta asupan cairan yang cukup.';
      protocol = 'Lanjutkan pemantauan rutin bulanan di Posyandu/Puskesmas terdekat untuk memastikan kurva pertumbuhan tetap naik mengikuti pita hijau KMS.';
      parent = 'Pertahankan pola makan dan stimulasi aktif yang sudah sangat baik ini! Tetap rutin menimbang dan mengukur anak setiap bulan.';
    }

    return VitaScaleReasoningResult(
      reasoningSummary: summary,
      chainOfThoughtSteps: steps,
      riskAndEtiology: etiology,
      nutritionalIntervention: nutrition,
      medicalProtocol: protocol,
      parentEducation: parent,
      generatedAt: DateTime.now(),
      modelUsed: 'Clinical Rule-Based Fallback Engine',
    );
  }
}

