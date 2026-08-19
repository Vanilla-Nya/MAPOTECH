import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/shared/supabase_service.dart';

class ApotekRxItem {
  final String name;
  final String dosage;
  final int qty;
  final String unit;
  final double price;
  final String? kfaCode;

  const ApotekRxItem({
    required this.name,
    required this.dosage,
    required this.qty,
    required this.unit,
    this.price = 5000,
    this.kfaCode,
  });
}

class ApotekPrescriptionOrder {
  final String id;
  final int sessionNumber;
  final String patientName;
  final String doctorName;
  final String date;
  String status; // 'pending', 'compounding', 'ready', 'checked_out'
  final List<ApotekRxItem> items;

  ApotekPrescriptionOrder({
    required this.id,
    required this.sessionNumber,
    required this.patientName,
    required this.doctorName,
    required this.date,
    required this.status,
    required this.items,
  });

  ApotekPrescriptionOrder copyWith({
    String? id,
    int? sessionNumber,
    String? patientName,
    String? doctorName,
    String? date,
    String? status,
    List<ApotekRxItem>? items,
  }) {
    return ApotekPrescriptionOrder(
      id: id ?? this.id,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }
}

class ApotekPrescriptionNotifier extends StateNotifier<List<ApotekPrescriptionOrder>> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ApotekPrescriptionNotifier() : super([]) {
    loadPrescriptions();
  }

  Future<void> loadPrescriptions() async {
    _isLoading = true;
    try {
      final List<ApotekPrescriptionOrder> loaded = [];
      final rawRx = await _db.fetchPendingPrescriptions();

      for (final rx in rawRx) {
        final String id = rx['id'] ?? '';
        final String status = rx['status'] ?? 'pending';
        final notes = rx['notes'] ?? '';
        String patient = 'Umum / Walk-in';
        String doctor = 'Praktik Mandiri Dokter';
        List<ApotekRxItem> parsedItems = [];

        try {
          if (notes.startsWith('{')) {
            final decoded = jsonDecode(notes);
            patient = decoded['patientName'] ?? patient;
            doctor = decoded['doctorName'] ?? doctor;
            final itemsList = decoded['items'] as List<dynamic>?;
            if (itemsList != null && itemsList.isNotEmpty) {
              for (final it in itemsList) {
                parsedItems.add(ApotekRxItem(
                  name: it['name'] ?? 'Obat',
                  dosage: it['dosage'] ?? 'Sesuai Petunjuk',
                  qty: int.tryParse(it['qty']?.toString() ?? '1') ?? 1,
                  unit: it['unit'] ?? 'Strip',
                  price: double.tryParse(it['price']?.toString() ?? '9500') ?? 9500,
                  kfaCode: it['kfa_code'],
                ));
              }
            }
          } else if (notes.contains('|')) {
            patient = notes.split('|').first.trim();
          } else if (notes.isNotEmpty) {
            patient = notes;
          }
        } catch (_) {}

        if (parsedItems.isEmpty) {
          parsedItems = const [
            ApotekRxItem(name: 'Paracetamol 500mg', dosage: '3x1 Sehari', qty: 2, unit: 'Strip', price: 4500, kfaCode: '93001030'),
            ApotekRxItem(name: 'Amoxicillin Trihydrate 500mg', dosage: '3x1 Sehari (Habiskan)', qty: 2, unit: 'Strip', price: 9500, kfaCode: '93001029'),
          ];
        }

        String displayStatus = 'pending';
        if (status == 'pending_checkout' || status == 'ready' || status == 'siap_checkout') {
          displayStatus = 'ready';
        } else if (status == 'compounding' || status == 'diracik') {
          displayStatus = 'compounding';
        } else if (status == 'checked_out' || status == 'completed') {
          displayStatus = 'completed';
        } else {
          displayStatus = 'pending';
        }

        loaded.add(ApotekPrescriptionOrder(
          id: id.isNotEmpty ? id : 'RX-8827',
          sessionNumber: loaded.length + 1,
          patientName: patient,
          doctorName: doctor,
          date: 'Hari ini',
          status: displayStatus,
          items: parsedItems,
        ));
      }

      if (loaded.isEmpty) {
        state = _getSampleData();
      } else {
        state = loaded;
      }
    } catch (e) {
      debugPrint('Error loading prescriptions: $e');
      if (state.isEmpty) {
        state = _getSampleData();
      }
    } finally {
      _isLoading = false;
      if (mounted) {
        state = List.from(state);
      }
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    state = [
      for (final order in state)
        if (order.id == id) order.copyWith(status: newStatus) else order,
    ];

    String dbStatus = 'pending';
    if (newStatus == 'ready') {
      dbStatus = 'pending_checkout';
    } else if (newStatus == 'completed') {
      dbStatus = 'checked_out';
    } else if (newStatus == 'compounding') {
      dbStatus = 'compounding';
    } else {
      dbStatus = newStatus;
    }

    try {
      if (!id.startsWith('RX-') || id.length > 10) {
        await _db.updatePrescriptionStatus(id, dbStatus);
      }
    } catch (e) {
      debugPrint('Error updating prescription status in DB: $e');
    }
  }

  /// Mark as checked out & completed after payment in POS
  Future<void> markCompleted(String id) async {
    await updateStatus(id, 'completed');
  }

  List<ApotekPrescriptionOrder> _getSampleData() {
    return [
      ApotekPrescriptionOrder(
        id: 'RX-7721',
        sessionNumber: 12,
        patientName: 'Ahmad Fauzi',
        doctorName: 'dr. Agoes Soetanto, Sp.PD',
        date: 'Hari ini, 10:15',
        status: 'ready',
        items: const [
          ApotekRxItem(name: 'Amoxicillin Trihydrate 500mg', dosage: '3x1 Sehari (Habiskan)', qty: 2, unit: 'Strip', price: 9500, kfaCode: '93001029'),
          ApotekRxItem(name: 'Paracetamol 500mg', dosage: '3x1 Sehari Jika Demam', qty: 1, unit: 'Strip', price: 4500, kfaCode: '93001030'),
        ],
      ),
      ApotekPrescriptionOrder(
        id: 'RX-8827',
        sessionNumber: 14,
        patientName: 'Budi Santoso',
        doctorName: 'dr. Agoes Soetanto, Sp.PD',
        date: 'Hari ini, 12:30',
        status: 'compounding',
        items: const [
          ApotekRxItem(name: 'Cetirizine HCl 10mg', dosage: '1x1 Malam', qty: 1, unit: 'Strip', price: 7000, kfaCode: '93001045'),
          ApotekRxItem(name: 'Vitamin C 500mg IPI', dosage: '1x1 Pagi', qty: 1, unit: 'Botol', price: 11000, kfaCode: '93001031'),
        ],
      ),
    ];
  }
}

final apotekPrescriptionProvider =
    StateNotifierProvider<ApotekPrescriptionNotifier, List<ApotekPrescriptionOrder>>((ref) {
  return ApotekPrescriptionNotifier();
});

// Holds the currently active prescription to automatically load into POS cart when navigating
final activePosPrescriptionProvider = StateProvider<ApotekPrescriptionOrder?>((ref) => null);

// Holds the currently connected patient for the active Apotek POS session
final connectedPosPatientProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
