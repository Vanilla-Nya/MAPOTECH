import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/animated_portal_switcher.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/animated_transitions.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/widgets/location_selector_widget.dart';
import 'package:mapotech/shared/location_service.dart';
import 'dart:async';

/// Shows the premium login modal dialog.
void showLoginModal(BuildContext context, WidgetRef ref) {
  showAnimatedDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _LoginModalContent(ref: ref, isDark: false),
      );
    },
  );
}

/// Shows the premium registration modal dialog with multi-step flow.
void showRegisterModal(BuildContext context, WidgetRef ref) {
  showAnimatedDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _RegisterModalContent(ref: ref, isDark: false),
      );
    },
  );
}

// ==================== LOGIN MODAL CONTENT ====================

class _LoginModalContent extends StatefulWidget {
  final WidgetRef ref;
  final bool isDark;

  const _LoginModalContent({required this.ref, required this.isDark});

  @override
  State<_LoginModalContent> createState() => _LoginModalContentState();
}

class _LoginModalContentState extends State<_LoginModalContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ref.watch(landingPageProvider);
    final notifier = widget.ref.read(landingPageProvider.notifier);

    // Identify if active portal is "Segera" (Soon)
    final soonPortals = [
      'klinik',
      'rumahsakit',
      'posyandu',
    ];
    final isSoonActive = soonPortals.contains(state.activeTab);

    final activeTab = state.activeTab;
    final isRev = state.appearance == 'rev';

    final isDark = state.appearance == 'dark';
    final bgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final fieldBg = isDark ? const Color(0xFF252528) : const Color(0xFFF6F3FC);

    final accentPurple = isRev
        ? const Color(0xFFB577F2)
        : const Color(0xFF48C9B0);

    final titleGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFB577F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    final btnGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFD6A4F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    final isMobile = MediaQuery.of(context).size.width < 768;

    // Disabled visual properties if soon
    final fieldColorText = isSoonActive
        ? subtitleColor.withOpacity(0.6)
        : textColor;

    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 24 : 36),
      child: Stack(
        children: [
          // Close Button
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Welcome title with gradient styling
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: titleGradient,
                  ).createShader(bounds),
                  child: Text(
                    state.language == 'id' ? 'Selamat Datang' : 'Welcome Back',
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // EMAIL FIELD
              Text(
                'EMAIL',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: subtitleColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: subtitleColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isSoonActive
                          ? Container(
                              alignment: Alignment.centerLeft,
                              height: 48,
                              child: Text(
                                'SEGERA',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: fieldColorText,
                                ),
                              ),
                            )
                          : TextField(
                              controller: _emailController,
                              enabled: true,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: 'name@company.com',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: subtitleColor.withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PASSWORD FIELD
              Text(
                state.language == 'id' ? 'KATA SANDI' : 'PASSWORD',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: subtitleColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: subtitleColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isSoonActive
                          ? Container(
                              alignment: Alignment.centerLeft,
                              height: 48,
                              child: Text(
                                '••••••••',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: fieldColorText,
                                ),
                              ),
                            )
                          : TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              enabled: true,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: subtitleColor.withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                    ),
                    if (!isSoonActive)
                      IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                          color: subtitleColor,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // MAIN ACTION BUTTON
              if (isSoonActive)
                // Disabled Segera button
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        btnGradient[0].withOpacity(0.4),
                        btnGradient[1].withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'SEGERA',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                )
              else
                CustomButton(
                  text: state.language == 'id' ? 'MASUK' : 'LOGIN',
                  height: 48,
                  isGradient: true,
                  gradientColors: btnGradient,
                  onPressed: () async {
                    final username = _emailController.text.trim();
                    final password = _passwordController.text;

                    if (username.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text(
                            state.language == 'id'
                                ? 'Email/Username dan password tidak boleh kosong!'
                                : 'Email/Username and password cannot be empty!',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    // 1. Offline/Static Fallback check first (instant bypass for demo accounts)
                    bool isStaticValid = false;
                    String staticRole = 'pasien';
                    String staticName = 'Alvin';

                    if (username == 'pasien' && password == '123') {
                      isStaticValid = true;
                      staticRole = 'pasien';
                      staticName = 'Alvin';
                    } else if (username == 'dokter' && password == '123') {
                      isStaticValid = true;
                      staticRole = 'dokter';
                      staticName = 'dr. Agoes Soetanto';
                    } else if (username == 'apotek' && password == '123') {
                      isStaticValid = true;
                      staticRole = 'apotek';
                      staticName = 'CyrenElysia~♪';
                    } else if (username == 'puskesmas' && password == '123') {
                      isStaticValid = true;
                      staticRole = 'puskesmas';
                      staticName = 'Puskesmas Sumbersari';
                    } else if (username == 'ponkesdes' && password == '123') {
                      isStaticValid = true;
                      staticRole = 'ponkesdes';
                      staticName = 'Ponkesdes Sukowono';
                    }

                    if (isStaticValid) {
                      Navigator.pop(context); // Close login modal
                      String? staticAvatarUrl;
                      if (staticRole == 'pasien') {
                        staticAvatarUrl =
                            'https://media.tenor.com/I-jCAV1wUCEAAAAM/luna-kindred-smile.gif';
                      } else if (staticRole == 'dokter') {
                        staticAvatarUrl =
                            'https://pkm-sumberwringin.bondowosokab.go.id/uploads/pkm-sumberwringin.bondowosokab.go.id/kegiatan/Foto%20Kappus.jpg';
                      } else if (staticRole == 'apotek') {
                        staticAvatarUrl =
                            'https://media1.tenor.com/m/vXcb3pS1xs8AAAAd/elysia-honkai-impact-3rd.gif';
                      } else if (staticRole == 'puskesmas') {
                        staticAvatarUrl =
                            'https://pkm-sumberwringin.bondowosokab.go.id/uploads/pkm-sumberwringin.bondowosokab.go.id/kegiatan/Foto%20Kappus.jpg';
                      } else if (staticRole == 'ponkesdes') {
                        staticAvatarUrl =
                            'https://media1.tenor.com/m/vXcb3pS1xs8AAAAd/elysia-honkai-impact-3rd.gif';
                      }

                      final mockUser = {
                        'id': 'mock-id-1234567890',
                        'name': staticName,
                        'email': '$staticRole@company.com',
                        'nik': '3511081208000003',
                        'phone_number': '08XXXXXXXXXX',
                        'birth_date': '2000-12-08',
                        'gender': 'male',
                        'role': staticRole,
                        'province': 'JAWA TIMUR',
                        'district': 'KABUPATEN BONDOWOSO',
                        'sub_district': 'PUER',
                        'village': 'KEJAYAN',
                        'address':
                            'Kel. KEJAYAN, Kec. PUER, KABUPATEN BONDOWOSO, Prov. JAWA TIMUR',
                        'subscription_status': 'inactive',
                        'subscription_expires_at': null,
                        'avatar_url': staticAvatarUrl,
                      };
                      notifier.login(
                        staticRole,
                        user: mockUser,
                        blurProfileEffectEnabled: true,
                        defaultServiceFee: staticRole == 'dokter'
                            ? 50000.0
                            : 0.0,
                        satusehatAutoSync: true,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: accentPurple,
                          content: Text(
                            state.language == 'id'
                                ? 'Selamat Datang! Login berhasil (Offline/Demo Mode).'
                                : 'Welcome! Login successful (Offline/Demo Mode).',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    // Show the premium full-screen loading page with progress and FAQ
                    final progressNotifier = ValueNotifier<double>(0.0);
                    Timer? loadingTimer;

                    loadingTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
                      final current = progressNotifier.value;
                      if (current < 0.90) {
                        progressNotifier.value = current + 0.015;
                      } else {
                        timer.cancel();
                      }
                    });

                    showGeneralDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.black.withOpacity(0.5),
                      transitionDuration: const Duration(milliseconds: 250),
                      pageBuilder: (context, anim1, anim2) => FadeTransition(
                        opacity: anim1,
                        child: MapotechLoadingScreen(
                          progressNotifier: progressNotifier,
                        ),
                      ),
                    );

                    try {
                      final SupabaseService db = SupabaseService();
                      final user = await db.fetchUserByEmailOrUsername(
                        username,
                      );

                      bool dbSuccess = false;
                      String mappedRole = 'pasien';
                      String? displayName;

                      if (user != null) {
                        final String? dbHash = user['password'];
                        if (dbHash != null && dbHash.isNotEmpty) {
                          // PHP Bcrypt compatibility: Replace prefix $2y$ with $2a$ for package compatibility
                          final compatibleHash = dbHash.replaceFirst(
                            '\$2y\$',
                            '\$2a\$',
                          );

                          // Run standard Bcrypt comparison
                          try {
                            if (BCrypt.checkpw(password, compatibleHash)) {
                              dbSuccess = true;
                              displayName = user['name'];

                              final String dbRole = user['role'] ?? 'pasien';
                              if (dbRole == 'pasien' || dbRole == 'patient') {
                                mappedRole = 'pasien';
                              } else if (dbRole == 'dokter' ||
                                  dbRole == 'praktikmandiri' ||
                                  dbRole == 'asisten_dokter') {
                                mappedRole = 'dokter';
                              } else if (dbRole == 'apotek' ||
                                  dbRole == 'asisten_apotek') {
                                mappedRole = 'apotek';
                              } else if (dbRole == 'puskesmas') {
                                mappedRole = 'puskesmas';
                              } else if (dbRole == 'ponkesdes') {
                                mappedRole = 'ponkesdes';
                              } else {
                                mappedRole = 'pasien'; // default fallback
                              }
                            }
                          } catch (_) {}
                        }
                      }

                      // Fast-forward progress to 100% and close the loading page
                      loadingTimer?.cancel();
                      double currentVal = progressNotifier.value;
                      while (currentVal < 1.0) {
                        currentVal = (currentVal + 0.05).clamp(0.0, 1.0);
                        progressNotifier.value = currentVal;
                        await Future.delayed(const Duration(milliseconds: 15));
                      }
                      await Future.delayed(const Duration(milliseconds: 150));

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      progressNotifier.dispose();

                      if (dbSuccess) {
                        final blurProfile =
                            user?['is_blur_enabled'] as bool? ?? true;
                        final savedLanguage =
                            user?['language'] as String? ?? state.language;
                        double defaultFee = 0.0;
                        bool ssAutoSync = true;

                        // Fetch assistant details if role is asisten_dokter
                        if (user != null && user['role'] == 'asisten_dokter') {
                          try {
                            final asisData = await SupabaseService.client
                                .from('user_detail_doctor_assistant')
                                .select('doctor_id, permissions')
                                .eq('id', user['id'])
                                .maybeSingle();
                            if (asisData != null) {
                              user['doctor_id'] = asisData['doctor_id'];
                              user['permissions'] = asisData['permissions'];
                            }
                          } catch (e) {
                            debugPrint('Error fetching assistant details: $e');
                          }
                        }

                        // Fetch assistant details if role is asisten_apotek
                        if (user != null && user['role'] == 'asisten_apotek') {
                          try {
                            final asisData = await SupabaseService.client
                                .from('user_detail_pharmacist_staff')
                                .select('apotek_id')
                                .eq('id', user['id'])
                                .maybeSingle();
                            if (asisData != null) {
                              user['apotek_id'] = asisData['apotek_id'];
                            }
                          } catch (e) {
                            debugPrint('Error fetching pharmacist assistant details: $e');
                          }
                        }

                        if (mappedRole == 'dokter') {
                          try {
                            final targetDoctorId =
                                (user?['role'] == 'asisten_dokter')
                                ? (user?['doctor_id'])
                                : (user?['id']);
                            if (targetDoctorId != null) {
                              final docDetail = await SupabaseService.client
                                  .from('user_detail_doctor')
                                  .select(
                                    'default_service_fee, satusehat_auto_sync',
                                  )
                                  .eq('id', targetDoctorId)
                                  .maybeSingle();
                              if (docDetail != null) {
                                defaultFee =
                                    double.tryParse(
                                      docDetail['default_service_fee']
                                              ?.toString() ??
                                          '',
                                    ) ??
                                    0.0;
                                ssAutoSync =
                                    docDetail['satusehat_auto_sync'] as bool? ??
                                    true;
                              }
                            }
                          } catch (e) {
                            debugPrint(
                              'Error loading doctor settings from DB: $e',
                            );
                          }
                        }

                        Set<String>? dbFavorites;
                        if (user != null && user['id'] != null) {
                          try {
                            final userId = user['id'];
                            final userRole = user['role']?.toString() ?? mappedRole;
                            dbFavorites = await db.fetchFavoriteMenusFromUserDetail(userId, userRole);
                          } catch (e) {
                            debugPrint('Error fetching favorite_menus during login: $e');
                          }
                        }

                        Navigator.pop(context); // Close the login modal
                        notifier.login(
                          mappedRole,
                          user: user,
                          blurProfileEffectEnabled: blurProfile,
                          defaultServiceFee: defaultFee,
                          satusehatAutoSync: ssAutoSync,
                          language: savedLanguage,
                          favoriteMenuItems: dbFavorites,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: accentPurple,
                            content: Text(
                              state.language == 'id'
                                  ? 'Selamat Datang, $displayName! Login berhasil.'
                                  : 'Welcome, $displayName! Login successful.',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                    } catch (_) {
                      // Silently proceed to failure feedback
                    }

                    // Try to close loading dialog if it's still open
                    loadingTimer?.cancel();
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    progressNotifier.dispose();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text(
                          state.language == 'id'
                              ? 'Username atau password salah!'
                              : 'Incorrect username or password!',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Lupa Password link
              Center(
                child: TextButton(
                  onPressed: isSoonActive ? null : () {},
                  child: Text(
                    state.language == 'id'
                        ? 'LUPA PASSWORD?'
                        : 'FORGOT PASSWORD?',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isSoonActive
                          ? subtitleColor.withOpacity(0.4)
                          : accentPurple,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

              // Register Link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showRegisterModal(context, widget.ref); // swap modal
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: subtitleColor,
                      ),
                      children: [
                        TextSpan(
                          text: state.language == 'id'
                              ? 'BELUM PUNYA AKUN? '
                              : 'DON\'T HAVE AN ACCOUNT? ',
                        ),
                        TextSpan(
                          text: 'DAFTAR',
                          style: TextStyle(color: accentPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== REGISTER MODAL CONTENT (STATEFUL 4-STEPS) ====================

class _RegisterModalContent extends StatefulWidget {
  final WidgetRef ref;
  final bool isDark;

  const _RegisterModalContent({required this.ref, required this.isDark});

  @override
  State<_RegisterModalContent> createState() => _RegisterModalContentState();
}

class _RegisterModalContentState extends State<_RegisterModalContent> {
  int _currentStep =
      0; // 0: Role, 1: Personal, 2: Address, 3: Account Credentials
  String _selectedRoleId = '';

  // Controllers
  final _namaController = TextEditingController();
  final _nikController = TextEditingController();
  String _jenisKelamin = 'Laki-laki';
  final _tempatLahirController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  DateTime? _tanggalLahirDate;

  String _provinsi = 'Pilih Provinsi';
  String _kota = 'Pilih Kota/Kabupaten';
  String _kecamatan = 'Pilih Kecamatan';
  String _kelurahan = 'Pilih Kelurahan/Desa';
  final _alamatDetailController = TextEditingController();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Auth state
  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  String _otpDebugCode = ''; // For development display

  @override
  void initState() {
    super.initState();
    // Default selected role is active tab
    _selectedRoleId = widget.ref.read(landingPageProvider).activeTab;
    if (_selectedRoleId == 'mapotek') {
      _selectedRoleId = 'pasien'; // Default to Masyarakat
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nikController.dispose();
    _tempatLahirController.dispose();
    _tanggalLahirController.dispose();
    _alamatDetailController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ref.watch(landingPageProvider);
    final notifier = widget.ref.read(landingPageProvider.notifier);

    final isRev = state.appearance == 'rev';

    final isDark = state.appearance == 'dark';
    final bgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final fieldBg = isDark ? const Color(0xFF252528) : const Color(0xFFF6F3FC);

    final accentPurple = isRev
        ? const Color(0xFFB577F2)
        : const Color(0xFF48C9B0);

    final titleGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFB577F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    final isMobile = MediaQuery.of(context).size.width < 768;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: _currentStep == 0 ? 760 : (_currentStep == 2 ? 600 : 540),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 20 : 36),
      child: Stack(
        children: [
          // Close button
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Register Title with gradient
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: titleGradient,
                  ).createShader(bounds),
                  child: Text(
                    state.language == 'id' ? 'Pendaftaran' : 'Registration',
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Progress indicators (4 capsule capsules)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index == _currentStep;
                  return Container(
                    width: 28,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? accentPurple : Colors.grey[200],
                      borderRadius: BorderRadius.circular(100),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // DYNAMIC STEPS BUILDER
              AnimatedPortalSwitcher(
                switcherKey: 'register_step_$_currentStep',
                child: _buildRegisterStep(
                  state,
                  notifier,
                  textColor,
                  fieldBg,
                  accentPurple,
                  isMobile,
                ),
              ),

              const SizedBox(height: 24),

              // Centered "Sudah ada akun? Masuk"
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showLoginModal(context, widget.ref); // swap modal
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: subtitleColor,
                      ),
                      children: [
                        TextSpan(
                          text: state.language == 'id'
                              ? 'SUDAH ADA AKUN? '
                              : 'ALREADY HAVE AN ACCOUNT? ',
                        ),
                        TextSpan(
                          text: 'MASUK',
                          style: TextStyle(color: accentPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterStep(
    LandingPageState state,
    LandingPageNotifier notifier,
    Color textColor,
    Color fieldBg,
    Color accentPurple,
    bool isMobile,
  ) {
    if (_currentStep == 0) {
      return _buildStep0RoleSelection(
        state,
        notifier,
        textColor,
        cardColor: fieldBg,
        isMobile: isMobile,
      );
    } else if (_currentStep == 1) {
      return _buildStep1PersonalInfo(state, textColor, fieldBg);
    } else if (_currentStep == 2) {
      return _buildStep2Address(state, textColor, fieldBg);
    } else {
      return _buildStep3AccountCredentials(
        state,
        textColor,
        fieldBg,
        accentPurple,
      );
    }
  }

  // ==================== STEP 0: ROLE SELECTION ====================

  Widget _buildStep0RoleSelection(
    LandingPageState state,
    LandingPageNotifier notifier,
    Color textColor, {
    required Color cardColor,
    required bool isMobile,
  }) {
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final accentPurple = isRev
        ? const Color(0xFFB577F2)
        : const Color(0xFF48C9B0);

    final btnGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFD6A4F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    final ribbonBg = isRev ? const Color(0xFFE5D5FC) : const Color(0xFFE0F7F4);

    final soonPortals = [
      'klinik',
      'rumahsakit',
      'posyandu',
    ];
    final isSelectedSoon = soonPortals.contains(_selectedRoleId);

    final roles = [
      {
        'id': 'pasien',
        'label': 'MASYARAKAT',
        'icon': Icons.person_rounded,
        'isSoon': false,
      },
      {
        'id': 'dokter',
        'label': 'PRAKTIK MANDIRI',
        'icon': Icons.medical_services_rounded,
        'isSoon': false,
      },
      {
        'id': 'apotek',
        'label': 'APOTEK',
        'icon': Icons.local_pharmacy_rounded,
        'isSoon': false,
      },
      {
        'id': 'klinik',
        'label': 'KLINIK',
        'icon': Icons.local_hospital_rounded,
        'isSoon': true,
      },
      {
        'id': 'puskesmas',
        'label': 'PUSKESMAS',
        'icon': Icons.domain_rounded,
        'isSoon': false,
      },
      {
        'id': 'rumahsakit',
        'label': 'RUMAH SAKIT',
        'icon': Icons.corporate_fare_rounded,
        'isSoon': true,
      },
      {
        'id': 'ponkesdes',
        'label': 'PONKESDES',
        'icon': Icons.home_work_rounded,
        'isSoon': false,
      },
      {
        'id': 'posyandu',
        'label': 'POSYANDU',
        'icon': Icons.favorite_rounded,
        'isSoon': true,
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role select grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            final isSoon = role['isSoon'] as bool;
            final isSelected = _selectedRoleId == role['id'];

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Material(
                    color: cardColor,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRoleId = role['id'] as String;
                        });
                        notifier.setActiveTab(role['id'] as String);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? accentPurple
                                : (isDark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.grey[200]!),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon Box
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2C2C32)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      isDark ? 0.15 : 0.04,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                role['icon'] as IconData,
                                color: accentPurple,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Text Label
                            Text(
                              role['label'] as String,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Diagonal Ribbon
                  if (isSoon)
                    Positioned(
                      top: -16,
                      right: -28,
                      child: Transform.rotate(
                        angle: 0.785398,
                        child: Container(
                          width: 80,
                          height: 48,
                          padding: const EdgeInsets.only(bottom: 2),
                          alignment: Alignment.bottomCenter,
                          color: ribbonBg.withOpacity(isDark ? 0.2 : 0.6),
                          child: Text(
                            'SEGERA',
                            style: GoogleFonts.outfit(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                              color: accentPurple,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 36),

        // Next button (displays SEGERA and is disabled if soon)
        if (isSelectedSoon)
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  btnGradient[0].withOpacity(0.4),
                  btnGradient[1].withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SEGERA',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          )
        else
          CustomButton(
            text: state.language == 'id' ? 'LANJUT' : 'NEXT',
            height: 48,
            isGradient: true,
            gradientColors: btnGradient,
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
          ),
      ],
    );
  }

  // ==================== STEP 1: PERSONAL INFO ====================

  Widget _buildStep1PersonalInfo(
    LandingPageState state,
    Color textColor,
    Color fieldBg,
  ) {
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);

    final btnGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFD6A4F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // NAMA LENGKAP
        Text(
          state.language == 'id' ? 'NAMA LENGKAP' : 'FULL NAME',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: subtitleColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _namaController,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'John Doe',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // NIK & JENIS KELAMIN side-by-side
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIK',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[200]!,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nikController,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: '16 digit NIK',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: subtitleColor.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.language == 'id' ? 'JENIS KELAMIN' : 'GENDER',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[200]!,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    height: 48,
                    alignment: Alignment.centerLeft,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _jenisKelamin,
                        isExpanded: true,
                        dropdownColor: fieldBg,
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: subtitleColor,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        onChanged: (String? val) {
                          if (val != null) setState(() => _jenisKelamin = val);
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'Laki-laki',
                            child: Text('Laki-laki'),
                          ),
                          DropdownMenuItem(
                            value: 'Perempuan',
                            child: Text('Perempuan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // TEMPAT LAHIR & TANGGAL LAHIR side-by-side
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.language == 'id' ? 'TEMPAT LAHIR' : 'BIRTH PLACE',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[200]!,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _tempatLahirController,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Kota/Kabupaten',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: subtitleColor.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.language == 'id' ? 'TANGGAL LAHIR' : 'BIRTH DATE',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[200]!,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tanggalLahirController,
                            readOnly: true,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'mm / dd / yyyy',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 13,
                                color: subtitleColor.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _tanggalLahirDate = picked;
                                  _tanggalLahirController.text =
                                      "${picked.month.toString().padLeft(2, '0')} / ${picked.day.toString().padLeft(2, '0')} / ${picked.year}";
                                });
                              }
                            },
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: subtitleColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Navigation Buttons: KEMBALI & LANJUT
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: state.language == 'id' ? 'KEMBALI' : 'BACK',
                isSecondary: true,
                height: 48,
                textColor: textColor,
                borderColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey[200]!,
                onPressed: _isLoading
                    ? () {}
                    : () {
                        setState(() {
                          _currentStep = 0;
                        });
                      },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _isLoading
                  ? Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: btnGradient),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : CustomButton(
                      text: state.language == 'id' ? 'LANJUT' : 'NEXT',
                      isGradient: true,
                      gradientColors: btnGradient,
                      height: 48,
                      onPressed: () async {
                        // Validate step 1 fields
                        if (_namaController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                state.language == 'id'
                                    ? 'Nama lengkap wajib diisi!'
                                    : 'Full name is required!',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        if (_nikController.text.trim().length != 16) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                state.language == 'id'
                                    ? 'NIK harus 16 digit!'
                                    : 'NIK must be 16 digits!',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);
                        try {
                          final db = SupabaseService();
                          String dbRole = 'patient';
                          if (_selectedRoleId == 'dokter') dbRole = 'praktikmandiri';
                          if (_selectedRoleId == 'apotek') dbRole = 'apotek';
                          if (_selectedRoleId == 'puskesmas') dbRole = 'puskesmas';
                          if (_selectedRoleId == 'ponkesdes') dbRole = 'ponkesdes';

                          final exists = await db.checkNikExists(_nikController.text.trim(), dbRole);
                          setState(() => _isLoading = false);

                          if (exists) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text(
                                    state.language == 'id'
                                        ? 'NIK sudah terdaftar!'
                                        : 'NIK already registered!',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                        } catch (e) {
                          setState(() => _isLoading = false);
                        }

                        setState(() {
                          _currentStep = 2;
                        });
                      },
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== STEP 2: ADDRESS ====================

  Widget _buildStep2Address(
    LandingPageState state,
    Color textColor,
    Color fieldBg,
  ) {
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);

    final btnGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFD6A4F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E22).withOpacity(0.5)
                : const Color(0xFFF7F5FC).withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.language == 'id' ? 'ALAMAT' : 'ADDRESS',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              LocationSelectorWidget(
                initialProvince: _provinsi == 'Pilih Provinsi' ? '' : _provinsi,
                initialDistrict: _kota == 'Pilih Kota/Kabupaten' ? '' : _kota,
                initialSubDistrict: _kecamatan == 'Pilih Kecamatan' ? '' : _kecamatan,
                initialVillage: _kelurahan == 'Pilih Kelurahan/Desa' ? '' : _kelurahan,
                fieldBg: fieldBg,
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey[200]!,
                dropdownColor: fieldBg,
                onChanged: (province, district, subDistrict, village) {
                  setState(() {
                    _provinsi = province.isEmpty ? 'Pilih Provinsi' : province;
                    _kota = district.isEmpty ? 'Pilih Kota/Kabupaten' : district;
                    _kecamatan = subDistrict.isEmpty ? 'Pilih Kecamatan' : subDistrict;
                    _kelurahan = village.isEmpty ? 'Pilih Kelurahan/Desa' : village;
                  });
                },
              ),
              const SizedBox(height: 14),

              // Detail Jalan
              Text(
                state.language == 'id'
                    ? 'Detail Jalan (Opsional / Nilai Saat Ini)'
                    : 'Street Details (Optional / Current Value)',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: subtitleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _alamatDetailController,
                  maxLines: 2,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Alamat lengkap (opsional)',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: state.language == 'id' ? 'KEMBALI' : 'BACK',
                isSecondary: true,
                height: 48,
                textColor: textColor,
                borderColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey[200]!,
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: CustomButton(
                text: state.language == 'id' ? 'LANJUT' : 'NEXT',
                isGradient: true,
                gradientColors: btnGradient,
                height: 48,
                onPressed: () {
                  setState(() {
                    _currentStep = 3;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== STEP 3: ACCOUNT CREDENTIALS ====================

  Widget _buildStep3AccountCredentials(
    LandingPageState state,
    Color textColor,
    Color fieldBg,
    Color accentPurple,
  ) {
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);

    final btnGradient = isRev
        ? const [Color(0xFFEAB7EE), Color(0xFFD6A4F2)]
        : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // EMAIL FIELD WITH "KIRIM KODE" inside
        Text(
          'EMAIL',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _otpVerified
                  ? Colors.green.withOpacity(0.5)
                  : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!),
              width: _otpVerified ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                _otpVerified
                    ? Icons.verified_rounded
                    : Icons.mail_outline_rounded,
                size: 18,
                color: _otpVerified ? Colors.green : subtitleColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  enabled: !_otpVerified,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'name@company.com',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              // KIRIM KODE / TERVERIFIKASI button
              if (_otpVerified)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    state.language == 'id' ? 'TERVERIFIKASI' : 'VERIFIED',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentPurple,
                          ),
                        )
                      : InkWell(
                          onTap: () async {
                            final email = _emailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text(
                                    state.language == 'id'
                                        ? 'Masukkan email yang valid!'
                                        : 'Enter a valid email!',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => _isLoading = true);
                            try {
                              final db = SupabaseService();

                              // Check if email already registered
                              final emailExists = await db.checkEmailExists(email);
                              if (emailExists) {
                                setState(() => _isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.redAccent,
                                      content: Text(
                                        state.language == 'id'
                                            ? 'Email sudah terdaftar!'
                                            : 'Email already registered!',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              final otp = await db.sendOtp(email);
                              setState(() {
                                _otpSent = true;
                                _otpDebugCode = otp;
                                _isLoading = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: accentPurple,
                                    content: Text(
                                      state.language == 'id'
                                          ? 'OTP terkirim! Kode: $otp (dev mode)'
                                          : 'OTP sent! Code: $otp (dev mode)',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() => _isLoading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text(
                                      '$e',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentPurple.withOpacity(
                                isDark ? 0.15 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accentPurple.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              _otpSent
                                  ? (state.language == 'id'
                                        ? 'KIRIM ULANG'
                                        : 'RESEND')
                                  : (state.language == 'id'
                                        ? 'KIRIM KODE'
                                        : 'SEND CODE'),
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: accentPurple,
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),

        // OTP INPUT (shown after KIRIM KODE is pressed)
        if (_otpSent && !_otpVerified) ...[
          const SizedBox(height: 16),
          Text(
            state.language == 'id' ? 'KODE VERIFIKASI' : 'VERIFICATION CODE',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: subtitleColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : Colors.grey[200]!,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.pin_rounded, size: 18, color: subtitleColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            hintText: '------',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 16,
                              color: subtitleColor.withOpacity(0.4),
                              letterSpacing: 4,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isLoading
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentPurple,
                        ),
                      ),
                    )
                  : InkWell(
                      onTap: () async {
                        final otp = _otpController.text.trim();
                        if (otp.length != 6) return;
                        setState(() => _isLoading = true);
                        try {
                          final db = SupabaseService();
                          final valid = await db.verifyOtp(
                            _emailController.text.trim(),
                            otp,
                          );
                          setState(() {
                            _isLoading = false;
                            _otpVerified = valid;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: valid
                                    ? Colors.green
                                    : Colors.redAccent,
                                content: Text(
                                  valid
                                      ? (state.language == 'id'
                                            ? 'Email terverifikasi!'
                                            : 'Email verified!')
                                      : (state.language == 'id'
                                            ? 'Kode salah atau kadaluarsa!'
                                            : 'Wrong or expired code!'),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => _isLoading = false);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: btnGradient),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.language == 'id' ? 'VERIFIKASI' : 'VERIFY',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // KATA SANDI
        Text(
          state.language == 'id' ? 'KATA SANDI' : 'PASSWORD',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: subtitleColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: subtitleColor,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // KONFIRMASI KATA SANDI
        Text(
          state.language == 'id' ? 'KONFIRMASI KATA SANDI' : 'CONFIRM PASSWORD',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: subtitleColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: subtitleColor,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: state.language == 'id' ? 'KEMBALI' : 'BACK',
                isSecondary: true,
                height: 48,
                textColor: textColor,
                borderColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey[200]!,
                onPressed: _isLoading
                    ? () {}
                    : () {
                        setState(() {
                          _currentStep = 2;
                        });
                      },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _isLoading
                  ? Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: btnGradient),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : CustomButton(
                      text: state.language == 'id'
                          ? 'DAFTAR SEKARANG'
                          : 'REGISTER NOW',
                      isGradient: true,
                      gradientColors: btnGradient,
                      height: 48,
                      onPressed: () async {
                        // Validate
                        final email = _emailController.text.trim();
                        final password = _passwordController.text;
                        final confirm = _confirmPasswordController.text;

                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                state.language == 'id'
                                    ? 'Masukkan email yang valid!'
                                    : 'Enter a valid email!',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        if (password.length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                state.language == 'id'
                                    ? 'Password minimal 8 karakter!'
                                    : 'Password must be at least 8 characters!',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        if (password != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                state.language == 'id'
                                    ? 'Konfirmasi password tidak cocok!'
                                    : 'Password confirmation does not match!',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        // Double check email duplicate first
                        setState(() => _isLoading = true);
                        try {
                          final db = SupabaseService();
                          final emailExists = await db.checkEmailExists(email);
                          if (emailExists) {
                            setState(() => _isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text(
                                    state.language == 'id'
                                        ? 'Email sudah terdaftar!'
                                        : 'Email already registered!',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                        } catch (e) {
                          print('Email double-check failed: $e');
                        }
                        setState(() => _isLoading = false);

                        // Show the premium full-screen loading page with progress and FAQ
                        final progressNotifier = ValueNotifier<double>(0.0);
                        Timer? loadingTimer;

                        loadingTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
                          final current = progressNotifier.value;
                          if (current < 0.90) {
                            progressNotifier.value = current + 0.015;
                          } else {
                            timer.cancel();
                          }
                        });

                        showGeneralDialog(
                          context: context,
                          barrierDismissible: false,
                          barrierColor: Colors.black.withOpacity(0.5),
                          transitionDuration: const Duration(milliseconds: 250),
                          pageBuilder: (context, anim1, anim2) => FadeTransition(
                            opacity: anim1,
                            child: MapotechLoadingScreen(
                              progressNotifier: progressNotifier,
                            ),
                          ),
                        );

                        setState(() => _isLoading = true);

                        try {
                          final db = SupabaseService();

                          // Map gender string to DB value
                          final genderValue = _jenisKelamin == 'Laki-laki'
                              ? 'male'
                              : 'female';

                          // Map role to DB role string
                          String dbRole = 'patient';
                          if (_selectedRoleId == 'dokter') dbRole = 'praktikmandiri';
                          if (_selectedRoleId == 'apotek') dbRole = 'apotek';
                          if (_selectedRoleId == 'puskesmas') dbRole = 'puskesmas';
                          if (_selectedRoleId == 'ponkesdes') dbRole = 'ponkesdes';

                          // Build ISO birth date
                          String birthDateIso = '';
                          if (_tanggalLahirDate != null) {
                            birthDateIso =
                                '${_tanggalLahirDate!.year.toString().padLeft(4, '0')}-'
                                '${_tanggalLahirDate!.month.toString().padLeft(2, '0')}-'
                                '${_tanggalLahirDate!.day.toString().padLeft(2, '0')}';
                          }

                          await db.register(
                            email: email,
                            password: password,
                            name: _namaController.text.trim(),
                            nik: _nikController.text.trim(),
                            gender: genderValue,
                            birthPlace: _tempatLahirController.text.trim(),
                            birthDate: birthDateIso,
                            province: _provinsi == 'Pilih Provinsi'
                                ? ''
                                : _provinsi,
                            district: _kota == 'Pilih Kota/Kabupaten'
                                ? ''
                                : _kota,
                            subDistrict: _kecamatan == 'Pilih Kecamatan'
                                ? ''
                                : _kecamatan,
                            village: _kelurahan == 'Pilih Kelurahan/Desa'
                                ? ''
                                : _kelurahan,
                            address: _alamatDetailController.text.trim(),
                            role: dbRole,
                          );

                          // Fast-forward progress to 100% and close the loading page
                          loadingTimer?.cancel();
                          double currentVal = progressNotifier.value;
                          while (currentVal < 1.0) {
                            currentVal = (currentVal + 0.05).clamp(0.0, 1.0);
                            progressNotifier.value = currentVal;
                            await Future.delayed(const Duration(milliseconds: 15));
                          }
                          await Future.delayed(const Duration(milliseconds: 150));

                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          progressNotifier.dispose();
                          setState(() => _isLoading = false);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: accentPurple,
                                content: Text(
                                  state.language == 'id'
                                      ? 'Pendaftaran berhasil! Akun Anda telah aktif dan siap digunakan.'
                                      : 'Registration successful! Your account is active and ready to use.',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          loadingTimer?.cancel();
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          progressNotifier.dispose();
                          setState(() => _isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text(
                                  '${state.language == 'id' ? 'Pendaftaran gagal: ' : 'Registration failed: '}$e',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
