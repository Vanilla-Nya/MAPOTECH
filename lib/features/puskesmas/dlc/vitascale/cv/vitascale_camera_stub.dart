import 'package:flutter/material.dart';
import 'marker_measurement.dart';

typedef OnCaptureCallback = void Function(CvMeasurementResult result);
typedef OnCameraStatusChanged = void Function(bool isReady, String? label);

class VitaScaleCameraWidget extends StatelessWidget {
  final OnCaptureCallback onMeasured;
  final OnCameraStatusChanged onStatusChanged;
  final VoidCallback? onSimulateFixture;

  const VitaScaleCameraWidget({
    super.key,
    required this.onMeasured,
    required this.onStatusChanged,
    this.onSimulateFixture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F141C),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_rounded, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Kamera Computer Vision Browser (Web Only)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fitur pemrosesan OpenCV.js zero-install aktif pada platform Web (Chrome/Edge/Firefox). '
            'Pada lingkungan non-web, Anda dapat menguji alur menggunakan fixture sintetis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (onSimulateFixture != null)
            ElevatedButton.icon(
              onPressed: onSimulateFixture,
              icon: const Icon(Icons.science_rounded, size: 16),
              label: const Text('Gunakan Data Fixture Sintetis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
