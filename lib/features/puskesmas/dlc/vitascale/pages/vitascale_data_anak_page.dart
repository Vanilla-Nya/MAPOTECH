import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/vitascale_models.dart';
import '../data/vitascale_repository.dart';
import '../vitascale_dlc_gate.dart';
import '../widgets/vitascale_child_map_card.dart';
import 'vitascale_child_history_page.dart';

class VitaScaleDataAnakPage extends ConsumerStatefulWidget {
  final ValueChanged<String>? onNavigateToMenu;
  final void Function(String menu, ChildProfile? child)? onNavigateWithChild;

  const VitaScaleDataAnakPage({
    super.key,
    this.onNavigateToMenu,
    this.onNavigateWithChild,
  });

  @override
  ConsumerState<VitaScaleDataAnakPage> createState() =>
      _VitaScaleDataAnakPageState();
}

class _VitaScaleDataAnakPageState extends ConsumerState<VitaScaleDataAnakPage> {
  final VitaScaleRepository _repository = VitaScaleRepository();
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  List<ChildProfile> _children = [];
  bool _isLoading = true;
  ChildProfile? _selectedChildForHistory;

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddChildRegistrationDialog(
        repository: _repository,
        existingChildren: _children,
        onChildRegistered: (newChild) {
          _repository.registerChild(newChild);
          setState(() {
            // Hapus duplikat bila ada, lalu sisipkan di posisi teratas
            _children.removeWhere(
              (c) =>
                  c.id == newChild.id ||
                  (newChild.nik != '-' && c.nik == newChild.nik),
            );
            _children.insert(0, newChild);
          });
          CustomSnackbar.success(
            context,
            'Pasien balita ${newChild.name} (NIK: ${newChild.nik}) berhasil didaftarkan ke faskes Puskesmas ini.',
          );
        },
      ),
    );
  }

  void _contactParent(ChildProfile child) {
    final phone = (child.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return;

    final formattedPhone = phone.startsWith('0') ? '62${phone.substring(1)}' : phone;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF27AE60), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hubungi Orang Tua / Wali Balita',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Pasien: ${child.name} • Wali: ${child.parentName} (${child.phone})',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFF25D366).withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                ),
                title: Text('Kirim Pengingat WhatsApp', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Kirim pesan otomatis jadwal posyandu & imunisasi balita', style: GoogleFonts.outfit(fontSize: 10.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final msg = Uri.encodeComponent(
                    'Halo Bapak/Ibu ${child.parentName}, kami dari Puskesmas mengingatkan jadwal pemeriksaan antropometri dan tumbuh kembang ananda ${child.name} (${child.ageLabel}). Mohon kehadirannya di Posyandu/Puskesmas. Terima kasih.',
                  );
                  final waUri = Uri.parse('https://wa.me/$formattedPhone?text=$msg');
                  if (await canLaunchUrl(waUri)) {
                    await launchUrl(waUri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFF2980B9).withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2980B9).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: Color(0xFF2980B9), size: 18),
                ),
                title: Text('Panggilan Telepon Langsung', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Hubungi via jaringan seluler ke nomor ${child.phone}', style: GoogleFonts.outfit(fontSize: 10.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final telUri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(telUri)) {
                    await launchUrl(telUri);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openHomeVisitMap(ChildProfile child) {
    CustomSnackbar.info(
      context,
      'Pasien ${child.name} tidak memiliki nomor kontak. Petugas kesehatan/kader dapat melakukan Home Visit ke: ${child.address} (Koordinat: ${child.latitude}, ${child.longitude}).',
      title: 'Tugaskan Kunjungan Rumah (Home Visit)',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedChildForHistory != null) {
      return VitaScaleChildHistoryPage(
        child: _selectedChildForHistory!,
        onBack: () {
          setState(() {
            _selectedChildForHistory = null;
          });
        },
        onStartScreening: (child) {
          if (widget.onNavigateWithChild != null) {
            widget.onNavigateWithChild!('dlc_vitascale_screening', child);
          } else if (widget.onNavigateToMenu != null) {
            widget.onNavigateToMenu!('dlc_vitascale_screening');
          }
        },
      );
    }

    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = state.appearance == 'dark';
    final isEn = state.language == 'en';

    final filtered = _children.where((c) {
      if (_selectedFilter == 'Balita < 5 Thn') {
        return c.isBalita;
      } else if (_selectedFilter == 'Bayi < 24 Bln') {
        return c.isUnder24Months;
      } else if (_selectedFilter == 'Anak ≥ 24 Bln') {
        return !c.isUnder24Months;
      }
      return true;
    }).toList();

    final balitaCount = _children.where((c) => c.isBalita).length;

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
                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.child_care_rounded,
                      size: 30,
                      color: Color(0xFF1ABC9C),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                                color: const Color(
                                  0xFF1ABC9C,
                                ).withValues(alpha: 0.15),
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
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Collapsible Summary Metric Cards (4 Cards - Default Closed saat Page Awal Dibuka)
            CustomCollapsibleCard(
              title: 'Ringkasan Statistik & Indikator Pasien',
              subtitle:
                  '4 Metrik Sasaran: Total Pasien Anak, Bayi PB, Anak TB, dan Kesiapan Skrining',
              icon: Icons.analytics_rounded,
              iconColor: const Color(0xFF1ABC9C),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              accentColor: const Color(0xFF1ABC9C),
              initiallyExpanded:
                  false, // WAKTU PAGE AWAL DIBUKA COLLAPSIBLE CARDNYA TERTUTUP
              previewBadge: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_children.length} Anak • 4 Metrik',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1ABC9C),
                  ),
                ),
              ),
              child: GridView.count(
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
                    count: '${_children.length} Anak ($balitaCount Balita)',
                    subtitleColor: subtitleColor,
                    countColor: textColor,
                    cardBgColor: isDark
                        ? const Color(0xFF1B1B26)
                        : const Color(0xFFF8FAFC),
                    borderColor: borderColor,
                  ),
                  MetricCard(
                    icon: Icons.crib_rounded,
                    label: 'BAYI < 24 BULAN (PB)',
                    count:
                        '${_children.where((c) => c.isUnder24Months).length} Bayi',
                    subtitleColor: subtitleColor,
                    countColor: const Color(0xFF3498DB),
                    cardBgColor: isDark
                        ? const Color(0xFF1B1B26)
                        : const Color(0xFFF8FAFC),
                    borderColor: borderColor,
                  ),
                  MetricCard(
                    icon: Icons.accessibility_new_rounded,
                    label: 'ANAK ≥ 24 BULAN (TB)',
                    count:
                        '${_children.where((c) => !c.isUnder24Months).length} Anak',
                    subtitleColor: subtitleColor,
                    countColor: const Color(0xFFE67E22),
                    cardBgColor: isDark
                        ? const Color(0xFF1B1B26)
                        : const Color(0xFFF8FAFC),
                    borderColor: borderColor,
                  ),
                  MetricCard(
                    icon: Icons.verified_user_rounded,
                    label: 'SIAP SKRINING',
                    count: '100%',
                    subtitleColor: subtitleColor,
                    countColor: const Color(0xFF2ECC71),
                    cardBgColor: isDark
                        ? const Color(0xFF1B1B26)
                        : const Color(0xFFF8FAFC),
                    borderColor: borderColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Peta Lokasi Pasien Anak & Balita (Geotagging & Batas Wilayah RevGeo API)
            VitaScaleChildMapCard(
              children: filtered,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              themeAccent: const Color(0xFF1ABC9C),
              isDark: isDark,
              isMobile: isMobile,
              isEn: state.language == 'en',
            ),

            const SizedBox(height: 24),

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
                    onClear: () {
                      _searchQuery = '';
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
                      icon: const Icon(
                        Icons.filter_list_rounded,
                        size: 18,
                        color: Color(0xFF1ABC9C),
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      dropdownColor: cardBgColor,
                      items:
                          [
                            'Semua',
                            'Balita < 5 Thn',
                            'Bayi < 24 Bln',
                            'Anak ≥ 24 Bln',
                          ].map((f) {
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
              CustomPageLoader(
                message: isEn
                    ? 'Loading child records & measurements...'
                    : 'Memuat data sasaran anak & penimbangan...',
                skeleton: const SkeletonChildrenList(),
              )
            else if (filtered.isEmpty)
              EmptyStateWidget(
                icon: Icons.child_care_rounded,
                title: _searchQuery.isNotEmpty
                    ? 'Tidak Ditemukan Pasien Anak'
                    : 'Belum Ada Data Pasien Anak',
                subtitle: _searchQuery.isNotEmpty
                    ? 'Tidak ada anak dengan NIK atau Nama "$_searchQuery" pada filter $_selectedFilter.'
                    : 'Gunakan tombol "+ Daftar Anak Baru" untuk menambahkan sasaran dari Mapotech atau input manual.',
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
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final child = filtered[index];
                  final isUnder24 = child.isUnder24Months;

                  return CustomCard(
                    color: cardBgColor,
                    borderColor: borderColor,
                    padding: const EdgeInsets.all(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VitaScaleChildHistoryPage(child: child),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // Avatar Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                (child.gender == 'L'
                                        ? const Color(0xFF3498DB)
                                        : const Color(0xFFE91E63))
                                    .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isUnder24
                                ? Icons.child_friendly_rounded
                                : Icons.face_rounded,
                            color: child.gender == 'L'
                                ? const Color(0xFF3498DB)
                                : const Color(0xFFE91E63),
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
                                  Flexible(
                                    child: Text(
                                      child.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
                                  if (child.isBalita)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: StatusBadge(
                                        label: 'BALITA',
                                        color: const Color(0xFF1ABC9C),
                                        fontSize: 8.5,
                                        showDot: false,
                                      ),
                                    ),
                                  StatusBadge(
                                    label: isUnder24
                                        ? 'PB (TELENTANG)'
                                        : 'TB (BERDIRI)',
                                    color: isUnder24
                                        ? const Color(0xFF3498DB)
                                        : const Color(0xFFE67E22),
                                    fontSize: 9,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NIK: ${child.nik} • Usia: ${child.ageLabel} (${child.ageInMonths} Bulan) • Wali: ${child.parentName}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: subtitleColor,
                                ),
                              ),
                              Text(
                                'Alamat: ${child.address} • Telp: ${child.phone?.isNotEmpty == true ? child.phone : "-"}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: subtitleColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (child.phone != null && child.phone!.trim().isNotEmpty && child.phone != '-')
                              CustomButton(
                                text: 'Hubungi WA',
                                icon: Icons.chat_rounded,
                                height: 38,
                                primaryColor: const Color(0xFF27AE60),
                                isSecondary: true,
                                onPressed: () => _contactParent(child),
                              )
                            else
                              CustomButton(
                                text: 'Peta (Home Visit)',
                                icon: Icons.pin_drop_rounded,
                                height: 38,
                                primaryColor: const Color(0xFF2980B9),
                                isSecondary: true,
                                onPressed: () => _openHomeVisitMap(child),
                              ),
                            // Tombol Pemeriksaan / Kunjungan
                            CustomButton(
                              text: 'Pemeriksaan / Kunjungan',
                              icon: Icons.assignment_outlined,
                              height: 38,
                              primaryColor: const Color(0xFF1ABC9C),
                              onPressed: () {
                                setState(() {
                                  _selectedChildForHistory = child;
                                });
                              },
                            ),
                          ],
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

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG REGISTRASI: CARI BALITA MAPOTECH & INPUT MANUAL
// ─────────────────────────────────────────────────────────────────────────────

class _AddChildRegistrationDialog extends ConsumerStatefulWidget {
  final IVitaScaleRepository repository;
  final List<ChildProfile> existingChildren;
  final ValueChanged<ChildProfile> onChildRegistered;

  const _AddChildRegistrationDialog({
    required this.repository,
    required this.existingChildren,
    required this.onChildRegistered,
  });

  @override
  ConsumerState<_AddChildRegistrationDialog> createState() =>
      _AddChildRegistrationDialogState();
}

class _AddChildRegistrationDialogState
    extends ConsumerState<_AddChildRegistrationDialog> {
  int _activeTab = 0; // 0 = Cari Balita Mapotech, 1 = Input Manual Baru

  // Controller Pencarian Mapotech
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedAgeFilter = 'Balita (< 5 Thn)';
  bool _isSearching = false;
  List<ChildProfile> _mapotechCandidates = [];
  ChildProfile? _selectedBalita;

  // Controller Form Pasien
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _nikCtrl = TextEditingController();
  final TextEditingController _parentCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  DateTime _selectedBirthDate = DateTime.now().subtract(
    const Duration(days: 365),
  );
  String _selectedGender = 'L';

  final List<String> _ageFilterOptions = const [
    'Balita (< 5 Thn)',
    'Bayi (< 24 Bln)',
    'Anak (≥ 24 Bln)',
    'Semua (0-12 Thn)',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMapotechBalita();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _nikCtrl.dispose();
    _parentCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMapotechBalita({String? query, String? ageFilter}) async {
    setState(() => _isSearching = true);
    final results = await widget.repository.searchMapotechRegisteredBalita(
      query: query ?? _searchCtrl.text,
      ageFilter: ageFilter ?? _selectedAgeFilter,
    );
    if (mounted) {
      setState(() {
        _mapotechCandidates = results;
        _isSearching = false;
      });
    }
  }

  void _onSelectBalita(ChildProfile balita) {
    setState(() {
      _selectedBalita = balita;
      _nameCtrl.text = balita.name;
      _nikCtrl.text = balita.nik != '-' ? balita.nik : '';
      _parentCtrl.text = balita.parentName;
      _addressCtrl.text = balita.address;
      _phoneCtrl.text = balita.phone ?? '';
      _selectedBirthDate = balita.birthDate;
      _selectedGender = balita.gender;
    });
  }

  void _submitRegistration() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      CustomSnackbar.error(context, 'Nama anak wajib diisi.');
      return;
    }

    final nik = _nikCtrl.text.trim();
    if (nik.isNotEmpty && nik != '-') {
      if (nik.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nik)) {
        CustomSnackbar.error(context, 'NIK anak harus 16 digit angka numerik.');
        return;
      }

      // Cek apakah balita sudah terdaftar di daftar puskesmas ini
      final alreadyRegistered = widget.existingChildren.any(
        (c) => c.nik == nik,
      );
      if (alreadyRegistered) {
        CustomSnackbar.error(
          context,
          'Balita dengan NIK $nik sudah terdaftar di faskes Puskesmas ini.',
        );
        return;
      }
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      if (phone.length < 10 ||
          phone.length > 13 ||
          !RegExp(r'^\d{10,13}$').hasMatch(phone)) {
        CustomSnackbar.error(
          context,
          'Nomor telepon harus angka numerik antara 10 - 13 digit.',
        );
        return;
      }
    }

    final newChild = ChildProfile(
      id:
          _selectedBalita?.id ??
          'ANK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      name: name,
      nik: nik.isEmpty ? '-' : nik,
      birthDate: _selectedBirthDate,
      gender: _selectedGender,
      parentName: _parentCtrl.text.trim().isEmpty
          ? 'Wali Terdaftar'
          : _parentCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? 'Puskesmas'
          : _addressCtrl.text.trim(),
      phone: phone,
      noKk: _selectedBalita?.noKk,
      latitude:
          _selectedBalita?.latitude ??
          (-7.9580 + (DateTime.now().second * 0.0002)),
      longitude:
          _selectedBalita?.longitude ??
          (113.9120 + (DateTime.now().second * 0.0002)),
    );

    widget.onChildRegistered(newChild);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isUnder24 =
        DateTime.now().difference(_selectedBirthDate).inDays < 730;

    return CustomDialog(
      title: 'Pendaftaran Sasaran Balita & Anak',
      icon: Icons.person_add_rounded,
      iconColor: const Color(0xFF1ABC9C),
      maxWidth: 620,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab Switcher Segments
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF22222E)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        index: 0,
                        title: 'Cari Balita Mapotech',
                        subtitle: 'Rekomendasi • NIK / Usia',
                        icon: Icons.person_search_rounded,
                        isSelected: _activeTab == 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildTabButton(
                        index: 1,
                        title: 'Input Manual Baru',
                        subtitle: _selectedBalita != null
                            ? 'Data Terisi'
                            : 'Pasien Belum Ada',
                        icon: Icons.edit_note_rounded,
                        isSelected: _activeTab == 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ===============================================================
              // TAB 0: CARI BALITA TERDAFTAR DI MAPOTECH
              // ===============================================================
              if (_activeTab == 0) ...[
                // Info Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: Color(0xFF1ABC9C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cari balita yang sudah terdaftar di Mapotech berdasarkan NIK atau Nama dan filter usia untuk registrasi cepat ke Puskesmas.',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1ABC9C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Search Bar Input
                CustomSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Cari NIK 16 digit atau Nama Balita di Mapotech...',
                  onChanged: (v) => _fetchMapotechBalita(query: v),
                  onClear: () {
                    _searchCtrl.clear();
                    _fetchMapotechBalita(query: '');
                  },
                ),

                const SizedBox(height: 10),

                // Filter Usia Horizontal Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _ageFilterOptions.map((f) {
                      final isSelected = _selectedAgeFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedAgeFilter = f);
                            _fetchMapotechBalita(ageFilter: f);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1ABC9C)
                                  : (isDark
                                        ? const Color(0xFF22222E)
                                        : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1ABC9C)
                                    : borderColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  f.contains('Bayi')
                                      ? Icons.crib_rounded
                                      : f.contains('Balita')
                                      ? Icons.child_care_rounded
                                      : Icons.people_outline_rounded,
                                  size: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : subtitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  f,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // List Hasil Pencarian Balita Mapotech
                Text(
                  'Daftar Pasien Balita Mapotech (${_mapotechCandidates.length} ditemukan)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),

                const SizedBox(height: 6),

                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A24)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: _isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1ABC9C),
                          ),
                        )
                      : _mapotechCandidates.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 36,
                                  color: subtitleColor,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tidak Ditemukan Balita Terdaftar',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Coba cari dengan NIK lain atau beralih ke tab "Input Manual Baru".',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: subtitleColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _mapotechCandidates.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final child = _mapotechCandidates[i];
                            final isSelected =
                                _selectedBalita?.nik == child.nik &&
                                child.nik != '-';
                            final isAlreadyInFaskes = widget.existingChildren
                                .any((c) => c.nik != '-' && c.nik == child.nik);

                            return InkWell(
                              onTap: () => _onSelectBalita(child),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFF1ABC9C,
                                        ).withValues(alpha: 0.12)
                                      : cardBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1ABC9C)
                                        : borderColor,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Gender Avatar
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color:
                                            (child.gender == 'L'
                                                    ? const Color(0xFF3498DB)
                                                    : const Color(0xFFE91E63))
                                                .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        child.isUnder24Months
                                            ? Icons.child_friendly_rounded
                                            : Icons.face_rounded,
                                        size: 18,
                                        color: child.gender == 'L'
                                            ? const Color(0xFF3498DB)
                                            : const Color(0xFFE91E63),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  child.name,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              StatusBadge(
                                                label: child.gender == 'L'
                                                    ? 'L'
                                                    : 'P',
                                                color: child.gender == 'L'
                                                    ? const Color(0xFF3498DB)
                                                    : const Color(0xFFE91E63),
                                                fontSize: 8,
                                                showDot: false,
                                              ),
                                              const SizedBox(width: 4),
                                              StatusBadge(
                                                label: child.ageLabel,
                                                color: child.isUnder24Months
                                                    ? const Color(0xFF3498DB)
                                                    : const Color(0xFFE67E22),
                                                fontSize: 8,
                                                showDot: false,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'NIK: ${child.nik} • Wali: ${child.parentName}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              color: subtitleColor,
                                            ),
                                          ),
                                          Text(
                                            child.address,
                                            style: GoogleFonts.outfit(
                                              fontSize: 9.5,
                                              color: subtitleColor.withValues(
                                                alpha: 0.8,
                                              ),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isAlreadyInFaskes)
                                      StatusBadge(
                                        label: 'Sudah di Faskes',
                                        color: Colors.grey,
                                        fontSize: 8.5,
                                        showDot: false,
                                      )
                                    else if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1ABC9C),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Terpilih ✓',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    else
                                      CustomButton(
                                        text: 'Pilih',
                                        height: 28,
                                        isSecondary: true,
                                        onPressed: () => _onSelectBalita(child),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Info Box Balita Terpilih
                if (_selectedBalita != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1ABC9C)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFF1ABC9C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Balita Terpilih: ${_selectedBalita!.name}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: _selectedBalita!.isUnder24Months
                                  ? 'PB (TELENTANG)'
                                  : 'TB (BERDIRI)',
                              color: _selectedBalita!.isUnder24Months
                                  ? const Color(0xFF3498DB)
                                  : const Color(0xFFE67E22),
                              fontSize: 8.5,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NIK: ${_selectedBalita!.nik} • Usia: ${_selectedBalita!.ageLabel} (${_selectedBalita!.ageInMonths} Bulan) • Wali: ${_selectedBalita!.parentName}',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: subtitleColor,
                          ),
                        ),
                        Text(
                          'Domisili: ${_selectedBalita!.address} • Telp: ${_selectedBalita!.phone?.isNotEmpty == true ? _selectedBalita!.phone : "-"}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'Daftarkan Langsung ke Faskes',
                                icon: Icons.person_add_alt_1_rounded,
                                height: 34,
                                primaryColor: const Color(0xFF1ABC9C),
                                onPressed: _submitRegistration,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CustomButton(
                              text: 'Tinjau / Edit Form',
                              icon: Icons.edit_rounded,
                              height: 34,
                              isSecondary: true,
                              onPressed: () => setState(() => _activeTab = 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // ===============================================================
              // TAB 1: FORM / INPUT MANUAL PASIEN BARU
              // ===============================================================
              if (_activeTab == 1) ...[
                if (_selectedBalita != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF1ABC9C).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: Color(0xFF1ABC9C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Form telah terisi otomatis dari pasien Mapotech. Anda dapat melengkapi informasi jika diperlukan.',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: const Color(0xFF1ABC9C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                CustomTextField(
                  label: 'Nama Lengkap Anak *',
                  hintText: 'Masukkan nama lengkap sesuai KIA / KK',
                  controller: _nameCtrl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'NIK Anak (16 Digit)',
                        hintText: '35110xxxxxxxxxxx',
                        controller: _nikCtrl,
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
                        value: _selectedGender,
                        items: const [
                          CustomDropdownItem(
                            value: 'L',
                            label: 'Laki-laki (L)',
                          ),
                          CustomDropdownItem(
                            value: 'P',
                            label: 'Perempuan (P)',
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedGender = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomDateField(
                  label: 'Tanggal Lahir',
                  selectedDate: _selectedBirthDate,
                  onDateSelected: (d) =>
                      setState(() => _selectedBirthDate = d ?? DateTime.now()),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
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
                  controller: _parentCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Alamat Domisili',
                  hintText: 'Dusun, RT/RW, Desa',
                  controller: _addressCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'No. Telepon / WhatsApp Wali (10-13 Digit)',
                  hintText: '08xxxxxxxxxx',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 13,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        CustomButton(
          text: 'Batal',
          isSecondary: true,
          height: 38,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        CustomButton(
          text: _activeTab == 0 && _selectedBalita != null
              ? 'Daftarkan Balita Terpilih'
              : 'Simpan Pasien',
          isSecondary: false,
          height: 38,
          primaryColor: const Color(0xFF1ABC9C),
          icon: Icons.check_circle_rounded,
          onPressed: _submitRegistration,
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ABC9C) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected ? Colors.white : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
