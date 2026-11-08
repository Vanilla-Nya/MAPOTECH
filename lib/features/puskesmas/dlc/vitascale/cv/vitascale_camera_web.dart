// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use, undefined_function, undefined_method

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'marker_measurement.dart';

typedef OnCaptureCallback = void Function(CvMeasurementResult result);
typedef OnCameraStatusChanged = void Function(bool isReady, String? label);

class CameraDeviceOption {
  final String deviceId;
  final String label;

  CameraDeviceOption({required this.deviceId, required this.label});

  bool get isVirtual {
    final l = label.toLowerCase();
    return l.contains('droidcam') ||
        l.contains('obs') ||
        l.contains('virtual') ||
        l.contains('manycam') ||
        l.contains('vysor') ||
        l.contains('iriun') ||
        l.contains('splitcam');
  }
}

class VitaScaleCameraWidget extends StatefulWidget {
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
  State<VitaScaleCameraWidget> createState() => _VitaScaleCameraWidgetState();
}

class _VitaScaleCameraWidgetState extends State<VitaScaleCameraWidget> {
  late final String _viewType;
  late final String _elementId;
  late final html.VideoElement _videoElement;
  html.MediaStream? _mediaStream;

  List<CameraDeviceOption> _devices = [];
  String? _selectedDeviceId;
  String _activeCameraLabel = 'Kamera Aktif';

  bool _isInitializing = true;
  bool _isOpenCvLoading = false;
  bool _isOpenCvReady = false;
  bool _isProcessingFrame = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final uniqueId = DateTime.now().microsecondsSinceEpoch;
    _viewType = 'vitascale-camera-view-$uniqueId';
    _elementId = 'vitascale-video-$uniqueId';

    _videoElement = html.VideoElement()
      ..id = _elementId
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.backgroundColor = '#0B0F17'
      ..style.border = 'none'
      ..style.pointerEvents = 'none';

    _videoElement.onLoadedMetadata.listen((_) {
      _videoElement.play().catchError((_) {});
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _videoElement);

    _initCamera();
    _loadOpenCv();
  }

  /// Memuat OpenCV.js dari berkas lokal yang tervendor di web/vitascale/opencv.js
  Future<void> _loadOpenCv() async {
    setState(() => _isOpenCvLoading = true);
    try {
      if (js_util.hasProperty(html.window, 'VitaScaleCV')) {
        final vsCv = js_util.getProperty(html.window, 'VitaScaleCV');
        if (vsCv != null) {
          final isReady = js_util.callMethod(vsCv, 'isReady', []) as bool? ?? false;
          if (isReady) {
            if (mounted) setState(() { _isOpenCvReady = true; _isOpenCvLoading = false; });
            return;
          }
          final promise = js_util.callMethod(vsCv, 'load', ['vitascale/opencv.js']);
          await js_util
              .promiseToFuture(promise)
              .timeout(const Duration(seconds: 6));
          if (mounted) {
            setState(() {
              _isOpenCvReady = true;
              _isOpenCvLoading = false;
            });
          }
          return;
        }
      }
      if (mounted) setState(() => _isOpenCvLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOpenCvLoading = false;
          _isOpenCvReady = false;
        });
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      await _enumerateDevices().timeout(const Duration(seconds: 2), onTimeout: () {});
      if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty) {
        await _startCamera(_selectedDeviceId);
      } else {
        await _startCamera();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Tidak dapat mendeteksi webcam USB.';
        });
        widget.onStatusChanged(false, _errorMessage);
      }
    }
  }

  Future<void> _enumerateDevices() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) return;
    try {
      final rawList = await js_util
          .promiseToFuture<dynamic>(
            js_util.callMethod(mediaDevices, 'enumerateDevices', []),
          )
          .timeout(const Duration(seconds: 2));
      if (rawList == null) return;

      final count = js_util.getProperty(rawList, 'length') as int? ?? 0;
      final List<CameraDeviceOption> parsed = [];

      for (int i = 0; i < count; i++) {
        final dev = js_util.getProperty(rawList, '$i') ?? js_util.callMethod(rawList, 'item', [i]);
        if (dev != null) {
          final kind = js_util.getProperty(dev, 'kind')?.toString() ?? '';
          if (kind == 'videoinput') {
            final id = js_util.getProperty(dev, 'deviceId')?.toString() ?? '';
            final rawLabel = js_util.getProperty(dev, 'label')?.toString() ?? '';
            final label = rawLabel.isNotEmpty ? rawLabel : 'Kamera ${parsed.length + 1}';
            parsed.add(CameraDeviceOption(deviceId: id, label: label));
          }
        }
      }

      if (mounted && parsed.isNotEmpty) {
        CameraDeviceOption? preferred;
        for (final d in parsed) {
          if (!d.isVirtual) {
            preferred = d;
            break;
          }
        }
        setState(() {
          _devices = parsed;
          _selectedDeviceId ??= preferred?.deviceId ?? parsed.first.deviceId;
        });
      }
    } catch (_) {}
  }

  Future<void> _startCamera([String? targetDeviceId]) async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      const err = 'Akses webcam tidak didukung di browser ini atau context tidak aman (Gunakan HTTPS atau localhost).';
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = err;
        });
        widget.onStatusChanged(false, err);
      }
      return;
    }

    try {
      _stopCurrentStream();
      html.MediaStream? stream;
      final devId = targetDeviceId ?? _selectedDeviceId;

      if (devId != null && devId.isNotEmpty) {
        try {
          final constraints = js_util.jsify({
            'video': {
              'deviceId': {'exact': devId},
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            },
            'audio': false,
          });
          final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
          stream = await js_util
              .promiseToFuture<html.MediaStream>(promise)
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          try {
            final constraints = js_util.jsify({
              'video': {'deviceId': devId},
              'audio': false,
            });
            final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
            stream = await js_util
                .promiseToFuture<html.MediaStream>(promise)
                .timeout(const Duration(seconds: 3));
          } catch (_) {}
        }
      }

      if (stream == null) {
        final constraints = js_util.jsify({
          'video': {'width': {'ideal': 1280}, 'height': {'ideal': 720}},
          'audio': false,
        });
        final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
        stream = await js_util
            .promiseToFuture<html.MediaStream>(promise)
            .timeout(const Duration(seconds: 4));
      }

      _mediaStream = stream;
      _videoElement.srcObject = stream;
      // Memulai pemutaran video secara asinkron tanpa memblokir thread
      _videoElement.play().catchError((_) {});

      _enumerateDevices().timeout(const Duration(seconds: 2), onTimeout: () {});

      String activeLabel = 'Webcam USB';
      try {
        final tracks = stream?.getVideoTracks() ?? [];
        if (tracks.isNotEmpty && tracks.first.label != null && tracks.first.label!.isNotEmpty) {
          activeLabel = tracks.first.label!;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activeCameraLabel = activeLabel;
          if (targetDeviceId != null) _selectedDeviceId = targetDeviceId;
          _isInitializing = false;
          _errorMessage = null;
        });
        widget.onStatusChanged(true, activeLabel);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Waktu pencarian webcam habis (4 detik). Kamera fisik tidak terdeteksi atau izin browser belum diberikan.';
        });
        widget.onStatusChanged(false, _errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Gagal mengakses kamera: $e';
        });
        widget.onStatusChanged(false, _errorMessage);
      }
    }
  }

  void _stopCurrentStream() {
    if (_mediaStream != null) {
      try {
        for (final track in _mediaStream!.getTracks()) {
          track.stop();
        }
      } catch (_) {}
      _mediaStream = null;
    }
    try {
      _videoElement.pause();
      _videoElement.srcObject = null;
    } catch (_) {}
  }

  /// Pemicu capture frame untuk diproses oleh OpenCV.js
  Future<void> captureAndMeasure() async {
    if (_isProcessingFrame) return;

    if (!_isOpenCvReady) {
      await _loadOpenCv();
      if (!_isOpenCvReady) {
        widget.onMeasured(CvMeasurementResult.failed(
          'Engine OpenCV.js belum selesai dimuat. Tunggu beberapa saat atau periksa file web/vitascale/opencv.js.',
        ));
        return;
      }
    }

    setState(() => _isProcessingFrame = true);

    try {
      if (js_util.hasProperty(html.window, 'VitaScaleCV')) {
        final vsCv = js_util.getProperty(html.window, 'VitaScaleCV');
        final rawJson = js_util.callMethod(
          vsCv,
          'measureVideo',
          [_videoElement, null, true],
        )?.toString();

        if (rawJson != null && rawJson.isNotEmpty) {
          final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
          final result = CvMeasurementResult.fromJson(decoded);
          widget.onMeasured(result);
          return;
        }
      }
      widget.onMeasured(CvMeasurementResult.failed('Gagal memanggil modul Computer Vision VitaScaleCV.'));
    } catch (e) {
      widget.onMeasured(CvMeasurementResult.failed('Kesalahan saat memproses frame kamera: $e'));
    } finally {
      if (mounted) setState(() => _isProcessingFrame = false);
    }
  }

  @override
  void dispose() {
    _stopCurrentStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFF0F141C),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 40),
              const SizedBox(height: 12),
              Text(
                'Kamera Tidak Terhubung',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _startCamera(),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Coba Lagi', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1ABC9C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (widget.onSimulateFixture != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onSimulateFixture,
                      icon: const Icon(Icons.science_rounded, size: 14, color: Colors.white70),
                      label: const Text('Simulasi Fixture CV', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),

        // Visual overlay border & guideline papan ukur
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.35), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Header status overlay
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _activeCameraLabel,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_isOpenCvLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Memuat OpenCV...',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Bottom Controls: Switch camera & Capture Trigger
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_devices.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Pilih Perangkat Webcam USB',
                  onSelected: (devId) => _startCamera(devId),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  itemBuilder: (ctx) => _devices.map((d) {
                    final isSel = d.deviceId == _selectedDeviceId;
                    return PopupMenuItem<String>(
                      value: d.deviceId,
                      child: Row(
                        children: [
                          Icon(
                            isSel ? Icons.check_circle_rounded : Icons.videocam_outlined,
                            size: 16,
                            color: isSel ? const Color(0xFF2ECC71) : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSel ? const Color(0xFF2ECC71) : Colors.white,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cameraswitch_rounded, size: 14, color: Color(0xFF1ABC9C)),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            _activeCameraLabel,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isProcessingFrame ? null : captureAndMeasure,
                icon: _isProcessingFrame
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_rounded, size: 16),
                label: Text(
                  _isProcessingFrame ? 'Memproses...' : 'Capture Ukuran',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1ABC9C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),

        if (_isInitializing)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F141C),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1ABC9C)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Menghubungkan Webcam USB...',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mencari perangkat video input kamera pada browser...',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10),
                    ),
                    if (widget.onSimulateFixture != null) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isInitializing = false;
                            _errorMessage = null;
                          });
                          widget.onSimulateFixture!();
                        },
                        icon: const Icon(Icons.science_rounded, size: 14),
                        label: Text(
                          'Lewati & Gunakan Simulasi Fixture CV',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ABC9C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
