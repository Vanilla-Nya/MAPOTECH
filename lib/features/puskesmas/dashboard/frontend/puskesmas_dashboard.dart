import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_owner_dashboard.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pekerja_dashboard.dart';

/// Role-based Puskesmas dashboard router without manual owner/worker tabs.
class PuskesmasDashboard extends ConsumerWidget {
  const PuskesmasDashboard({super.key});

  /// Returns true when the authenticated Puskesmas account is a worker/staff role.
  static bool isWorkerAccount(LandingPageState state) {
    final rawRole =
        (state.loggedInUser?['role'] ?? state.loggedInRole ?? '')
            .toString()
            .trim()
            .toLowerCase();
    return rawRole == 'pekerja' ||
        rawRole == 'worker' ||
        rawRole == 'staff' ||
        rawRole == 'staf' ||
        rawRole.contains('pekerja') ||
        rawRole.contains('staff') ||
        rawRole.contains('staf') ||
        rawRole.contains('asisten') ||
        state.loggedInUser?['owner_id'] != null ||
        state.loggedInUser?['puskesmas_id'] != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    if (isWorkerAccount(state)) {
      return const PuskesmasPekerjaDashboard();
    }
    return const PuskesmasOwnerDashboard();
  }
}
