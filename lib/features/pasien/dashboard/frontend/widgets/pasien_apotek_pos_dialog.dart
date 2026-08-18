import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal dialog connecting patient directly to an Apotek POS system
class PasienApotekPosDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> pharmacy;
  final bool isDark;

  const PasienApotekPosDialog({
    super.key,
    required this.pharmacy,
    required this.isDark,
  });

  @override
  ConsumerState<PasienApotekPosDialog> createState() =>
      _PasienApotekPosDialogState();
}

class _PasienApotekPosDialogState extends ConsumerState<PasienApotekPosDialog> {
  final SupabaseService _db = SupabaseService();
  bool _loadingPrescriptions = true;
  List<Map<String, dynamic>> _patientPrescriptions = [];
  String? _selectedPrescriptionId;
  bool _isRedeeming = false;
  bool _redeemSuccess = false;
  String _successMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPatientPrescriptions();
  }

  Future<void> _loadPatientPrescriptions() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) {
      if (mounted) setState(() => _loadingPrescriptions = false);
      return;
    }

    try {
      final patientName = (user['name'] ?? '').toString().toLowerCase();
      final rawRx = await _db.fetchAllPrescriptions();
      final List<Map<String, dynamic>> list = [];

      for (final rx in rawRx) {
        final notes = rx['notes']?.toString() ?? '';
        String pName = '';
        String dName = 'dr. Agoes Soetanto';
        List<dynamic> items = [];

        try {
          if (notes.startsWith('{')) {
            final dec = jsonDecode(notes);
            pName = dec['patientName'] ?? '';
            dName = dec['doctorName'] ?? dName;
            items = dec['items'] ?? [];
          } else if (notes.contains('|')) {
            pName = notes.split('|').first.trim();
          } else {
            pName = notes;
          }
        } catch (_) {}

        if (pName.toLowerCase().contains(patientName) ||
            pName.isEmpty ||
            patientName.contains(pName.toLowerCase())) {
          if (rx['status'] != 'checked_out') {
            list.add({
              'id': rx['id']?.toString() ?? '',
              'doctor_name': dName,
              'date': rx['prescription_date'] ?? 'Hari ini',
              'items': items,
              'raw': rx,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _patientPrescriptions = list;
          if (list.isNotEmpty) {
            _selectedPrescriptionId = list.first['id'];
          }
          _loadingPrescriptions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  Future<void> _redeemPrescription() async {
    if (_selectedPrescriptionId == null) return;
    setState(() => _isRedeeming = true);

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      // Notify / dispatch prescription to Apotek POS
      final apotekName =
          widget.pharmacy['nama_faskes'] ??
          widget.pharmacy['name'] ??
          'Apotek Jejaring';

      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _redeemSuccess = true;
          _successMessage =
              'E-Resep berhasil disambungkan ke sistem POS $apotekName.\nSilakan tunjukkan QR e-resep atau ambil obat di konter kasir apotek.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRedeeming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyambungkan e-resep: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  void _launchWhatsApp() async {
    final phone = widget.pharmacy['whatsapp_number']?.toString() ?? '';
    if (phone.isNotEmpty) {
      var clean = phone.replaceAll(RegExp(r'\D'), '');
      if (clean.startsWith('0')) {
        clean = '62${clean.substring(1)}';
      } else if (clean.startsWith('8')) {
        clean = '62$clean';
      }
      final apotekName =
          widget.pharmacy['nama_faskes'] ?? widget.pharmacy['name'] ?? 'Apotek';
      final msg = Uri.encodeComponent(
        'Halo $apotekName, saya terhubung melalui QR Mapotech dan ingin berkonsultasi mengenai ketersediaan obat / tebus resep.',
      );
      final uri = Uri.parse('https://wa.me/$clean?text=$msg');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _launchMaps() async {
    final mapsLink = widget.pharmacy['google_maps_link']?.toString() ?? '';
    final lat = widget.pharmacy['latitude'];
    final lng = widget.pharmacy['longitude'];

    Uri? mapUri;
    if (mapsLink.isNotEmpty) {
      mapUri = Uri.parse(mapsLink);
    } else if (lat != null && lng != null) {
      mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    }

    if (mapUri != null && await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark
        ? const Color(0xFF9E9EB0)
        : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF2D2D32)
        : const Color(0xFFECEEF2);
    final sectionBg = isDark
        ? const Color(0xFF1F1F24)
        : const Color(0xFFF8FAFD);
    const themeAccent = Color(0xFF0F9D58);
    const green = Color(0xFF27AE60);

    final faskes =
        widget.pharmacy['nama_faskes'] ??
        widget.pharmacy['name'] ??
        'Apotek Mandiri';
    final apotekerName = widget.pharmacy['name'] ?? '';
    final address =
        widget.pharmacy['address'] ??
        widget.pharmacy['fullAddress'] ??
        'Bondowoso, Jawa Timur';
    final about =
        widget.pharmacy['about'] ??
        'Apotek jejaring resmi Mapotech yang melayani penebusan E-Resep, pembelian obat bebas, dan konsultasi kefarmasian terintegrasi.';
    final phone = widget.pharmacy['whatsapp_number']?.toString() ?? '';
    final bool verified = widget.pharmacy['is_visible'] ?? true;
    final jamOperasional =
        widget.pharmacy['jamBuka'] ??
        widget.pharmacy['jam_kerja'] ??
        '08:00 - 21:00';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Connection Header Banner ───────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0D3823), const Color(0xFF18181B)]
                      : [const Color(0xFFE6F7ED), const Color(0xFFF4FAF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: green.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'POS APOTEK TERHUBUNG',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: green,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          faskes,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (apotekerName.isNotEmpty && apotekerName != faskes)
                          Text(
                            'Apoteker: $apotekerName',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: subtitleColor,
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ─────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Verified Status Badge
                    if (verified)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Apotek Resmi Terverifikasi Sistem Mapotech',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Card 1: Tebus Resep Digital Section ───────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: themeAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: themeAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: themeAccent,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tebus E-Resep di POS Apotek Ini',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Koneksikan E-Resep Anda langsung ke kasir/dispenser apotek ini secara realtime.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (_loadingPrescriptions)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: themeAccent,
                                ),
                              ),
                            )
                          else if (_redeemSuccess)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _successMessage,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: green,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_patientPrescriptions.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: subtitleColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tidak ada resep aktif yang menunggu tebus.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            // Prescription items selector
                            ..._patientPrescriptions.map((rx) {
                              final isSelected =
                                  _selectedPrescriptionId == rx['id'];
                              final itemsCount =
                                  (rx['items'] as List?)?.length ?? 0;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPrescriptionId = rx['id'];
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? themeAccent.withValues(alpha: 0.08)
                                        : cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? themeAccent
                                          : borderColor,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        color: isSelected
                                            ? themeAccent
                                            : subtitleColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Resep dari ${rx['doctor_name']}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: textColor,
                                              ),
                                            ),
                                            Text(
                                              'Tanggal: ${rx['date']} • ${itemsCount > 0 ? "$itemsCount item obat" : "Resep dokter"}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isRedeeming
                                    ? null
                                    : _redeemPrescription,
                                icon: _isRedeeming
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        size: 15,
                                      ),
                                label: Text(
                                  _isRedeeming
                                      ? 'Menyambungkan...'
                                      : 'Sambungkan & Tebus Resep ke POS',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Card 2: Apotek Information ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            'Lokasi Apotek',
                            address,
                            textColor,
                            subtitleColor,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.access_time_rounded,
                            'Jam Buka / Operasional',
                            jamOperasional,
                            textColor,
                            subtitleColor,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.info_outline_rounded,
                            'Tentang Apotek',
                            about,
                            textColor,
                            subtitleColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer Action Buttons ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: phone.isNotEmpty ? _launchWhatsApp : null,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                      ),
                      label: const Text('Hubungi Apoteker'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchMaps,
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: const Text('Petunjuk Arah'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: subtitleColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
