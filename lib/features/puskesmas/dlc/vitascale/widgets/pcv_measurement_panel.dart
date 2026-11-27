import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mapotech/shared/widgets/ui.dart';

import '../cv/pcv_camera_capture_bridge.dart';
import '../cv/pcv_photo_processing.dart';
import '../data/vitascale_api_service.dart';

class PcvCalibration {
  const PcvCalibration({
    required this.pixelsPerCm,
    required this.width,
    required this.height,
    required this.crop,
  });

  final double pixelsPerCm;
  final int width;
  final int height;
  final Rect crop;
}

class PcvMeasurementPanel extends StatefulWidget {
  const PcvMeasurementPanel({
    super.key,
    required this.calibration,
    required this.onCalibrationChanged,
    required this.onMeasurementChanged,
    required this.isEnglish,
    required this.cardColor,
    required this.borderColor,
  });

  final PcvCalibration? calibration;
  final ValueChanged<PcvCalibration?> onCalibrationChanged;
  final ValueChanged<double?> onMeasurementChanged;
  final bool isEnglish;
  final Color cardColor;
  final Color borderColor;

  @override
  State<PcvMeasurementPanel> createState() => _PcvMeasurementPanelState();
}

class _PcvMeasurementPanelState extends State<PcvMeasurementPanel> {
  static const _fullFrame = Rect.fromLTWH(0, 0, 1, 1);
  static const _accent = Color(0xFF148773);
  final _referenceLength = TextEditingController();
  final _points = <Offset>[];
  Rect _crop = _fullFrame;
  PcvFrame? _frame;
  Uint8List? _annotation;
  String? _message;
  bool _hasError = false;
  bool _busy = false;

  bool get _isCalibrating => widget.calibration == null;
  String _t(String id, String en) => widget.isEnglish ? en : id;

  @override
  void dispose() {
    _referenceLength.dispose();
    super.dispose();
  }

  double? get _knownLength {
    final length = double.tryParse(
      _referenceLength.text.trim().replaceAll(',', '.'),
    );
    return length != null && length.isFinite && length > 0 ? length : null;
  }

  PcvCalibration? get _draftCalibration {
    final frame = _frame;
    final length = _knownLength;
    if (frame == null || length == null || _points.length != 2) return null;
    final delta = _points[1] - _points[0];
    final distance = Offset(
      delta.dx * frame.width,
      delta.dy * frame.height,
    ).distance;
    final scale = distance / length;
    if (!scale.isFinite || scale <= 0) return null;
    return PcvCalibration(
      pixelsPerCm: scale,
      width: frame.width,
      height: frame.height,
      crop: _crop,
    );
  }

  void _clearFeedback() {
    _message = null;
    _hasError = false;
    _annotation = null;
  }

  void _fail(String message) {
    setState(() {
      _message = message;
      _hasError = true;
    });
  }

  Future<void> _choosePhoto({required bool camera}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Uint8List? bytes;
      if (camera) {
        bytes = (await capturePcvCameraSnapshot(context))?.bytes;
      } else {
        final files = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        bytes = files?.files.single.bytes;
      }
      if (!mounted || bytes == null) return;

      widget.onMeasurementChanged(null);
      setState(() {
        _frame = null;
        _points.clear();
        _crop = _fullFrame;
        _clearFeedback();
      });
      final frame = await preparePcvPhoto(bytes);
      if (!mounted) return;
      if (frame == null) {
        _fail(
          _t(
            'Format gambar tidak dapat dibaca.',
            'This image format could not be read.',
          ),
        );
        return;
      }
      setState(() => _frame = frame);
    } catch (error) {
      if (!mounted) return;
      _fail(
        _t(
          'Foto tidak dapat dibuka. Periksa izin kamera atau pilih berkas.',
          'Could not open the photo. Check camera permissions or choose a file.',
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (mounted && !_isCalibrating) await _measure(reference: false);
  }

  void _changeCrop({required bool start, required Offset delta}) {
    const minimumSize = 0.05;
    setState(() {
      _crop = start
          ? Rect.fromLTRB(
              (_crop.left + delta.dx).clamp(0.0, _crop.right - minimumSize),
              (_crop.top + delta.dy).clamp(0.0, _crop.bottom - minimumSize),
              _crop.right,
              _crop.bottom,
            )
          : Rect.fromLTRB(
              _crop.left,
              _crop.top,
              (_crop.right + delta.dx).clamp(_crop.left + minimumSize, 1.0),
              (_crop.bottom + delta.dy).clamp(_crop.top + minimumSize, 1.0),
            );
      _points.clear();
      _clearFeedback();
    });
  }

  void _markPoint(Offset point) {
    if (point.dx < _crop.left ||
        point.dx > _crop.right ||
        point.dy < _crop.top ||
        point.dy > _crop.bottom) {
      _fail(
        _t(
          'Tandai titik di dalam kotak potong.',
          'Mark points inside the crop box.',
        ),
      );
      return;
    }
    setState(() {
      if (_points.length == 2) _points.clear();
      _points.add(point);
      _clearFeedback();
    });
  }

  void _saveCalibration(PcvCalibration? calibration) {
    setState(() {
      _frame = null;
      _crop = _fullFrame;
      _points.clear();
      _referenceLength.clear();
      _clearFeedback();
    });
    widget.onCalibrationChanged(calibration);
  }

  Future<void> _measure({required bool reference}) async {
    final calibration = reference ? _draftCalibration : widget.calibration;
    final frame = _frame;
    if (_busy || frame == null || calibration == null) return;
    final knownLength = _knownLength;

    if (!reference) widget.onMeasurementChanged(null);
    setState(_clearFeedback);
    if (frame.width != calibration.width ||
        frame.height != calibration.height) {
      _fail(
        _t(
          'Resolusi berbeda dari foto kalibrasi. Gunakan kamera dan resolusi yang sama atau kalibrasi ulang.',
          'Resolution differs from the calibration photo. Use the same camera and resolution or recalibrate.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      final cropped = await cropPcvPhoto(frame, calibration.crop);
      if (!mounted) return;
      final data = await VitaScaleApiService.measureCalibratedPhoto(
        jpeg: cropped,
        pixelsPerCm: calibration.pixelsPerCm,
      );
      if (!mounted) return;
      final scale = data['skala_efektif'];
      if (scale is! num ||
          !scale.isFinite ||
          (scale - calibration.pixelsPerCm).abs() > 0.00501) {
        _fail(
          _t(
            'Skala dari API berbeda. Periksa kalibrasi atau coba lagi.',
            'The API returned a different scale. Check the calibration or retry.',
          ),
        );
        return;
      }

      final value = data['tinggi_cm'];
      if (data['status'] == 'ok' &&
          value is num &&
          value.isFinite &&
          value > 0) {
        final cm = value.toDouble();
        final rawAnnotation = data['annotated_image'];
        if (rawAnnotation is String && rawAnnotation.isNotEmpty) {
          try {
            _annotation = base64Decode(rawAnnotation.split(',').last);
          } on FormatException {
            _annotation = null;
          }
        }
        final reading = '${cm.toStringAsFixed(1)} cm';
        setState(() {
          if (reference && knownLength != null) {
            final difference = (cm - knownLength).abs().toStringAsFixed(1);
            _message = _t(
              'Referensi terdeteksi $reading · Selisih $difference cm',
              'Reference detected at $reading · Difference $difference cm',
            );
          } else {
            _message = _t(
              'Panjang terukur $reading',
              'Measured length $reading',
            );
          }
        });
        if (!reference) widget.onMeasurementChanged(cm);
      } else if (data['status'] == 'tidak_terdeteksi') {
        final message = reference
            ? _t(
                'API menerima skala. Kontur referensi tidak terdeteksi.',
                'The API accepted the scale. No reference contour was detected.',
              )
            : _t(
                'Objek tidak terdeteksi. Ambil foto baru dan periksa area potong.',
                'No object was detected. Take another photo and check the crop area.',
              );
        if (reference) {
          setState(() => _message = message);
        } else {
          _fail(message);
        }
      } else {
        _fail(
          _t(
            'API tidak mengembalikan hasil pengukuran yang valid.',
            'The API did not return a valid measurement.',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint('[VitaScale PCV] $error');
      _fail(
        _t(
          'Pengukuran gagal. Periksa koneksi PCV dan coba lagi.',
          'Measurement failed. Check the PCV connection and retry.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photoPreview(PcvFrame frame) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = frame.width / frame.height;
        final width = math.min(constraints.maxWidth, 320.0 * ratio);
        final height = width / ratio;
        final area = widget.calibration?.crop ?? _crop;
        final bounds = Rect.fromLTRB(
          area.left * width,
          area.top * height,
          area.right * width,
          area.bottom * height,
        );
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTapUp: _isCalibrating && !_busy
                      ? (event) => _markPoint(
                          Offset(
                            event.localPosition.dx / width,
                            event.localPosition.dy / height,
                          ),
                        )
                      : null,
                  child: Image.memory(frame.bytes, fit: BoxFit.fill),
                ),
                Positioned.fromRect(
                  rect: bounds,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFF2BA34),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < _points.length; index++)
                  Positioned(
                    left: _points[index].dx * width - 9,
                    top: _points[index].dy * height - 9,
                    child: IgnorePointer(
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                if (_isCalibrating && !_busy)
                  for (final start in [true, false])
                    Positioned(
                      left: (start ? bounds.left : bounds.right) - 12,
                      top: (start ? bounds.top : bounds.bottom) - 12,
                      width: 24,
                      height: 24,
                      child: Semantics(
                        label: start
                            ? _t(
                                'Sudut kiri atas area potong',
                                'Crop top left corner',
                              )
                            : _t(
                                'Sudut kanan bawah area potong',
                                'Crop bottom right corner',
                              ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.move,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (event) => _changeCrop(
                              start: start,
                              delta: Offset(
                                event.delta.dx / width,
                                event.delta.dy / height,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2BA34),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final calibration = widget.calibration;
    final frame = _frame;
    final draft = _draftCalibration;
    final errorColor = Theme.of(context).colorScheme.error;

    return CustomCard(
      color: widget.cardColor,
      borderColor: widget.borderColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isCalibrating
                ? _t('Kalibrasi Kamera PCV', 'PCV camera calibration')
                : _t(
                    'Uji Ukur Panjang via Kamera',
                    'Camera length measurement',
                  ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            calibration == null
                ? _t(
                    'Foto benda yang panjangnya diketahui pada bidang ukur. Tarik sudut kotak potong, lalu tandai dua ujung referensi.',
                    'Photograph an object of known length on the measurement surface. Drag the crop corners, then mark both ends of the reference.',
                  )
                : _t(
                    'Gunakan posisi kamera dan resolusi yang sama seperti saat kalibrasi.',
                    'Use the same camera position and resolution as during calibration.',
                  ),
          ),
          if (calibration != null)
            Text(
              '${calibration.pixelsPerCm.toStringAsFixed(3)} px/cm · ${calibration.width} × ${calibration.height} px',
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CustomButton(
                text: _t('Buka Kamera', 'Open camera'),
                icon: Icons.photo_camera_rounded,
                height: 36,
                onPressed: _busy ? null : () => _choosePhoto(camera: true),
              ),
              CustomButton(
                text: _t('Pilih Foto', 'Choose photo'),
                icon: Icons.image_outlined,
                height: 36,
                isSecondary: true,
                onPressed: _busy ? null : () => _choosePhoto(camera: false),
              ),
              if (calibration != null)
                CustomButton(
                  text: _t('Kalibrasi Ulang', 'Recalibrate'),
                  icon: Icons.tune_rounded,
                  height: 36,
                  isSecondary: true,
                  onPressed: _busy ? null : () => _saveCalibration(null),
                ),
            ],
          ),
          if (frame != null) ...[
            const SizedBox(height: 15),
            _photoPreview(frame),
          ],
          if (_isCalibrating && frame != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _points.clear();
                          _clearFeedback();
                        }),
                  child: Text(_t('Ulangi Titik', 'Reset points')),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _crop = _fullFrame;
                          _clearFeedback();
                        }),
                  child: Text(_t('Gunakan Seluruh Foto', 'Use full photo')),
                ),
              ],
            ),
            CustomTextField(
              label: _t('Panjang Referensi (cm)', 'Reference length (cm)'),
              controller: _referenceLength,
              hintText: _t('Contoh: 29,7', 'Example: 29.7'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !_busy,
              onChanged: (_) => setState(_clearFeedback),
            ),
            if (draft != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${draft.pixelsPerCm.toStringAsFixed(3)} px/cm'),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CustomButton(
                  text: _t('Uji Skala ke API', 'Test scale with API'),
                  isSecondary: true,
                  height: 36,
                  onPressed: _busy || draft == null
                      ? null
                      : () => _measure(reference: true),
                ),
                CustomButton(
                  text: _t('Simpan Kalibrasi', 'Save calibration'),
                  height: 36,
                  onPressed: _busy || draft == null
                      ? null
                      : () => _saveCalibration(draft),
                ),
              ],
            ),
          ],
          if (!_isCalibrating &&
              _hasError &&
              !_busy &&
              frame != null &&
              calibration != null &&
              frame.width == calibration.width &&
              frame.height == calibration.height) ...[
            const SizedBox(height: 12),
            CustomButton(
              text: _t('Coba Ukur Lagi', 'Retry measurement'),
              height: 40,
              icon: Icons.refresh_rounded,
              onPressed: () => _measure(reference: false),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(color: _hasError ? errorColor : _accent),
            ),
          ],
          if (_annotation != null) ...[
            const SizedBox(height: 10),
            Image.memory(
              _annotation!,
              height: 260,
              fit: BoxFit.contain,
              semanticLabel: _t(
                'Foto dengan anotasi kontur PCV',
                'Photo with PCV contour annotation',
              ),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
