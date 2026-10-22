import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import '../cv/vitascale_camera_bridge.dart';
import '../data/vitascale_device_simulator.dart';
import '../data/vitascale_models.dart';
import '../data/vitascale_repository.dart';
import '../logic/screening_state_machine.dart';
import '../logic/whtr.dart';
import '../vitascale_dlc_gate.dart';
import '../widgets/measurement_card.dart';
import '../widgets/vitascale_status_bar.dart';

class VitaScaleScreeningPage extends ConsumerStatefulWidget {
  final ChildProfile? selectedChild;

  const VitaScaleScreeningPage({
    super.key,
    this.selectedChild,
  });

  @override
  ConsumerState<VitaScaleScreeningPage> createState() => _VitaScaleScreeningPageState();
}

class _VitaScaleScreeningPageState extends ConsumerState<VitaScaleScreeningPage> {
  late final VitaScaleDeviceSimulator _simulator;
  final VitaScaleRepository _repository = VitaScaleRepository();
  final TextEditingController _notesController = TextEditingController();

  List<ChildProfile> _availableChildren = [];
  ChildProfile? _activeChild;

  @override
  void initState() {
    super.initState();
    _simulator = VitaScaleDeviceSimulator(
      stateMachine: ref.read(screeningStateProvider.notifier),
    );

    _initSession();
  }

  Future<void> _initSession() async {
    final list = await _repository.searchChildren();
    if (mounted) {
      setState(() {
        _availableChildren = list;
        _activeChild = widget.selectedChild ?? (list.isNotEmpty ? list.first : null);
      });

      if (_activeChild != null) {
        final state = ref.read(landingPageProvider);
        final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';

        ref.read(screeningStateProvider.notifier).startSession(
              child: _activeChild!,
              facilityId: facilityId,
              isDemo: true,
            );
      }
    }
  }

  @override
  void dispose() {
    _simulator.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showPatientPickerModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        return CustomDialog(
          title: 'Pilih Sasaran Anak / Bayi',
          icon: Icons.people_rounded,
          iconColor: const Color(0xFF1ABC9C),
          maxWidth: 480,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableChildren.map((child) {
              final isCurrent = child.id == _activeChild?.id;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isCurrent ? const Color(0xFF1ABC9C).withOpacity(0.12) : null,
                leading: Icon(
                  child.isUnder24Months ? Icons.child_friendly_rounded : Icons.face_rounded,
                  color: isCurrent ? const Color(0xFF1ABC9C) : Colors.grey,
                ),
                title: Text(
                  child.name,
                  style: GoogleFonts.outfit(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'NIK: ${child.nik} • Usia: ${child.ageLabel}',
                  style: GoogleFonts.outfit(fontSize: 10.5),
                ),
                trailing: StatusBadge(
                  label: child.isUnder24Months ? 'PB (TELENTANG)' : 'TB (BERDIRI)',
                  color: child.isUnder24Months ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                  fontSize: 8,
                ),
                onTap: () {
                  setState(() => _activeChild = child);
                  final state = ref.read(landingPageProvider);
                  final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';
                  ref.read(screeningStateProvider.notifier).startSession(
                        child: child,
                        facilityId: facilityId,
                        isDemo: true,
                      );
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showSummarySuccessModal(ScreeningSession session) {
    final whtr = WHtRCalculator.calculate(
      waistCm: session.waist.value,
      heightCm: session.height.value,
      ageInMonths: session.child.ageInMonths,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return CustomDialog(
          title: 'Hasil Skrining Terverifikasi Final',
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF27AE60),
          maxWidth: 480,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                ),
                child: Text(
                  'Sesi ${session.sessionId} telah diverifikasi oleh petugas faskes dan disimpan ke rekam audit.',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                ),
              ),
              const SizedBox(height: 14),
              _buildSummaryRow('Nama Anak', session.child.name),
              _buildSummaryRow('NIK / Usia', '${session.child.nik} (${session.child.ageLabel})'),
              _buildSummaryRow('Mode Pengukuran', session.mode.label),
              const Divider(height: 16),
              _buildSummaryRow('Berat Badan', '${session.weight.value?.toStringAsFixed(2)} kg'),
              _buildSummaryRow('Panjang / Tinggi', '${session.height.value?.toStringAsFixed(1)} cm'),
              _buildSummaryRow('Lingkar Perut', '${session.waist.value?.toStringAsFixed(1)} cm'),
              if (whtr != null) ...[
                const Divider(height: 16),
                _buildSummaryRow('Rasio WHtR (Lingkar/Tinggi)', whtr.formattedRatio),
                const SizedBox(height: 4),
                Text(
                  whtr.informationalNote,
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, height: 1.4),
                ),
              ],
            ],
          ),
          actions: [
            CustomButton(
              text: 'Selesai & Tutup',
              height: 38,
              primaryColor: const Color(0xFF27AE60),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(screeningStateProvider.notifier).closeSession();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screeningState = ref.watch(screeningStateProvider);
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isMobile = MediaQuery.of(context).size.width < 900;

    final session = screeningState.session;

    return VitaScaleDlcGate(
      menuTitle: 'Screening Anak & Bayi',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Top Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.monitor_weight_rounded, size: 28, color: Color(0xFF1ABC9C)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1ABC9C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'MODUL SKRINING ANTROPOMETRI IOT',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1ABC9C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VitaScale by MAPOTECH',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Screening Antropometri Anak / Bayi',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Text(
                          'Integrasi sensor berat digital HX711, pita lingkar perut AS5600, dan Computer Vision OpenCV.js.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  if (session == null)
                    CustomButton(
                      text: 'Pilih Pasien',
                      icon: Icons.person_search_rounded,
                      height: 40,
                      primaryColor: const Color(0xFF1ABC9C),
                      onPressed: _showPatientPickerModal,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (session == null)
              EmptyStateWidget(
                icon: Icons.person_search_rounded,
                title: 'Belum Ada Sesi Skrining yang Aktif',
                subtitle: 'Pilih pasien anak/bayi untuk memulai pengukuran antropometri dengan perangkat VitaScale.',
                cardBg: cardBgColor,
                border: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              )
            else ...[
              // Status Bar Pasien & Perangkat
              VitaScaleStatusBar(
                session: session,
                deviceStatus: screeningState.deviceStatus,
                isCameraReady: screeningState.isCameraReady,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                themeAccent: const Color(0xFF1ABC9C),
                onModeChanged: (m) => ref.read(screeningStateProvider.notifier).changeAnthropometryMode(m),
                onCloseSession: () => ref.read(screeningStateProvider.notifier).closeSession(),
              ),

              const SizedBox(height: 18),

              // Layout Grid Kamera & Panel Pengukuran
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sisi Kiri: Webcam Preview OpenCV.js
                  Expanded(
                    flex: isMobile ? 1 : 3,
                    child: Container(
                      height: 380,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: VitaScaleCameraWidget(
                        onStatusChanged: (isReady, label) {
                          ref.read(screeningStateProvider.notifier).setCameraStatus(
                                isReady: isReady,
                                cameraLabel: label,
                              );
                        },
                        onMeasured: (result) {
                          if (result.ok && result.valueCm != null) {
                            ref.read(screeningStateProvider.notifier).updateHeight(
                                  value: result.valueCm,
                                  status: MeasurementStatus.stable,
                                  source: 'opencv_web',
                                );
                            CustomSnackbar.success(
                              context,
                              'Panjang/Tinggi terdeteksi: ${result.valueCm!.toStringAsFixed(1)} cm',
                              title: 'Deteksi Marker Berhasil',
                            );
                          } else {
                            final err = result.reasons.isNotEmpty
                                ? result.reasons.join('\n')
                                : 'Deteksi marker papan ukur gagal.';
                            ref.read(screeningStateProvider.notifier).updateHeight(
                                  value: null,
                                  status: MeasurementStatus.failed,
                                  errorMessage: err,
                                );
                            CustomSnackbar.warning(context, err, title: 'Kamera Gagal Mengukur');
                          }
                        },
                        onSimulateFixture: () {
                          // Injeksi data uji sintetis untuk pengujian non-hardware
                          final sampleVal = session.child.isUnder24Months ? 74.8 : 98.5;
                          _simulator.injectCvFixtureMeasurement(fixtureHeight: sampleVal);
                          CustomSnackbar.info(
                            context,
                            'Data fixture sintetis panjang/tinggi ($sampleVal cm) telah diinjeksikan.',
                            title: 'Fixture Uji Selesai',
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Sisi Kanan: 3 Kartu Hasil Sensor (Berat, Panjang/Tinggi, Lingkar Perut)
                  Expanded(
                    flex: isMobile ? 1 : 2,
                    child: Column(
                      children: [
                        // 1. Berat Badan (HX711)
                        SizedBox(
                          height: 180,
                          child: MeasurementCard(
                            type: MeasurementType.weight,
                            item: session.weight,
                            icon: Icons.monitor_weight_rounded,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            themeAccent: const Color(0xFF1ABC9C),
                            onReset: () => ref
                                .read(screeningStateProvider.notifier)
                                .resetMeasurement(MeasurementType.weight),
                            simulateLabel: 'Simulasi Berat',
                            onSimulate: () {
                              final defaultTarget = session.child.isUnder24Months ? 9.45 : 15.20;
                              _simulator.simulateWeightMeasurement(targetWeight: defaultTarget);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Lingkar Perut (AS5600)
                        SizedBox(
                          height: 180,
                          child: MeasurementCard(
                            type: MeasurementType.waist,
                            item: session.waist,
                            icon: Icons.straighten_rounded,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            themeAccent: const Color(0xFFE67E22),
                            onReset: () => ref
                                .read(screeningStateProvider.notifier)
                                .resetMeasurement(MeasurementType.waist),
                            simulateLabel: 'Simulasi Lingkar',
                            onSimulate: () {
                              final defaultWaist = session.child.isUnder24Months ? 44.2 : 51.5;
                              _simulator.simulateWaistMeasurement(targetWaist: defaultWaist);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Baris Tambahan: Indikator WHtR & Analisis Tambahan
              if (session.height.hasValue && session.waist.hasValue) ...[
                Builder(
                  builder: (context) {
                    final whtr = WHtRCalculator.calculate(
                      waistCm: session.waist.value,
                      heightCm: session.height.value,
                      ageInMonths: session.child.ageInMonths,
                    );
                    if (whtr == null) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: whtr.indicatorColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: whtr.indicatorColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.analytics_rounded, size: 20, color: whtr.indicatorColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'RASIO LINGKAR PERUT TERHADAP TINGGI BADAN (WHtR): ',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      whtr.formattedRatio,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: whtr.indicatorColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  whtr.informationalNote,
                                  style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],

              // Panel Aksi Final: Catatan & Tombol Verifikasi
              CustomCard(
                color: cardBgColor,
                borderColor: borderColor,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Catatan Petugas (Opsional)',
                        hintText: 'Kondisi anak saat diukur, posisi rewel/tenang, evaluasi faskes...',
                        controller: _notesController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    CustomButton(
                      text: screeningState.isSubmitting ? 'Menyimpan...' : 'Verifikasi & Simpan Hasil',
                      icon: Icons.verified_rounded,
                      height: 48,
                      primaryColor: const Color(0xFF27AE60),
                      onPressed: () async {
                        final staffName = state.loggedInName ?? 'Petugas Puskesmas';
                        final ok = await ref.read(screeningStateProvider.notifier).verifyAndFinalize(
                              verifiedBy: staffName,
                              notes: _notesController.text.trim(),
                            );
                        if (!context.mounted) return;
                        if (ok) {
                          final currentSession = ref.read(screeningStateProvider).session;
                          if (currentSession != null) {
                            await _repository.saveScreeningResult(currentSession, staffName: staffName);
                            if (!context.mounted) return;
                            _showSummarySuccessModal(currentSession);
                          }
                        } else {
                          CustomSnackbar.warning(
                            context,
                            ref.read(screeningStateProvider).errorMessage ?? 'Gagal memverifikasi.',
                            title: 'Verifikasi Belum Lengkap',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
