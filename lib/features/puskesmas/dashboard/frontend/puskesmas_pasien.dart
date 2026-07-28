import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';

/// Puskesmas Pasien Page (Dedicated patient management component for Puskesmas)
class PuskesmasPasien extends ConsumerStatefulWidget {
  const PuskesmasPasien({super.key});

  @override
  ConsumerState<PuskesmasPasien> createState() => _PuskesmasPasienState();
}

class _PuskesmasPasienState extends ConsumerState<PuskesmasPasien> {
  @override
  Widget build(BuildContext context) {
    return const DokterPasien();
  }
}
