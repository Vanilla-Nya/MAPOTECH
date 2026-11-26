// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class CameraDeviceInfo {
  final String deviceId;
  final String label;

  CameraDeviceInfo({required this.deviceId, required this.label});

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

class WebPlatformQrScannerWidget extends StatefulWidget {
  final Function(String code) onScanned;
  final bool isFrontCamera;
  final bool isTorchOn;
  final Function(bool isReady, String? statusMessage) onCameraStatusChanged;
  final VoidCallback? onCameraSwitch;

  const WebPlatformQrScannerWidget({
    super.key,
    required this.onScanned,
    required this.isFrontCamera,
    required this.isTorchOn,
    required this.onCameraStatusChanged,
    this.onCameraSwitch,
  });

  @override
  State<WebPlatformQrScannerWidget> createState() => _WebPlatformQrScannerWidgetState();
}

class _WebPlatformQrScannerWidgetState extends State<WebPlatformQrScannerWidget> {
  late final String _viewType;
  late final String _elementId;
  late final html.VideoElement _videoElement;
  html.MediaStream? _mediaStream;
  Timer? _scanTimer;

  List<CameraDeviceInfo> _videoDevices = [];
  String? _selectedDeviceId;
  String _activeCameraLabel = 'Kamera Aktif';

  bool _isInitializing = true;
  bool _isScanningActive = false;
  String? _errorMessage;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  @override
  void initState() {
    super.initState();
    final uniqueId = DateTime.now().microsecondsSinceEpoch;
    _viewType = 'web-qr-scanner-view-$uniqueId';
    _elementId = 'web-qr-video-$uniqueId';

    _videoElement = html.VideoElement()
      ..id = _elementId
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..setAttribute('autoplay', 'true')
      ..setAttribute('muted', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.backgroundColor = '#0F141C'
      ..style.border = 'none'
      ..style.pointerEvents = 'none';

    _videoElement.onLoadedMetadata.listen((_) {
      _videoElement.play().catchError((_) {});
    });
    _videoElement.onCanPlay.listen((_) {
      _videoElement.play().catchError((_) {});
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _videoElement);

    _initCamera();
  }

  Future<void> _initCamera() async {
    // 1. First probe available devices
    await _enumerateDevices();

    // 2. If a physical camera is found, directly use its deviceId
    if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty) {
      await _startCamera(_selectedDeviceId);
    } else {
      await _startCamera();
    }
  }

  @override
  void didUpdateWidget(covariant WebPlatformQrScannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFrontCamera != widget.isFrontCamera) {
      _switchNextCamera();
    }
    if (oldWidget.isTorchOn != widget.isTorchOn) {
      _applyTorch(widget.isTorchOn);
    }
  }

  void _switchNextCamera() {
    if (_videoDevices.length <= 1) {
      _restartCamera();
      return;
    }
    final currentIndex = _videoDevices.indexWhere((d) => d.deviceId == _selectedDeviceId);
    final nextIndex = (currentIndex + 1) % _videoDevices.length;
    final nextDev = _videoDevices[nextIndex];
    _restartCamera(nextDev.deviceId);
  }

  Future<void> _enumerateDevices() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) return;
    try {
      final rawList = await js_util.promiseToFuture<dynamic>(
        js_util.callMethod(mediaDevices, 'enumerateDevices', []),
      );
      if (rawList == null) return;

      final count = js_util.getProperty(rawList, 'length') as int? ?? 0;
      final List<CameraDeviceInfo> parsedDevices = [];

      for (int i = 0; i < count; i++) {
        final dev = js_util.getProperty(rawList, '$i') ?? js_util.callMethod(rawList, 'item', [i]);
        if (dev != null) {
          final kind = js_util.getProperty(dev, 'kind')?.toString() ?? '';
          if (kind == 'videoinput') {
            final id = js_util.getProperty(dev, 'deviceId')?.toString() ?? '';
            final rawLabel = js_util.getProperty(dev, 'label')?.toString() ?? '';
            final label = rawLabel.isNotEmpty ? rawLabel : 'Kamera ${parsedDevices.length + 1}';
            parsedDevices.add(CameraDeviceInfo(deviceId: id, label: label));
          }
        }
      }

      if (mounted && parsedDevices.isNotEmpty) {
        // Prioritize physical camera (e.g. Integrated Webcam, USB Camera, HD Camera)
        CameraDeviceInfo? preferred;
        for (final d in parsedDevices) {
          if (!d.isVirtual) {
            preferred = d;
            break;
          }
        }

        setState(() {
          _videoDevices = parsedDevices;
          _selectedDeviceId ??= preferred?.deviceId ?? parsedDevices.first.deviceId;
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
      const err = 'Akses kamera tidak didukung di browser ini atau koneksi tidak aman (Gunakan localhost atau HTTPS).';
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = err;
        });
        widget.onCameraStatusChanged(false, err);
      }
      return;
    }

    try {
      _stopCurrentStream();

      html.MediaStream? stream;
      final devId = targetDeviceId ?? _selectedDeviceId;

      // 1. Try with explicit device ID
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
          stream = await js_util.promiseToFuture<html.MediaStream>(promise);
        } catch (_) {
          try {
            final constraints = js_util.jsify({
              'video': {'deviceId': devId},
              'audio': false,
            });
            final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
            stream = await js_util.promiseToFuture<html.MediaStream>(promise);
          } catch (_) {}
        }
      }

      // 2. Try with facing mode preference
      if (stream == null) {
        try {
          final constraints = js_util.jsify({
            'video': {
              'facingMode': widget.isFrontCamera ? 'user' : 'environment',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            },
            'audio': false,
          });
          final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
          stream = await js_util.promiseToFuture<html.MediaStream>(promise);
        } catch (_) {}
      }

      // 3. Fallback generic video
      if (stream == null) {
        try {
          final constraints = js_util.jsify({'video': true, 'audio': false});
          final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
          stream = await js_util.promiseToFuture<html.MediaStream>(promise);
        } catch (e2) {
          throw Exception('Izin kamera ditolak atau kamera tidak aktif: $e2');
        }
      }

      _mediaStream = stream;
      _videoElement.muted = true;
      _videoElement.defaultMuted = true;
      _videoElement.autoplay = true;

      try {
        _videoElement.srcObject = stream;
      } catch (_) {}
      try {
        js_util.setProperty(_videoElement, 'srcObject', stream);
      } catch (_) {}

      try {
        await _videoElement.play();
      } catch (_) {}

      // Refresh list of devices with granted permissions
      await _enumerateDevices();

      String activeLabel = 'Kamera Aktif';
      try {
        final videoTracks = stream?.getVideoTracks() ?? [];
        if (videoTracks.isNotEmpty) {
          final track = videoTracks.first;
          final trackLabel = track.label;
          if (trackLabel != null && trackLabel.isNotEmpty) {
            activeLabel = trackLabel;
          }
        }
      } catch (_) {}

      // Auto-switch if the initial stream caught a virtual driver (DroidCam) but a real physical camera is available!
      if (targetDeviceId == null) {
        final isCurrVirtual = activeLabel.toLowerCase().contains('droidcam') ||
            activeLabel.toLowerCase().contains('virtual') ||
            activeLabel.toLowerCase().contains('obs');
        if (isCurrVirtual) {
          CameraDeviceInfo? physicalCam;
          for (final d in _videoDevices) {
            if (!d.isVirtual && d.deviceId.isNotEmpty) {
              physicalCam = d;
              break;
            }
          }
          if (physicalCam != null) {
            // Immediately switch to the physical camera!
            _selectedDeviceId = physicalCam.deviceId;
            await _startCamera(physicalCam.deviceId);
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeCameraLabel = activeLabel;
          if (targetDeviceId != null) {
            _selectedDeviceId = targetDeviceId;
          }
          _isInitializing = false;
          _errorMessage = null;
        });
        widget.onCameraStatusChanged(true, activeLabel);
      }

      _startScanningTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Gagal mengakses kamera: $e';
        });
        widget.onCameraStatusChanged(false, _errorMessage);
      }
    }
  }

  Future<void> _restartCamera([String? deviceId]) async {
    _scanTimer?.cancel();
    if (deviceId != null) {
      _selectedDeviceId = deviceId;
    }
    await _startCamera(_selectedDeviceId);
  }

  void _applyTorch(bool on) {
    if (_mediaStream == null) return;
    try {
      final videoTracks = _mediaStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final track = videoTracks.first;
        final constraints = js_util.jsify({
          'advanced': [
            {'torch': on}
          ]
        });
        js_util.callMethod(track, 'applyConstraints', [constraints]);
      }
    } catch (_) {}
  }

  void _startScanningTimer() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      _scanFrame();
    });
  }

  Future<void> _scanFrame() async {
    if (!mounted || _mediaStream == null || _isScanningActive) return;
    if (_videoElement.readyState < 2 || _videoElement.videoWidth == 0) return;

    _isScanningActive = true;
    try {
      // 1. Try global optimized JS QR decoder
      if (js_util.hasProperty(html.window, 'decodeQrFromVideo')) {
        final promise = js_util.callMethod(html.window, 'decodeQrFromVideo', [_videoElement]);
        final result = await js_util.promiseToFuture<dynamic>(promise);
        if (result != null) {
          final code = result.toString().trim();
          if (code.isNotEmpty) {
            _handleDetectedCode(code);
            return;
          }
        }
      }
    } catch (_) {
    } finally {
      _isScanningActive = false;
    }
  }

  void _handleDetectedCode(String code) {
    final now = DateTime.now();
    if (_lastScannedCode == code && _lastScannedTime != null) {
      if (now.difference(_lastScannedTime!).inMilliseconds < 2500) {
        return; // Debounce rapid scans of the same QR code
      }
    }
    _lastScannedCode = code;
    _lastScannedTime = now;
    widget.onScanned(code);
  }

  Future<void> _pickAndScanQrImage() async {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
      uploadInput.click();

      await uploadInput.onChange.first;
      if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
        final file = uploadInput.files!.first;
        if (js_util.hasProperty(html.window, 'decodeQrFromImageFile')) {
          final promise = js_util.callMethod(html.window, 'decodeQrFromImageFile', [file]);
          final result = await js_util.promiseToFuture<dynamic>(promise);
          if (result != null) {
            final code = result.toString().trim();
            if (code.isNotEmpty) {
              _handleDetectedCode(code);
              return;
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak ditemukan QR Code yang valid pada gambar tersebut.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _stopCurrentStream() {
    if (_mediaStream != null) {
      try {
        final tracks = _mediaStream!.getTracks();
        for (final track in tracks) {
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

  @override
  void dispose() {
    _scanTimer?.cancel();
    _stopCurrentStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFF0F141C),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 36),
              const SizedBox(height: 10),
              const Text(
                'Kamera Tidak Dapat Terhubung',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _restartCamera(),
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                    label: const Text('Coba Lagi', style: TextStyle(fontSize: 11, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27AE60),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickAndScanQrImage,
                    icon: const Icon(Icons.image_outlined, size: 14, color: Colors.white70),
                    label: const Text('Upload Gambar QR', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final isCurrentVirtual = _activeCameraLabel.toLowerCase().contains('droidcam') ||
        _activeCameraLabel.toLowerCase().contains('virtual') ||
        _activeCameraLabel.toLowerCase().contains('obs');

    return Stack(
      children: [
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),

        // If virtual camera (like DroidCam idle green) is detected, show direct switch banner
        if (isCurrentVirtual && _videoDevices.any((d) => !d.isVirtual))
          Positioned(
            top: 42,
            left: 12,
            right: 12,
            child: InkWell(
              onTap: () {
                final physical = _videoDevices.firstWhere((d) => !d.isVirtual);
                _restartCamera(physical.deviceId);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'DroidCam aktif (layar hijau). Klik untuk ganti ke Kamera Laptop',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Ganti',
                        style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Device Switcher & Upload Image Action (Bottom Bar)
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Upload image shortcut button
              InkWell(
                onTap: _pickAndScanQrImage,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 13, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        'Upload QR',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              // Camera Selector Popup Dropdown
              if (_videoDevices.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Pilih Sumber Kamera (Webcam / DroidCam)',
                  onSelected: (devId) => _restartCamera(devId),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  itemBuilder: (context) {
                    return _videoDevices.map((dev) {
                      final isCurrent = dev.deviceId == _selectedDeviceId ||
                          (_selectedDeviceId == null && dev == _videoDevices.first);
                      return PopupMenuItem<String>(
                        value: dev.deviceId,
                        child: Row(
                          children: [
                            Icon(
                              isCurrent ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                              size: 16,
                              color: isCurrent ? const Color(0xFF2ECC71) : Colors.white60,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dev.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCurrent ? const Color(0xFF2ECC71) : Colors.white,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cameraswitch_rounded, size: 13, color: Color(0xFF2ECC71)),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            _activeCameraLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_isInitializing)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F141C),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2ECC71)),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Menghubungkan Kamera & Pemindai...',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Widget buildPlatformWebQrScanner({
  required Function(String code) onScanned,
  required bool isFrontCamera,
  required bool isTorchOn,
  required Function(bool isReady, String? statusMessage) onCameraStatusChanged,
  VoidCallback? onCameraSwitch,
}) {
  return WebPlatformQrScannerWidget(
    onScanned: onScanned,
    isFrontCamera: isFrontCamera,
    isTorchOn: isTorchOn,
    onCameraStatusChanged: onCameraStatusChanged,
    onCameraSwitch: onCameraSwitch,
  );
}
