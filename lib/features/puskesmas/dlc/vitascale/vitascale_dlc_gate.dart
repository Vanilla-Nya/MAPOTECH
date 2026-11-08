import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider lokal untuk status pembukaan kunci Modul DLC VitaScale (selalu terbuka langsung)
final vitascaleDlcUnlockedProvider = StateProvider<bool>((ref) => true);

/// Wrapper DLC VitaScale — sekarang langsung menampilkan child tanpa batasan kunci
class VitaScaleDlcGate extends ConsumerWidget {
  final Widget child;
  final String menuTitle;

  const VitaScaleDlcGate({
    super.key,
    required this.child,
    this.menuTitle = 'VITASCALE By MAPOTECH',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: child,
    );
  }
}
