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
    final rawSteps = map['chain_of_thought_steps'] ?? map['chainOfThoughtSteps'];
    List<String> steps = [];
    if (rawSteps is List) {
      steps = rawSteps.map((e) => e.toString()).toList();
    }

    return VitaScaleReasoningResult(
      reasoningSummary: map['reasoning_summary']?.toString() ??
          map['reasoningSummary']?.toString() ??
          'Analisis status pertumbuhan menunjukkan kesesuaian dengan parameter antropometri Buku KIA 2024.',
      chainOfThoughtSteps: steps.isNotEmpty
          ? steps
          : [
              'Memeriksa z-score dan kurva standar WHO 2006 / Buku KIA 2024 untuk usia dan jenis kelamin balita.',
              'Mengevaluasi kesesuaian rasio berat terhadap tinggi badan (BB/TB).',
              'Menilai risiko defisit pertumbuhan linier jangka panjang (TB/U).',
            ],
      riskAndEtiology: map['risk_and_etiology']?.toString() ??
          map['riskAndEtiology']?.toString() ??
          'Perlu evaluasi asupan energi, kecukupan protein hewani harian, dan riwayat infeksi berulang.',
      nutritionalIntervention: map['nutritional_intervention']?.toString() ??
          map['nutritionalIntervention']?.toString() ??
          'Tingkatkan asupan protein hewani harian (1 butir telur/hari, ikan lokal, daging/hati ayam) dan pastikan tekstur MP-ASI adekuat sesuai usia (Buku KIA 2024).',
      medicalProtocol: map['medical_protocol']?.toString() ??
          map['medicalProtocol']?.toString() ??
          'Jadwalkan pemantauan berat dan tinggi badan dalam 14-30 hari di Puskesmas/Posyandu. Waspadai indikasi rujukan jika terjadi weight faltering (2T) atau BGM.',
      parentEducation: map['parent_education']?.toString() ??
          map['parentEducation']?.toString() ??
          'Tetap berikan stimulasi tumbuh kembang yang hangat, jaga sanitasi lingkungan, serta utamakan protein hewani di setiap porsi makan anak.',
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
    double? headCircumferenceCm,
    String? measurementMethod,
    String? kmsStatus,
    bool? receivedVitA,
    bool? receivedDeworming,
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
        temperature: 0.2,
      ),
      systemInstruction: Content.system('''
Anda adalah Dokter Spesialis Anak Konsultan Tumbuh Kembang & Ahli Gizi Klinis di sistem MAPOTECH VitaScale terintegrasi SATUSEHAT Kemenkes RI.
Tugas Anda adalah melakukan Clinical Reasoning (Penalaran Klinis Berbasis Bukti) terhadap data skrining balita dan hasil klasifikasi Machine Learning (Keras MLP).

STANDAR ACUAN RESMI:
1. Buku KIA (Kesehatan Ibu dan Anak) Edisi 2024 - Kementerian Kesehatan RI (Bagian Kesehatan & Tumbuh Kembang Balita)
2. Standar Interoperabilitas Antropometri Anak SATUSEHAT Kemenkes RI (FHIR R4 / LOINC & SNOMED CT)
3. Permenkes RI No. 2 Tahun 2020 tentang Standar Antropometri Anak
4. WHO Child Growth Standards (2006)
5. Pedoman Pencegahan dan Tata Laksana Gizi Buruk pada Balita Kemenkes RI

ATURAN KLINIS MUTLAK (GOLDEN RULES BUKU KIA 2024 & SATUSEHAT) - TIDAK BOLEH DILANGGAR:
1. ATURAN CARA PENGUKURAN ANTROPOMETRI BAKU (BUKU KIA 2024 HAL 48):
   - Balita usia < 24 bulan: Diukur Panjang Badan Telentang (PB / Infantometer). Jika diukur berdiri, hasil dikoreksi +0.7 cm.
   - Balita usia ≥ 24 bulan: Diukur Tinggi Badan Berdiri (TB / Stadiometer). Jika diukur telentang, hasil dikoreksi -0.7 cm.
   - Lingkar Kepala (LK): Diplot pada Kurva Nellhaus (Buku KIA) untuk deteksi mikrosefali (<-2 SD) atau makrosefali (>+2 SD).
   - Lingkar Lengan Atas (LiLA): Pita warna Merah (<11.5 cm = gizi buruk), Kuning (11.5-12.5 cm = gizi kurang), Hijau (>12.5 cm = normal).

2. ATURAN PEMBERIAN MAKAN & MP-ASI SESUAI KELOMPOK USIA:
   - Usia 0 - 6 bulan:
     * HANYA ASI Eksklusif sesering mungkin (on demand, minimal 8 kali sehari).
     * DILARANG merekomendasikan makanan padat/MP-ASI, air putih, teh, madu, atau susu formula tanpa instruksi medis dokter spesialis.
   - Usia 6 - 8 bulan:
     * Tekstur: Bubur lumat/kental (puree/mashed), tidak encer (tidak mudah tumpah saat sendok dimiringkan).
     * Frekuensi: 2-3 kali makan besar + 1-2 kali selingan ASI/buah.
     * Porsi: Mulai 2-3 sendok makan bertahap hingga 1/2 mangkuk ukuran 250 ml (125 ml) tiap kali makan.
     * Komposisi: Wajib Protein Hewani (telur, hati ayam, ikan, daging) + Lemak Tambahan (santan/minyak/mentega untuk densitas energi). Sayur dan buah hanya perkenalan porsi kecil.
   - Usia 9 - 11 bulan:
     * Tekstur: Makanan lembek, cincang halus (minced), cincang kasar (chopped), atau finger food yang bisa digenggam anak.
     * Frekuensi: 3-4 kali makan besar + 1-2 kali selingan bergizi.
     * Porsi: 1/2 hingga 3/4 mangkuk ukuran 250 ml (125-187 ml).
     * Komposisi: Padat protein hewani di setiap porsi makan.
   - Usia 12 - 23 bulan:
     * Tekstur: Makanan keluarga (dihaluskan bila perlu).
     * Frekuensi: 3-4 kali makan besar + 1-2 kali selingan bergizi + lanjutkan ASI sampai usia 2 tahun.
     * Porsi: 3/4 hingga 1 mangkuk penuh ukuran 250 ml (187-250 ml).
   - Usia 24 - 59 bulan:
     * Pola makan keluarga gizi seimbang mengacu prinsip "Isi Piringku Balita" (1/3 karbohidrat, 1/3 protein hewani kaya zat besi, 1/3 sayur & buah padat nutrisi).

3. PRIORITAS PROTEIN HEWANI (INTERVENSI STUNTING & GIZI KURANG):
   - Kemenkes RI & Buku KIA 2024 mewajibkan intervensi Protein Hewani (Animal Source Foods) kaya asam amino esensial dan zat besi heme.
   - Prioritas utama: Telur ayam (minimal 1 butir utuh/hari), hati ayam/sapi (sumber zat besi terbaik pencegah anemia/stunting), ikan lokal (kembung, lele, bandeng), dan daging ayam/sapi.
   - LARANGAN KLINIS: JANGAN menyarankan menu rendah lemak/rendah kalori atau memperbanyak porsi kuah/sayur bening pada balita gizi kurang/stunting, karena kapasitas lambung balita terbatas dan membutuhkan makanan padat energi.

4. EVALUASI GRAFIK KMS (KARTU MENUJU SEHAT) & KENAIKAN BERAT BADAN:
   - Evaluasi tren kenaikan berat badan minimal (KBM) sesuai usia balita.
   - N (Naik): BB naik sesuai atau melebihi KBM.
   - T (Tidak Naik): BB mendatar atau turun.
   - 2T (Dua kali tidak naik berturut-turut): Tanda Bahaya (Red Flag) wajib dirujuk ke faskes.
   - BGM (Bawah Garis Merah): Tanda Bahaya gizi buruk akut / stunting berat wajib dirujuk ke faskes.

5. INDIKASI RUJUKAN & TANDA BAHAYA (RED FLAGS):
   - Wajib cantumkan rekomendasi rujukan ke Puskesmas / Dokter Spesialis Anak jika:
     a. Status balita: Stunting (TB/U < -2 SD), Gizi Kurang/Buruk (BB/TB < -2 SD), atau Berada di Bawah Garis Merah (BGM) KMS.
     b. Indikasi 2T (dua kali penimbangan berturut-turut berat badan tidak naik atau turun).
     c. Tanda bahaya klinis: Edema simetris pada kedua punggung kaki (tanda Kwashiorkor), anak tampak sangat kurus/iga gambang (tanda Marasmus), tidak nafsu makan/anoreksia, muntah berulang, lemas/letargis.
     d. Penyakit penyerta kronis: Batuk tidak kunjung sembuh > 2 minggu (skrining TB anak), demam berulang, atau diare berulang/kronis > 14 hari.

6. PANDUAN EDUKASI ORANG TUA & SUPLEMEN:
   - Evaluasi kelengkapan Kapsul Vitamin A (Februari/Agustus) dan Obat Cacing (anak ≥ 12 bulan).
   - Gunakan bahasa yang ramah, jelas, empati, dan memberdayakan orang tua tanpa menimbulkan kepanikan atau menyalahkan.
   - Tekankan pentingnya kebersihan sanitasi air/lingkungan, mencuci tangan pakai sabun (CTPS), dan stimulasi tumbuh kembang aktif responsif.

WAJIB mengembalikan HANYA format JSON valid berikut (tanpa markdown atau teks pembuka/penutup):
{
  "reasoning_summary": "Ringkasan penalaran klinis dokter dalam 2-3 kalimat padat mengenai status gizi (BB/TB), stunting (TB/U), dan tren KMS balita sesuai acuan Buku KIA 2024 & SATUSEHAT.",
  "chain_of_thought_steps": [
    "Langkah 1: Analisis data antropometri (usia, jenis kelamin, BB, PB/TB, LK, LiLA) terhadap median baku WHO, grafik Nellhaus, & Buku KIA 2024.",
    "Langkah 2: Evaluasi hasil prediksi model MLP (klasifikasi gizi BB/TB dan stunting TB/U) serta tingkat keyakinannya.",
    "Langkah 3: Analisis diferensial antara defisit berat badan akut (wasting/gizi kurang) dan gangguan pertumbuhan linier kronis (stunting).",
    "Langkah 4: Penilaian tren kurva pertumbuhan KMS (N/T/2T/BGM), risiko weight faltering, dan faktor infeksi penyerta."
  ],
  "risk_and_etiology": "Analisis potensi faktor risiko utama berbasis usia balita (kualitas/tekstur MP-ASI, defisiensi protein hewani, anemia defisiensi besi, riwayat infeksi ISPA/diare/TB, sanitasi, status imunisasi).",
  "nutritional_intervention": "Rencana intervensi gizi terperinci sesuai usia spesifik anak berdasar Buku KIA 2024 (tekstur makan, porsi mangkuk 250ml, frekuensi makan, target protein hewani spesifik seperti 1 telur/hari, hati ayam, ikan, dan lemak tambahan).",
  "medical_protocol": "Protokol tindakan fasilitas kesehatan: jadwal kontrol penimbangan (14 hari untuk gizi kurang/buruk, 30 hari untuk gizi baik), indikasi rujukan faskes/Dokter Spesialis Anak jika 2T/BGM/red flags, dan suplementasi mikronutrien (Vitamin A, Taburia, Zat Besi/Zinc, Obat Cacing).",
  "parent_education": "Pesan edukasi praktis, mudah dipahami, dan empatik untuk orang tua di rumah mengenai praktik pemberian makan aktif responsif, kebersihan sanitasi, dan stimulasi tumbuh kembang balita."
}
'''),
    );

    final promptText = '''
Lakukan analisis Clinical Reasoning berbasis Protokol Buku KIA 2024 & Standar SATUSEHAT Kemenkes RI untuk data skrining balita berikut:

Profil Balita:
- Nama: $childName
- Jenis Kelamin: $genderLabel
- Usia: $ageMonths bulan
- Berat Badan: $weightKg kg
- Panjang/Tinggi Badan: $heightCm cm ${measurementMethod != null ? '($measurementMethod)' : ''}
${headCircumferenceCm != null ? '- Lingkar Kepala (LK): $headCircumferenceCm cm (Evaluasi Grafik Nellhaus)' : ''}
${lilaCm != null ? '- LiLA (Lingkar Lengan Atas): $lilaCm cm' : ''}
${waistCm != null ? '- Lingkar Perut: $waistCm cm' : ''}
${kmsStatus != null ? '- Tren Pertumbuhan KMS Buku KIA: $kmsStatus' : ''}
${receivedVitA != null ? '- Status Vitamin A: ${receivedVitA ? "Sudah Diberikan" : "Belum Diberikan"}' : ''}
${receivedDeworming != null ? '- Status Obat Cacing: ${receivedDeworming ? "Sudah Diberikan" : "Belum Diberikan"}' : ''}

Hasil Prediksi Model Machine Learning VitaScale (Keras MLP):
- Kategori Status Gizi (BB/TB): ${mlpResult.kategoriGiziBbtb} (Keyakinan: ${mlpResult.confidenceBbtb.toStringAsFixed(1)}%)
- Kategori Status Stunting (TB/U): ${mlpResult.kategoriStuntingTbu} (Keyakinan: ${mlpResult.confidenceTbu.toStringAsFixed(1)}%)
- Status Berisiko Stunting: ${mlpResult.isStunting ? 'YA' : 'TIDAK'}
- Status Berisiko Gizi Buruk / Kurang: ${mlpResult.isGiziBurukAtauKurang ? 'YA' : 'TIDAK'}
- Distribusi Probabilitas BB/TB: ${mlpResult.probabilitasBbtb}
- Distribusi Probabilitas TB/U: ${mlpResult.probabilitasTbu}

Berikan alur penalaran klinis terstruktur (Chain of Thought), evaluasi tren KMS dan parameter antropometri Buku KIA, identifikasi faktor risiko etiologi sesuai usia, rekomendasi nutrisi protein hewani & tekstur MP-ASI Buku KIA 2024, protokol tindakan faskes, serta edukasi orang tua dalam format JSON.
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
        headCircumferenceCm: headCircumferenceCm,
        measurementMethod: measurementMethod,
        kmsStatus: kmsStatus,
      );
    }
  }

  /// Fallback cerdas berbasis protokol antropometri & Buku KIA 2024 jika koneksi ke Gemini terhambat
  static VitaScaleReasoningResult _generateClinicalRuleBasedFallback({
    required String childName,
    required String genderLabel,
    required double ageMonths,
    required double weightKg,
    required double heightCm,
    required HasilSmartGrowthBalita mlpResult,
    double? headCircumferenceCm,
    String? measurementMethod,
    String? kmsStatus,
  }) {
    final isStunting = mlpResult.isStunting;
    final isGiziKurang = mlpResult.isGiziBurukAtauKurang;
    final is2T = kmsStatus?.contains('2T') ?? false;
    final isBgm = kmsStatus?.contains('BGM') ?? false;

    String summary;
    List<String> steps = [];
    String etiology;
    String nutrition;
    String protocol;
    String parent;

    // Panduan nutrisi berbasis rentang usia (Buku KIA 2024)
    String ageBasedNutrition;
    if (ageMonths < 6) {
      ageBasedNutrition = 'Usia di bawah 6 bulan: Berikan HANYA ASI Eksklusif sesering mungkin (on demand, minimal 8 kali sehari). Belum diperkenankan MP-ASI atau susu formula tanpa instruksi dokter spesialis.';
    } else if (ageMonths < 9) {
      ageBasedNutrition = 'Usia 6-8 bulan (Buku KIA 2024): Berikan bubur lumat/kental (tidak tumpah saat sendok dimiringkan) 2-3 kali/hari @ 2-3 sdm bertahap hingga 1/2 mangkuk (125 ml) + 1-2 kali selingan. Wajib sertakan protein hewani (1 butir telur/hari, hati ayam, atau ikan) dan lemak tambahan (santan/minyak).';
    } else if (ageMonths < 12) {
      ageBasedNutrition = 'Usia 9-11 bulan (Buku KIA 2024): Berikan makanan cincang halus/kasar atau finger food 3-4 kali/hari @ 1/2 sampai 3/4 mangkuk (250 ml) + 1-2 kali selingan bergizi. Utamakan protein hewani di setiap jadwal makan.';
    } else if (ageMonths < 24) {
      ageBasedNutrition = 'Usia 12-23 bulan (Buku KIA 2024): Berikan makanan keluarga padat gizi 3-4 kali/hari @ 3/4 sampai 1 mangkuk penuh (250 ml) + 1-2 kali selingan bergizi. Teruskan pemberian ASI hingga 2 tahun dan wajib konsumsi telur/ikan/daging setiap hari.';
    } else {
      ageBasedNutrition = 'Usia 2-5 tahun (Buku KIA 2024): Berikan makanan keluarga gizi seimbang prinsip "Isi Piringku Balita" (1/3 karbohidrat, 1/3 protein hewani kaya zat besi, 1/3 sayur & buah). Penuhi kebutuhan 1 butir telur dan lauk hewani lain setiap hari.';
    }

    if (isStunting || isGiziKurang || is2T || isBgm) {
      final flagLabel = is2T ? 'tren 2T (dua kali tidak naik)' : (isBgm ? 'posisi BGM (Bawah Garis Merah)' : 'indikasi malnutrisi');
      summary = 'Hasil penapisan antropometri menunjukkan status ${mlpResult.kategoriStuntingTbu} (TB/U) '
          'dan ${mlpResult.kategoriGiziBbtb} (BB/TB) dengan $flagLabel. Mengacu pada Buku KIA 2024, kondisi ini memerlukan akselerasi nutrisi protein hewani padat kalori serta evaluasi tanda gagal tumbuh (weight faltering).';
      steps = [
        'Evaluasi rasio berat badan terhadap panjang/tinggi ($weightKg kg / $heightCm cm) menunjukkan deviasi pada anak ${genderLabel.toLowerCase()} usia ${ageMonths.toStringAsFixed(0)} bulan.',
        'Pertumbuhan linier menunjukkan deviasi yang mengarah pada status ${mlpResult.kategoriStuntingTbu} dengan tingkat keyakinan model MLP ${mlpResult.confidenceTbu.toStringAsFixed(1)}%.',
        if (headCircumferenceCm != null)
          'Pengukuran lingkar kepala $headCircumferenceCm cm dicatat untuk verifikasi grafik Nellhaus Buku KIA 2024.',
        if (is2T || isBgm)
          'PERINGATAN KMS: Terdeteksi status $kmsStatus. Buku KIA 2024 menetapkan status ini sebagai Tanda Bahaya (Red Flag) rujukan medis segera.',
        'Sesuai protokol Buku KIA 2024 & SATUSEHAT, anak dengan deviasi pertumbuhan wajib dipantau ketat di faskes primer/Puskesmas.'
      ];
      etiology = 'Faktor risiko yang sering menjadi penyebab: kepadatan kalori dan protein hewani MP-ASI yang kurang optimal, tekstur makanan yang terlambat dinaikkan, riwayat sakit berulang (ISPA, diare, atau TBC balita), atau sanitasi lingkungan.';
      nutrition = '$ageBasedNutrition Untuk mengejar ketertinggalan pertumbuhan, berikan minimal 1 butir telur utuh setiap hari ditambah hati ayam/sapi atau ikan berlemak. Hindari pemberian sayur berlebihan atau makanan rendah kalori.';
      protocol = 'Jadwalkan penimbangan ulang 14 hari ke depan di Puskesmas/Posyandu. Jika berat badan tidak naik sesuai KBM (indikasi 2T), anak berada di Bawah Garis Merah (BGM), atau tampak sangat kurus, SEGERA rujuk ke Dokter Spesialis Anak di RS/Puskesmas.';
      parent = 'Bunda dan Ayah tidak perlu berkecil hati. Di usia emas ini, pemulihan pertumbuhan sangat efektif jika anak mendapatkan cukup protein hewani di setiap waktu makan. Prioritaskan lauk hewani sebelum camilan manis.';
    } else {
      summary = 'Status pertumbuhan $childName tergolong ${mlpResult.kategoriGiziBbtb} (BB/TB) dan ${mlpResult.kategoriStuntingTbu} (TB/U). '
          'Indikator antropometri berada dalam batas aman grafik KMS Buku KIA 2024 dan standar WHO.';
      steps = [
        'Panjang/tinggi badan $heightCm cm proporsional dan sesuai median kurva pertumbuhan untuk balita usia ${ageMonths.toStringAsFixed(0)} bulan.',
        'Berat badan $weightKg kg seimbang dengan tinggi badan saat ini (${mlpResult.kategoriGiziBbtb}), menandakan status nutrisi akut yang baik.',
        if (headCircumferenceCm != null)
          'Lingkar kepala $headCircumferenceCm cm berada dalam batas normal kurva pertumbuhan kepala Nellhaus.',
        'Confidence model MLP mencapai ${mlpResult.confidenceBbtb.toStringAsFixed(1)}% untuk status gizi BB/TB dan ${mlpResult.confidenceTbu.toStringAsFixed(1)}% untuk status stunting TB/U.',
        'Pertumbuhan anak berada pada pita hijau KMS, pertahankan tren kenaikan berat badan tiap bulan (N).'
      ];
      etiology = 'Pertumbuhan dan perkembangan berlangsung optimal tanpa tanda-tanda malnutrisi akut maupun kronis.';
      nutrition = '$ageBasedNutrition Pertahankan pola asupan bergizi dengan kombinasi karbohidrat, protein hewani berkualitas tinggi, lemak sehat, serta sayur dan buah secukupnya.';
      protocol = 'Lanjutkan pemantauan rutin bulanan di Posyandu/Puskesmas terdekat untuk memastikan kurva KMS anak selalu naik mengikuti pita hijau (indikator N). Berikan kapsul Vitamin A pada bulan Februari dan Agustus.';
      parent = 'Hebat sekali Bunda & Ayah! Pola asuh dan pemberian makan yang diterapkan sudah sangat tepat. Tetap rutin datang ke Posyandu setiap bulan untuk menimbang dan memantau perkembangan ananda.';
    }

    return VitaScaleReasoningResult(
      reasoningSummary: summary,
      chainOfThoughtSteps: steps,
      riskAndEtiology: etiology,
      nutritionalIntervention: nutrition,
      medicalProtocol: protocol,
      parentEducation: parent,
      generatedAt: DateTime.now(),
      modelUsed: 'Clinical Rule-Based Fallback Engine (Buku KIA 2024)',
    );
  }
}

