import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import '../data/vitascale_models.dart';
import '../data/vitascale_repository.dart';
import '../vitascale_dlc_gate.dart';
import 'vitascale_screening_page.dart';

class VitaScaleDataAnakPage extends ConsumerStatefulWidget {
  final ValueChanged<String>? onNavigateToMenu;

  const VitaScaleDataAnakPage({
    super.key,
    this.onNavigateToMenu,
  });

  @override
  ConsumerState<VitaScaleDataAnakPage> createState() => _VitaScaleDataAnakPageState();
}

class _VitaScaleDataAnakPageState extends ConsumerState<VitaScaleDataAnakPage> {
  final VitaScaleRepository _repository = VitaScaleRepository();
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  List<ChildProfile> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    final results = await _repository.searchChildren(query: _searchQuery);
    if (mounted) {
      setState(() {
        _children = results;
        _isLoading = false;
      });
    }
  }

  void _openAddChildDialog() {
    final nameCtrl = TextEditingController();
    final nikCtrl = TextEditingController();
    final parentCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    DateTime selectedBirthDate = DateTime.now().subtract(const Duration(days: 365));
    String selectedGender = 'L';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isUnder24 = DateTime.now().difference(selectedBirthDate).inDays < 730;

          return CustomDialog(
            title: 'Daftarkan Pasien Anak / Bayi Baru',
            icon: Icons.person_add_rounded,
            iconColor: const Color(0xFF1ABC9C),
            maxWidth: 520,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  label: 'Nama Lengkap Anak',
                  hintText: 'Masukkan nama lengkap sesuai KIA / KK',
                  controller: nameCtrl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'NIK Anak (16 Digit)',
                        hintText: '35110xxxxxxxxxxx',
                        controller: nikCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 16,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomDropdown<String>(
                        label: 'Jenis Kelamin',
                        value: selectedGender,
                        items: const [
                          CustomDropdownItem(value: 'L', label: 'Laki-laki (L)'),
                          CustomDropdownItem(value: 'P', label: 'Perempuan (P)'),
                        ],
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedGender = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomDateField(
                  label: 'Tanggal Lahir',
                  selectedDate: selectedBirthDate,
                  onDateSelected: (d) => setModalState(() => selectedBirthDate = d ?? DateTime.now()),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUnder24
                        ? 'Rekomendasi WHO: Usia < 24 Bulan → Mode Panjang Badan Telentang (Infantometer)'
                        : 'Rekomendasi WHO: Usia ≥ 24 Bulan → Mode Tinggi Badan Berdiri (Stadiometer)',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1ABC9C),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Nama Orang Tua / Wali',
                  hintText: 'Nama Ayah / Ibu',
                  controller: parentCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Alamat Domisili',
                  hintText: 'Dusun, RT/RW, Desa',
                  controller: addressCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'No. Telepon / WhatsApp Wali (11-13 Digit)',
                  hintText: '08xxxxxxxxxx',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 13,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                ),
              ],
            ),
            actions: [
              CustomButton(
                text: 'Batal',
                isSecondary: true,
                height: 38,
                onPressed: () => Navigator.pop(ctx),
              ),
              const SizedBox(width: 8),
              CustomButton(
                text: 'Simpan Pasien',
                isSecondary: false,
                height: 38,
                primaryColor: const Color(0xFF1ABC9C),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    CustomSnackbar.error(context, 'Nama anak wajib diisi.');
                    return;
                  }
                  final nikVal = nikCtrl.text.trim();
                  if (nikVal.isNotEmpty && nikVal != '-') {
                    if (nikVal.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikVal)) {
                      CustomSnackbar.error(context, 'NIK anak harus 16 digit angka numerik.');
                      return;
                    }
                  }
                  final phoneVal = phoneCtrl.text.trim();
                  if (phoneVal.isNotEmpty) {
                    if (phoneVal.length < 11 || phoneVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(phoneVal)) {
                      CustomSnackbar.error(context, 'Nomor telepon harus angka numerik antara 11 - 13 digit.');
                      return;
                    }
                  }
                  final newChild = ChildProfile(
                    id: 'ANK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    name: nameCtrl.text.trim(),
                    nik: nikCtrl.text.trim().isEmpty ? '-' : nikCtrl.text.trim(),
                    birthDate: selectedBirthDate,
                    gender: selectedGender,
                    parentName: parentCtrl.text.trim().isEmpty ? 'Wali' : parentCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty ? 'Puskesmas' : addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
                  setState(() {
                    _children.insert(0, newChild);
                  });
                  Navigator.pop(ctx);
                  CustomSnackbar.success(
                    context,
                    'Pasien anak ${newChild.name} berhasil didaftarkan.',
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final filtered = _children.where((c) {
      if (_selectedFilter == 'Bayi < 24 Bln') {
        return c.isUnder24Months;
      } else if (_selectedFilter == 'Anak ≥ 24 Bln') {
        return !c.isUnder24Months;
      }
      return true;
    }).toList();

    return VitaScaleDlcGate(
      menuTitle: 'Data Anak & Bayi (0–12 Tahun)',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Banner Header
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
                      color: const Color(0xFF1ABC9C).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.child_care_rounded, size: 30, color: Color(0xFF1ABC9C)),
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
                                color: const Color(0xFF1ABC9C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'DLC VITASCALE - PUSKESMAS',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1ABC9C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'IoT & Zero-Install Computer Vision',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: subtitleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Data Pasien Anak & Bayi (0–12 Tahun)',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Pusat data sasaran pengukuran antropometri berkala balita & anak faskes Puskesmas.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Summary KPI Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                MetricCard(
                  icon: Icons.child_friendly_rounded,
                  label: 'TOTAL PASIEN ANAK',
                  count: '${_children.length} Anak',
                  subtitleColor: subtitleColor,
                  countColor: textColor,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
                MetricCard(
                  icon: Icons.crib_rounded,
                  label: 'BAYI < 24 BULAN (PB)',
                  count: '${_children.where((c) => c.isUnder24Months).length} Bayi',
                  subtitleColor: subtitleColor,
                  countColor: const Color(0xFF3498DB),
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
                MetricCard(
                  icon: Icons.accessibility_new_rounded,
                  label: 'ANAK ≥ 24 BULAN (TB)',
                  count: '${_children.where((c) => !c.isUnder24Months).length} Anak',
                  subtitleColor: subtitleColor,
                  countColor: const Color(0xFFE67E22),
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
                MetricCard(
                  icon: Icons.verified_user_rounded,
                  label: 'SIAP SKRINING',
                  count: '100%',
                  subtitleColor: subtitleColor,
                  countColor: const Color(0xFF2ECC71),
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Search Bar & Filter Controls
            Row(
              children: [
                Expanded(
                  child: CustomSearchBar(
                    hintText: 'Cari Nama Anak, NIK, atau Nama Orang Tua...',
                    onChanged: (v) {
                      _searchQuery = v;
                      _loadChildren();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 48,
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      icon: const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF1ABC9C)),
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                      dropdownColor: cardBgColor,
                      items: ['Semua', 'Bayi < 24 Bln', 'Anak ≥ 24 Bln'].map((f) {
                        return DropdownMenuItem(value: f, child: Text(f));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedFilter = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CustomButton(
                  text: 'Daftar Anak Baru',
                  icon: Icons.person_add_rounded,
                  height: 48,
                  primaryColor: const Color(0xFF1ABC9C),
                  onPressed: _openAddChildDialog,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Daftar Kartu Pasien Anak
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1ABC9C))),
              )
            else if (filtered.isEmpty)
              EmptyStateWidget(
                icon: Icons.child_care_rounded,
                title: 'Belum Ada Data Pasien Anak',
                subtitle: 'Gunakan tombol "+ Daftar Anak Baru" untuk menambahkan sasaran skrining.',
                cardBg: cardBgColor,
                border: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final child = filtered[index];
                  final isUnder24 = child.isUnder24Months;

                  return CustomCard(
                    color: cardBgColor,
                    borderColor: borderColor,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        // Avatar Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63))
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isUnder24 ? Icons.child_friendly_rounded : Icons.face_rounded,
                            color: child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Data Detail
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    child.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(
                                    label: child.gender == 'L' ? 'L' : 'P',
                                    color: child.gender == 'L'
                                        ? const Color(0xFF3498DB)
                                        : const Color(0xFFE91E63),
                                    fontSize: 9,
                                    showDot: false,
                                  ),
                                  const SizedBox(width: 6),
                                  StatusBadge(
                                    label: isUnder24 ? 'PB (TELENTANG)' : 'TB (BERDIRI)',
                                    color: isUnder24 ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                                    fontSize: 9,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NIK: ${child.nik} • Usia: ${child.ageLabel} • Wali: ${child.parentName}',
                                style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                              ),
                              Text(
                                'Alamat: ${child.address}',
                                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor.withOpacity(0.8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tombol Mulai Skrining
                        CustomButton(
                          text: 'Mulai Skrining',
                          icon: Icons.play_arrow_rounded,
                          height: 38,
                          primaryColor: const Color(0xFF1ABC9C),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VitaScaleScreeningPage(
                                  selectedChild: child,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
