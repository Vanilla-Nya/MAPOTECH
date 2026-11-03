import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ============================================================================
/// KONFIGURASI SERVER FASTAPI VITASCALE
/// ============================================================================
class VitaScaleApiConfig {
  /// Default base URL.
  /// Web & Windows: 'http://127.0.0.1:8000'
  /// Android Emulator: 'http://10.0.2.2:8000'
  static String baseUrl = 'http://127.0.0.1:8000';

  static const String smartGrowthEndpoint = '/prediksi/smart-growth';
  static const String longitudinalEndpoint = '/prediksi';
  static const String healthEndpoint = '/health';
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
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'isOnline': data['status'] == 'ok',
          'modelStunting': data['model_stunting'] == true,
          'modelGizi': data['model_gizi'] == true,
          'preprocessor': data['preprocessor'] == true,
          'message': 'Server terhubung & model siap',
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
        'message': 'Gagal menghubungi server di ${VitaScaleApiConfig.baseUrl}. Pastikan python main.py aktif.',
      };
    }
  }

  /// Prediksi status antropometri Smart Growth (4 Fitur: JK, Usia, BB, TB)
  static Future<HasilSmartGrowthBalita> prediksiSmartGrowth(
    InputSmartGrowthBalita input,
  ) async {
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
        throw Exception(error['detail'] ?? 'Prediksi gagal dengan kode ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VitaScaleApi] prediksiSmartGrowth error: $e');
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
}

