import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'pcv_camera_capture_types.dart';
import 'pcv_photo_processing_web.dart' show encodePcvCanvasJpeg;

/// Opens a live local webcam dialog in the browser and returns a captured JPEG snapshot.
Future<PcvCapturedPhoto?> capturePcvCameraSnapshot(BuildContext context) {
  return showDialog<PcvCapturedPhoto>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WebPcvCameraDialog(),
  );
}

class _CameraDeviceInfo {
  final String deviceId;
  final String label;

  const _CameraDeviceInfo({
    required this.deviceId,
    required this.label,
  });

  bool get isVirtual => _isVirtualCameraLabel(label);
}

bool _isVirtualCameraLabel(String label) {
  final lower = label.toLowerCase();
  return lower.contains('droidcam') ||
      lower.contains('obs') ||
      lower.contains('virtual') ||
      lower.contains('manycam') ||
      lower.contains('vysor') ||
      lower.contains('iriun') ||
      lower.contains('splitcam');
}

class _WebPcvCameraDialog extends StatefulWidget {
  const _WebPcvCameraDialog();

  @override
  State<_WebPcvCameraDialog> createState() => _WebPcvCameraDialogState();
}

class _WebPcvCameraDialogState extends State<_WebPcvCameraDialog> {
  late final String _viewType;
  late final String _elementId;
  late final web.HTMLVideoElement _videoElement;

  web.MediaStream? _mediaStream;
  StreamSubscription<web.Event>? _loadedMetadataSub;
  StreamSubscription<web.Event>? _canPlaySub;

  List<_CameraDeviceInfo> _devices = [];
  String? _selectedDeviceId;
  String _activeCameraLabel = 'Kamera Lokal';

  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _captureWarning;

  @override
  void initState() {
    super.initState();
    final uniqueId = DateTime.now().microsecondsSinceEpoch;
    _viewType = 'pcv-local-camera-view-$uniqueId';
    _elementId = 'pcv-local-camera-video-$uniqueId';

    _videoElement = web.HTMLVideoElement()
      ..id = _elementId
      ..autoplay = true
      ..muted = true
      ..defaultMuted = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = '#0B0F17'
      ..style.border = 'none'
      ..style.pointerEvents = 'none';

    _loadedMetadataSub = _videoElement.onLoadedMetadata.listen((_) {
      _playVideoSafely();
    });
    _canPlaySub = _videoElement.onCanPlay.listen((_) {
      _playVideoSafely();
      if (mounted && !_isDisposed && _isInitializing && _videoElement.videoWidth > 0) {
        setState(() => _isInitializing = false);
      }
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement,
    );

    _initCamera();
  }

  void _playVideoSafely() {
    try {
      _videoElement.play().toDart.catchError((_) => null);
    } catch (_) {}
  }

  web.MediaDevices? _getMediaDevices() {
    if (!web.window.isSecureContext) return null;
    final navigatorObj = web.window.navigator as JSObject;
    if (!navigatorObj.hasProperty('mediaDevices'.toJS).toDart) {
      return null;
    }
    return web.window.navigator.mediaDevices;
  }

  Future<void> _initCamera() async {
    await _enumerateDevices();
    if (_isDisposed || !mounted) return;
    await _startCamera(_selectedDeviceId);
  }

  Future<void> _enumerateDevices() async {
    final mediaDevices = _getMediaDevices();
    if (mediaDevices == null) return;

    try {
      final rawDevices = await mediaDevices
          .enumerateDevices()
          .toDart
          .timeout(const Duration(seconds: 3));
      final list = rawDevices.toDart;
      final parsed = <_CameraDeviceInfo>[];

      for (final dev in list) {
        if (dev.kind == 'videoinput') {
          final id = dev.deviceId;
          final label = dev.label.isNotEmpty
              ? dev.label
              : 'Kamera ${parsed.length + 1}';
          parsed.add(_CameraDeviceInfo(deviceId: id, label: label));
        }
      }

      if (!mounted || _isDisposed || parsed.isEmpty) return;

      _CameraDeviceInfo? preferred;
      for (final d in parsed) {
        if (!d.isVirtual && d.deviceId.isNotEmpty) {
          preferred = d;
          break;
        }
      }
      preferred ??= parsed.firstWhere(
        (d) => d.deviceId.isNotEmpty,
        orElse: () => parsed.first,
      );

      setState(() {
        _devices = parsed;
        if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
          _selectedDeviceId = preferred!.deviceId.isNotEmpty
              ? preferred.deviceId
              : null;
        }
      });
    } catch (_) {}
  }

  Future<web.MediaStream> _requestStream(
    web.MediaDevices mediaDevices,
    JSAny videoConstraint,
  ) {
    final constraints = web.MediaStreamConstraints(
      video: videoConstraint,
      audio: false.toJS,
    );
    return mediaDevices
        .getUserMedia(constraints)
        .toDart
        .timeout(const Duration(seconds: 30));
  }

  Future<void> _startCamera([String? targetDeviceId]) async {
    if (!mounted || _isDisposed) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _captureWarning = null;
    });

    final mediaDevices = _getMediaDevices();
    if (mediaDevices == null) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Akses kamera tidak tersedia. Pastikan browser mendukung kamera dan berjalan pada HTTPS atau localhost.';
        });
      }
      return;
    }

    try {
      _stopCurrentStream();
      web.MediaStream? stream;
      final devId = targetDeviceId ?? _selectedDeviceId;

      if (devId != null && devId.isNotEmpty) {
        try {
          stream = await _requestStream(
            mediaDevices,
            {
              'deviceId': {'exact': devId},
              'width': {'ideal': 1920},
              'height': {'ideal': 1080},
            }.jsify()!,
          );
        } catch (_) {
          try {
            stream = await _requestStream(
              mediaDevices,
              {'deviceId': devId}.jsify()!,
            );
          } catch (_) {}
        }
      }

      if (stream == null) {
        try {
          stream = await _requestStream(
            mediaDevices,
            {
              'facingMode': 'environment',
              'width': {'ideal': 1920},
              'height': {'ideal': 1080},
            }.jsify()!,
          );
        } catch (_) {
          stream = await _requestStream(mediaDevices, true.toJS);
        }
      }

      final activeStream = stream;

      if (_isDisposed || !mounted) {
        _stopStreamTracks(activeStream);
        return;
      }

      _mediaStream = activeStream;
      _videoElement.srcObject = activeStream;
      _playVideoSafely();

      await _enumerateDevices();
      if (_isDisposed || !mounted) {
        _stopCurrentStream();
        return;
      }

      var activeLabel = 'Kamera Lokal';
      var activeDeviceId = targetDeviceId ?? _selectedDeviceId;
      try {
        final tracks = activeStream.getVideoTracks().toDart;
        if (tracks.isNotEmpty) {
          final track = tracks.first;
          if (track.label.isNotEmpty) {
            activeLabel = track.label;
          }
          final settings = track.getSettings();
          if (settings.deviceId.isNotEmpty) {
            activeDeviceId = settings.deviceId;
          }
        }
      } catch (_) {}

      // If browser initially opened a virtual camera driver, switch to physical camera once.
      if (targetDeviceId == null && _isVirtualCameraLabel(activeLabel)) {
        _CameraDeviceInfo? physicalCam;
        for (final d in _devices) {
          if (!d.isVirtual && d.deviceId.isNotEmpty) {
            physicalCam = d;
            break;
          }
        }
        if (physicalCam != null && physicalCam.deviceId != activeDeviceId) {
          _selectedDeviceId = physicalCam.deviceId;
          await _startCamera(physicalCam.deviceId);
          return;
        }
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _activeCameraLabel = activeLabel;
          if (activeDeviceId != null && activeDeviceId.isNotEmpty) {
            _selectedDeviceId = activeDeviceId;
          }
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } on TimeoutException {
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Permintaan akses kamera habis waktu. Pastikan izin kamera pada browser sudah diberikan.';
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Gagal membuka kamera lokal. Periksa izin kamera browser atau sambungan webcam ($e).';
        });
      }
    }
  }

  void _stopStreamTracks(web.MediaStream? stream) {
    if (stream == null) return;
    try {
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    } catch (_) {}
  }

  void _stopCurrentStream() {
    _stopStreamTracks(_mediaStream);
    _mediaStream = null;
    try {
      _videoElement.pause();
      _videoElement.srcObject = null;
    } catch (_) {}
  }

  Future<void> _captureSnapshot() async {
    if (_isCapturing || _isInitializing || _errorMessage != null) return;

    final vw = _videoElement.videoWidth;
    final vh = _videoElement.videoHeight;
    if (vw <= 0 || vh <= 0 || _videoElement.readyState < 2) {
      setState(() {
        _captureWarning =
            'Frame kamera belum siap. Tunggu sebentar hingga gambar tampil lalu coba lagi.';
      });
      return;
    }

    setState(() {
      _isCapturing = true;
      _captureWarning = null;
    });

    try {
      const maxDim = 1920;
      final longest = vw > vh ? vw : vh;
      final scale = longest > maxDim ? maxDim / longest : 1.0;
      final cw = (vw * scale).round().clamp(1, maxDim);
      final ch = (vh * scale).round().clamp(1, maxDim);

      final canvas = web.HTMLCanvasElement()
        ..width = cw
        ..height = ch;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (ctx == null) {
        throw StateError('Konteks kanvas 2D tidak tersedia.');
      }

      ctx.drawImage(_videoElement, 0, 0, cw, ch);
      final bytes = await encodePcvCanvasJpeg(canvas, quality: 0.92);

      if (mounted && !_isDisposed && ModalRoute.of(context)?.isCurrent == true) {
        _stopCurrentStream();
        Navigator.of(context).pop(
          PcvCapturedPhoto(
            bytes: bytes,
            fileName: 'kamera_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isCapturing = false;
          _captureWarning = 'Gagal mengambil snapshot kamera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadedMetadataSub?.cancel();
    _canPlaySub?.cancel();
    _stopCurrentStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF161924) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF2D3348) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Color(0xFF1ABC9C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kamera Lokal (Snapshot PCV)',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Arahkan kamera ke bayi / objek di atas papan ukur lalu klik Ambil Snapshot.',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () {
                      _stopCurrentStream();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.close_rounded, color: subColor),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Viewfinder
              Container(
                height: 360,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F17),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.amber,
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Kamera Lokal Tidak Dapat Dibuka',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _errorMessage!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _startCamera(_selectedDeviceId),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: Text(
                                  'Coba Lagi',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1ABC9C),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: HtmlElementView(viewType: _viewType),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                margin: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF1ABC9C)
                                        .withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: _isInitializing
                                            ? Colors.amber
                                            : const Color(0xFF2ECC71),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      child: Text(
                                        _isInitializing
                                            ? 'Menghubungkan kamera...'
                                            : _activeCameraLabel,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_isInitializing)
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFF0B0F17),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF1ABC9C),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Membuka kamera lokal...',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Izinkan akses kamera pada browser bila diminta.',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white60,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),

              if (_captureWarning != null) ...[
                const SizedBox(height: 10),
                Text(
                  _captureWarning!,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFFE67E22),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Controls (outside HtmlElementView so pointer events always hit Flutter)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_devices.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Pilih Kamera Lokal',
                      onSelected: (devId) => _startCamera(devId),
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      itemBuilder: (_) => _devices.map((dev) {
                        final isSelected = dev.deviceId == _selectedDeviceId;
                        return PopupMenuItem<String>(
                          value: dev.deviceId,
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.videocam_outlined,
                                size: 16,
                                color: isSelected
                                    ? const Color(0xFF2ECC71)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dev.label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: isSelected
                                        ? const Color(0xFF2ECC71)
                                        : Colors.white,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2130)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cameraswitch_rounded,
                              size: 16,
                              color: Color(0xFF1ABC9C),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                _activeCameraLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: subColor,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _stopCurrentStream();
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: subColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed:
                            (_isInitializing ||
                                _errorMessage != null ||
                                _isCapturing)
                            ? null
                            : _captureSnapshot,
                        icon: _isCapturing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(
                          _isCapturing ? 'Menyimpan...' : 'Ambil Snapshot',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ABC9C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
