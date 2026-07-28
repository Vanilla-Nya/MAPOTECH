import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

class PuskesmasFormIbuHamil extends ConsumerStatefulWidget {
  const PuskesmasFormIbuHamil({super.key});

  @override
  ConsumerState<PuskesmasFormIbuHamil> createState() => _PuskesmasFormIbuHamilState();
}

class _PuskesmasFormIbuHamilState extends ConsumerState<PuskesmasFormIbuHamil> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nikController = TextEditingController(text: '3511084205940001');
  final TextEditingController _namaController = TextEditingController(text: 'Siti Rahmawati');
  final TextEditingController _tbController = TextEditingController(text: '158');
  final TextEditingController _bbController = TextEditingController(text: '62');
  final TextEditingController _lilaController = TextEditingController(text: '24.5');
  final TextEditingController _sistoleController = TextEditingController(text: '120');
  final TextEditingController _diastoleController = TextEditingController(text: '80');
  final TextEditingController _tfuController = TextEditingController(text: '26');
  final TextEditingController _djjController = TextEditingController(text: '142');
  final TextEditingController _hbController = TextEditingController(text: '11.5');
  final TextEditingController _catatanController = TextEditingController(text: 'Janin tunggal hidup, presentasi kepala, DJJ teratur 142x/mnt.');

  String _trimester = 'Trimester 3';
  String _kunjungan = 'K4';
  bool _ttdDiberikan = true;
  bool _tripleEliminasiNonReaktif = true;

  @override
  void dispose() {
    _nikController.dispose();
    _namaController.dispose();
    _tbController.dispose();
    _bbController.dispose();
    _lilaController.dispose();
    _sistoleController.dispose();
    _diastoleController.dispose();
    _tfuController.dispose();
    _djjController.dispose();
    _hbController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _simpanForm() {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEn
              ? 'Form Pemeriksaan Ibu Hamil (ANC 10T) berhasil disimpan & disinkronkan ke SatuSehat RME!'
              : 'Form Pemeriksaan Ibu Hamil (ANC 10T) berhasil disimpan & disinkronkan ke SatuSehat RME!',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFEC407A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = const Color(0xFFEC407A);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.assignment_rounded, size: 28, color: themeAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'DLC INOVASI STANDAR KEMENKES',
                              style: GoogleFonts.outfit(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: themeAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Form Digital Standar ANC 10T',
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Form Pemeriksaan Ibu Hamil',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        'Pengisian rekam medis digital antenatal care (ANC 10T) otomatis terkoneksi RME SatuSehat & BPJS P-Care.',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Form Body
          Form(
            key: _formKey,
            child: Column(
              children: [
                // 1. Identitas & Kunjungan
                _buildFormSection(
                  '1. Identitas & Status Kunjungan ANC',
                  Icons.person_rounded,
                  themeAccent,
                  cardBgColor,
                  borderColor,
                  textColor,
                  [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('NIK Ibu Hamil', _nikController, textColor, subtitleColor, borderColor, cardBgColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('Nama Lengkap Pasien', _namaController, textColor, subtitleColor, borderColor, cardBgColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown('Trimester Kehamilan', _trimester, ['Trimester 1', 'Trimester 2', 'Trimester 3'], (v) {
                            if (v != null) setState(() => _trimester = v);
                          }, textColor, cardBgColor, borderColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown('Kontak Kunjungan (ANC)', _kunjungan, ['K1', 'K2', 'K3', 'K4', 'K5', 'K6'], (v) {
                            if (v != null) setState(() => _kunjungan = v);
                          }, textColor, cardBgColor, borderColor),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Pemeriksaan Antropometri & Tensi (1T - 3T)
                _buildFormSection(
                  '2. Timbang, Tinggi Badan, Tensi & LILA (1T - 3T)',
                  Icons.monitor_weight_rounded,
                  themeAccent,
                  cardBgColor,
                  borderColor,
                  textColor,
                  [
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Tinggi Badan (cm)', _tbController, textColor, subtitleColor, borderColor, cardBgColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Berat Badan (kg)', _bbController, textColor, subtitleColor, borderColor, cardBgColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('LiLA (cm)', _lilaController, textColor, subtitleColor, borderColor, cardBgColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Sistole (mmHg)', _sistoleController, textColor, subtitleColor, borderColor, cardBgColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Diastole (mmHg)', _diastoleController, textColor, subtitleColor, borderColor, cardBgColor)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Pemeriksaan Janin & TFU (4T - 6T)
                _buildFormSection(
                  '3. Tentukan TFU, Presentasi Janin & DJJ (4T - 6T)',
                  Icons.child_care_rounded,
                  themeAccent,
                  cardBgColor,
                  borderColor,
                  textColor,
                  [
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Tinggi Fundus Uteri (TFU) cm', _tfuController, textColor, subtitleColor, borderColor, cardBgColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Denyut Jantung Janin (DJJ) x/mnt', _djjController, textColor, subtitleColor, borderColor, cardBgColor)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. Lab & Tablet Tambah Darah (7T - 10T)
                _buildFormSection(
                  '4. Lab Hb, TTD, Triple Eliminasi & Temu Wicara (7T - 10T)',
                  Icons.science_rounded,
                  themeAccent,
                  cardBgColor,
                  borderColor,
                  textColor,
                  [
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Kadar Hemoglobin (Hb) g/dL', _hbController, textColor, subtitleColor, borderColor, cardBgColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            activeColor: themeAccent,
                            title: Text('Pemberian TTD (90 Tablet)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                            value: _ttdDiberikan,
                            onChanged: (v) => setState(() => _ttdDiberikan = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      activeColor: themeAccent,
                      title: Text('Skrining Triple Eliminasi (HIV/Syphilis/Hepatitis B) Non-Reaktif', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                      value: _tripleEliminasiNonReaktif,
                      onChanged: (v) => setState(() => _tripleEliminasiNonReaktif = v),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Catatan Konseling & Temu Wicara Bidan/Dokter', _catatanController, textColor, subtitleColor, borderColor, cardBgColor, maxLines: 3),
                  ],
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Batal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: subtitleColor)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: _simpanForm,
                      icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Simpan Form ANC & Sync SatuSehat',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(
    String title,
    IconData icon,
    Color accentColor,
    Color bgColor,
    Color borderColor,
    Color textColor,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color textColor,
    Color subColor,
    Color borderColor,
    Color bgColor, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subColor)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: bgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFEC407A))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    Color textColor,
    Color bgColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
