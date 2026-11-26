import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ============================================================================
/// KONFIGURASI SERVER FASTAPI & CLOUD VITASCALE
/// ============================================================================
class VitaScaleApiConfig {
  /// Default base URL mengarah ke hosting cloud Vercel aktif:
  /// https://vitascalemapotech.vercel.app/
  /// Cadangan / lokal: 'http://127.0.0.1:8000' atau 'http://10.0.2.2:8000'
  static String baseUrl = 'https://vitascalemapotech.vercel.app';

  /// URL dedicated Vercel untuk pemrosesan Computer Vision (PCV 7 Tahap):
  static String pcvBaseUrl = 'https://pcvmapotechs5.vercel.app';

  static const String smartGrowthEndpoint = '/prediksi/smart-growth';
  static const String giziEndpoint = '/prediksi/gizi';
  static const String stuntingEndpoint = '/prediksi/stunting';
  static const String longitudinalEndpoint = '/prediksi';
  static const String healthEndpoint = '/health';
  static const String measureEndpoint = '/measure';
}

/// ============================================================================
/// MODEL INPUT & OUTPUT: SMART GROWTH (4 FITUR UTAMA)
/// Endpoint: POST /prediksi/smart-growth
/// ============================================================================
class InputSmartGrowthBalita {
  final int jk; // 0 = Laki-laki, 1 = Perempuan
  final double usiaBulan;
  final double berat;
  final double tinggi;

  const InputSmartGrowthBalita({
    required this.jk,
    required this.usiaBulan,
    required this.berat,
    required this.tinggi,
  });

  Map<String, dynamic> toJson() => {
        'JK': jk,
        'Usia_Bulan': usiaBulan,
        'Berat': berat,
        'Tinggi': tinggi,
      };
}

class HasilSmartGrowthBalita {
  final String kategoriGiziBbtb;
  final String kategoriStuntingTbu;
  final double confidenceBbtb;
  final double confidenceTbu;
  final Map<String, double> probabilitasBbtb;
  final Map<String, double> probabilitasTbu;
  final bool isStunting;
  final bool isGiziBurukAtauKurang;
  final Map<String, dynamic> inputDiproses;

  const HasilSmartGrowthBalita({
    required this.kategoriGiziBbtb,
    required this.kategoriStuntingTbu,
    required this.confidenceBbtb,
    required this.confidenceTbu,
    required this.probabilitasBbtb,
    required this.probabilitasTbu,
    required this.isStunting,
    required this.isGiziBurukAtauKurang,
    required this.inputDiproses,
  });

  factory HasilSmartGrowthBalita.fromJson(Map<String, dynamic> json) {
    return HasilSmartGrowthBalita(
      kategoriGiziBbtb: json['kategori_gizi_bbtb']?.toString() ?? 'Normal',
      kategoriStuntingTbu: json['kategori_stunting_tbu']?.toString() ?? 'Normal',
      confidenceBbtb: (json['confidence_bbtb'] as num?)?.toDouble() ?? 0.0,
      confidenceTbu: (json['confidence_tbu'] as num?)?.toDouble() ?? 0.0,
      probabilitasBbtb: (json['probabilitas_bbtb'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      probabilitasTbu: (json['probabilitas_tbu'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      isStunting: json['is_stunting'] as bool? ?? false,
      isGiziBurukAtauKurang: json['is_gizi_buruk_atau_kurang'] as bool? ?? false,
      inputDiproses: (json['input_diproses'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// ============================================================================
/// MODEL INPUT & OUTPUT: LONGITUDINAL (2 BULAN BERURUTAN)
/// Endpoint: POST /prediksi
/// ============================================================================
class InputPrediksiLongitudinal {
  final double beratPrev;
  final double tinggiPrev;
  final double zsTbuPrev;
  final double zsBbtbPrev;

  final String jk; // 'L' atau 'P'
  final double usiaBulanCurr;
  final double beratCurr;
  final double tinggiCurr;
  final double lilaCurr;
  final double zsTbuCurr;
  final double zsBbtbCurr;
  final String naikBbCurr; // 'Ya' atau 'Tidak'

  final double? deltaBb;
  final double? deltaTb;
  final double? deltaDays;
  final double? deltaZsTbu;
  final double? deltaZsBbtb;

  const InputPrediksiLongitudinal({
    required this.beratPrev,
    required this.tinggiPrev,
    required this.zsTbuPrev,
    required this.zsBbtbPrev,
    required this.jk,
    required this.usiaBulanCurr,
    required this.beratCurr,
    required this.tinggiCurr,
    required this.lilaCurr,
    required this.zsTbuCurr,
    required this.zsBbtbCurr,
    required this.naikBbCurr,
    this.deltaBb,
    this.deltaTb,
    this.deltaDays,
    this.deltaZsTbu,
    this.deltaZsBbtb,
  });

  Map<String, dynamic> toJson() => {
        'Berat_Prev': beratPrev,
        'Tinggi_Prev': tinggiPrev,
        'ZS_TBU_Prev': zsTbuPrev,
        'ZS_BBTB_Prev': zsBbtbPrev,
        'JK': jk,
        'Usia_Bulan_Curr': usiaBulanCurr,
        'Berat_Curr': beratCurr,
        'Tinggi_Curr': tinggiCurr,
        'LiLA_Curr': lilaCurr,
        'ZS_TBU_Curr': zsTbuCurr,
        'ZS_BBTB_Curr': zsBbtbCurr,
        'Naik_BB_Curr': naikBbCurr,
        if (deltaBb != null) 'Delta_BB': deltaBb,
        if (deltaTb != null) 'Delta_TB': deltaTb,
        if (deltaDays != null) 'Delta_Days': deltaDays,
        if (deltaZsTbu != null) 'Delta_ZS_TBU': deltaZsTbu,
        if (deltaZsBbtb != null) 'Delta_ZS_BBTB': deltaZsBbtb,
      };
}

class HasilPrediksiLongitudinal {
  final double probabilitasStunting;
  final double probabilitasGiziBuruk;
  final bool risikoStunting;
  final bool risikoGiziBuruk;
  final String statusStunting;
  final String statusGizi;
  final double confidenceStunting;
  final double confidenceGizi;
  final Map<String, dynamic> inputDiproses;

  const HasilPrediksiLongitudinal({
    required this.probabilitasStunting,
    required this.probabilitasGiziBuruk,
    required this.risikoStunting,
    required this.risikoGiziBuruk,
    required this.statusStunting,
    required this.statusGizi,
    required this.confidenceStunting,
    required this.confidenceGizi,
    required this.inputDiproses,
  });

  factory HasilPrediksiLongitudinal.fromJson(Map<String, dynamic> json) {
    return HasilPrediksiLongitudinal(
      probabilitasStunting: (json['probabilitas_stunting'] as num?)?.toDouble() ?? 0.0,
      probabilitasGiziBuruk: (json['probabilitas_gizi_buruk'] as num?)?.toDouble() ?? 0.0,
      risikoStunting: json['risiko_stunting'] as bool? ?? false,
      risikoGiziBuruk: json['risiko_gizi_buruk'] as bool? ?? false,
      statusStunting: json['status_stunting']?.toString() ?? 'Normal',
      statusGizi: json['status_gizi']?.toString() ?? 'Gizi Normal',
      confidenceStunting: (json['confidence_stunting'] as num?)?.toDouble() ?? 0.0,
      confidenceGizi: (json['confidence_gizi'] as num?)?.toDouble() ?? 0.0,
      inputDiproses: (json['input_diproses'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// ============================================================================
/// SERVICE CLIENT VITASCALE API
/// ============================================================================
class VitaScaleApiService {
  static final http.Client _client = http.Client();

  /// Cek kesehatan server backend FastAPI dan kesiapan model MLP
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final uri = Uri.parse('${VitaScaleApiConfig.baseUrl}${VitaScaleApiConfig.healthEndpoint}');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isOnline = data['status'] == 'ok' || data['status'] == 'online';
        final hasStunting = data['model_stunting'] == true ||
            (data['model'] is List && (data['model'] as List).any((m) => m.toString().contains('Stunting')));
        final hasGizi = data['model_gizi'] == true ||
            (data['model'] is List && (data['model'] as List).any((m) => m.toString().contains('Gizi')));

        return {
          'isOnline': isOnline,
          'modelStunting': hasStunting,
          'modelGizi': hasGizi,
          'engine': data['engine'] ?? 'MLP Inference Engine',
          'message': 'Server cloud Vercel aktif & model inferensi siap',
        };
      }
      return {
        'isOnline': false,
        'message': 'Server merespons kode ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('[VitaScaleApi] Health check error: $e');
      return {
        'isOnline': false,
        'message': 'Gagal menghubungi server di ${VitaScaleApiConfig.baseUrl}. Pastikan koneksi internet aktif.',
      };
    }
  }

  /// Prediksi status antropometri Smart Growth (4 Fitur: JK, Usia, BB, TB)
  static Future<HasilSmartGrowthBalita> prediksiSmartGrowth(
    InputSmartGrowthBalita input,
  ) async {
    // 1. Coba endpoint split Vercel (/prediksi/gizi & /prediksi/stunting) secara paralel
    try {
      final giziUri = Uri.parse('${VitaScaleApiConfig.baseUrl}${VitaScaleApiConfig.giziEndpoint}');
      final stuntingUri = Uri.parse('${VitaScaleApiConfig.baseUrl}${VitaScaleApiConfig.stuntingEndpoint}');

      final responses = await Future.wait([
        _client.post(
          giziUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(input.toJson()),
        ).timeout(const Duration(seconds: 12)),
        _client.post(
          stuntingUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'JK': input.jk,
            'Usia_Bulan': input.usiaBulan,
            'Tinggi': input.tinggi,
          }),
        ).timeout(const Duration(seconds: 12)),
      ]);

      final giziRes = responses[0];
      final stuntingRes = responses[1];

      if (giziRes.statusCode == 200 && stuntingRes.statusCode == 200) {
        final giziData = jsonDecode(giziRes.body) as Map<String, dynamic>;
        final stuntingData = jsonDecode(stuntingRes.body) as Map<String, dynamic>;

        final katGizi = giziData['prediksi']?.toString() ?? 'Normal';
        final katStunting = stuntingData['prediksi']?.toString() ?? 'Normal';

        final skorGizi = (giziData['skor_model'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {};
        final skorStunting = (stuntingData['skor_model'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {};

        double confGizi = 0.0;
        if (skorGizi.containsKey(katGizi)) {
          confGizi = (skorGizi[katGizi] ?? 0.0) * 100;
        } else if (skorGizi.isNotEmpty) {
          confGizi = skorGizi.values.reduce((a, b) => a > b ? a : b) * 100;
        }

        double confStunting = 0.0;
        if (skorStunting.containsKey(katStunting)) {
          confStunting = (skorStunting[katStunting] ?? 0.0) * 100;
        } else if (skorStunting.isNotEmpty) {
          confStunting = skorStunting.values.reduce((a, b) => a > b ? a : b) * 100;
        }

        final isStunting = katStunting.toLowerCase().contains('pendek');
        final isGiziBuruk = katGizi.toLowerCase().contains('kurang') ||
            katGizi.toLowerCase().contains('buruk');

        return HasilSmartGrowthBalita(
          kategoriGiziBbtb: katGizi,
          kategoriStuntingTbu: katStunting,
          confidenceBbtb: confGizi,
          confidenceTbu: confStunting,
          probabilitasBbtb: skorGizi,
          probabilitasTbu: skorStunting,
          isStunting: isStunting,
          isGiziBurukAtauKurang: isGiziBuruk,
          inputDiproses: input.toJson(),
        );
      }
    } catch (e) {
      debugPrint('[VitaScaleApi] Vercel split endpoints error: $e. Mencoba fallback ke unified endpoint...');
    }

    // 2. Fallback ke endpoint unified /prediksi/smart-growth bila server menggunakan single endpoint
    final uri = Uri.parse('${VitaScaleApiConfig.baseUrl}${VitaScaleApiConfig.smartGrowthEndpoint}');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(input.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HasilSmartGrowthBalita.fromJson(json);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? error['error'] ?? 'Prediksi gagal dengan kode ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VitaScaleApi] prediksiSmartGrowth fallback error: $e');
      rethrow;
    }
  }

  /// Prediksi risiko stunting & gizi buruk longitudinal (2 Bulan)
  static Future<HasilPrediksiLongitudinal> prediksiLongitudinal(
    InputPrediksiLongitudinal input,
  ) async {
    final uri = Uri.parse('${VitaScaleApiConfig.baseUrl}${VitaScaleApiConfig.longitudinalEndpoint}');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(input.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HasilPrediksiLongitudinal.fromJson(json);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Prediksi longitudinal gagal dengan kode ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VitaScaleApi] prediksiLongitudinal error: $e');
      rethrow;
    }
  }

  /// ============================================================================
  /// PENGUKURAN PANJANG/TINGGI OBJEK VIA PCV (7 TAHAP)
  /// Endpoint: POST /measure
  /// ============================================================================
  static Future<Map<String, dynamic>> ukurTinggiObjek({
    String? base64Image,
    double? h,
    double? ppm100,
    double? t,
    double? k1,
    double? skala,
    bool? useRoi,
    bool? useK1,
    String? preset,
  }) async {
    final targetUrl = VitaScaleApiConfig.pcvBaseUrl.isNotEmpty
        ? '${VitaScaleApiConfig.pcvBaseUrl}${VitaScaleApiConfig.measureEndpoint}'
        : '${VitaScaleApiConfig.baseUrl}${VitaScaleApiConfig.measureEndpoint}';
    final uri = Uri.parse(targetUrl);

    try {
      final payload = <String, dynamic>{
        if (base64Image != null && base64Image.isNotEmpty) 'image': base64Image,
        'H': ?h,
        'PPM100': ?ppm100,
        't': ?t,
        'k1': ?k1,
        'skala': ?skala,
        'use_roi': ?useRoi,
        'use_k1': ?useK1,
        'preset': ?preset,
      };

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>?;
        return {
          'status': 'error',
          'message': err?['error'] ?? err?['message'] ?? 'Gagal memproses gambar (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[VitaScaleApi] ukurTinggiObjek error: $e');
      return {
        'status': 'error',
        'message': 'Gagal menghubungi server pengukuran di $targetUrl: $e',
      };
    }
  }
}

