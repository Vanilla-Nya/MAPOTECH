/// Hasil evaluasi Computer Vision deteksi marker papan ukur
class CvMeasurementResult {
  final bool ok;
  final double? valueCm;
  final List<String> reasons;
  final Map<String, dynamic> diagnostics;
  final String? previewDataUrl;

  const CvMeasurementResult({
    required this.ok,
    this.valueCm,
    this.reasons = const [],
    this.diagnostics = const {},
    this.previewDataUrl,
  });

  factory CvMeasurementResult.failed(String reason) {
    return CvMeasurementResult(
      ok: false,
      reasons: [reason],
    );
  }

  factory CvMeasurementResult.fromJson(Map<String, dynamic> json) {
    return CvMeasurementResult(
      ok: json['ok'] == true,
      valueCm: (json['valueCm'] as num?)?.toDouble(),
      reasons: (json['reasons'] as List?)?.map((e) => e.toString()).toList() ?? [],
      diagnostics: (json['diagnostics'] as Map?)?.cast<String, dynamic>() ?? {},
      previewDataUrl: json['previewDataUrl']?.toString(),
    );
  }
}
