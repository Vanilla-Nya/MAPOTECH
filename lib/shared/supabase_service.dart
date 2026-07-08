import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bcrypt/bcrypt.dart';

class SupabaseService {
  static String get _baseUrl {
    final url = dotenv.env['SUPABASE_URL'] ?? 'https://abdburxhqqwsobmzuwmz.supabase.co';
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return '$cleanUrl/rest/v1';
  }
  static String get _anonKey => dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiZGJ1cnhocXF3c29ibXp1d216Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0OTMyNjYsImV4cCI6MjA5MjA2OTI2Nn0.mB3qIJAHjtWe5UKxE9Oj-RNLQCbQKFYHUZBLaF4nQwk';


  /// Convenience getter for the Supabase client (requires Supabase.initialize() called at startup)
  static SupabaseClient get client => Supabase.instance.client;

  final http.Client _http = http.Client();

  // ─────────────────────────────────────────────────────────────────
  // AUTH — REGISTER (via Supabase Auth signUp)
  // ─────────────────────────────────────────────────────────────────

  /// Registers a new user via Supabase Auth. On success the `handle_new_user`
  /// trigger on the database automatically:
  ///   1. Inserts into public.user (with all metadata)
  ///   2. Inserts into public.user_role (patient role)
  ///   3. Inserts into public.user_detail_patient
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String nik,
    required String gender,
    required String birthPlace,
    required String birthDate, // ISO 8601 e.g. "2000-12-08"
    required String province,
    required String district,
    required String subDistrict,
    required String village,
    required String address,
    required String role, // 'pasien' | 'dokter' | 'apotek'
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'nik': nik,
          'gender': gender,
          'birth_place': birthPlace,
          'birth_date': birthDate,
          'province': province,
          'regency': district,
          'district': subDistrict,
          'village': village,
          'address': address,
          'role': role,
        },
      );

      if (response.user == null) {
        throw Exception('Pendaftaran gagal. Coba lagi.');
      }

      return {
        'success': true,
        'user': response.user,
        'message':
            'Pendaftaran berhasil! Silakan cek email Anda untuk verifikasi.',
      };
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // AUTH — OTP (send & verify via otp_verifications table)
  // ─────────────────────────────────────────────────────────────────

  /// Generates a 6-digit OTP, stores it in otp_verifications, and returns
  /// the code so the caller can display/send it (in a real app, use an
  /// email service; here we return it for demo/development use).
  Future<String> sendOtp(String email) async {
    // Generate 6-digit OTP
    final otp = (100000 + Random().nextInt(900000)).toString();
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: 10))
        .toUtc()
        .toIso8601String();

    try {
      // Delete old OTPs for this email first
      await _delete('otp_verifications?email=eq.${Uri.encodeComponent(email)}');
      // Insert new OTP
      await _post('otp_verifications', {
        'email': email,
        'otp_code': otp,
        'expires_at': expiresAt,
      });
      return otp;
    } catch (e) {
      throw Exception('Gagal mengirim OTP: $e');
    }
  }

  /// Verifies a given OTP code for the email, marks it as verified.
  /// Returns true if valid & not expired, false otherwise.
  Future<bool> verifyOtp(String email, String otpCode) async {
    try {
      final rows = await _get(
        'otp_verifications?email=eq.${Uri.encodeComponent(email)}&otp_code=eq.${Uri.encodeComponent(otpCode)}&verified_at=is.null&order=created_at.desc&limit=1',
      );
      if (rows.isEmpty) return false;

      final row = rows.first as Map<String, dynamic>;
      final expiresAt = DateTime.parse(row['expires_at'] as String);
      if (DateTime.now().toUtc().isAfter(expiresAt)) return false;

      // Mark as verified
      await _patch('otp_verifications?id=eq.${row['id']}', {
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // HTTP HELPERS
  // ─────────────────────────────────────────────────────────────────

  Map<String, String> _headers({
    String schema = 'public',
    bool isWrite = false,
  }) => {
    'apikey': _anonKey,
    'Authorization': 'Bearer $_anonKey',
    if (isWrite) 'Content-Profile': schema else 'Accept-Profile': schema,
    if (isWrite) 'Content-Type': 'application/json',
  };

  Future<List<dynamic>> _get(String path, {String schema = 'public'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/$path');
      final response = await _http
          .get(uri, headers: _headers(schema: schema))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      throw Exception('HTTP error ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Failed to connect to Supabase: $e');
    }
  }

  Future<void> _patch(
    String path,
    Map<String, dynamic> data, {
    String schema = 'public',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/$path');
      final response = await _http
          .patch(
            uri,
            headers: _headers(schema: schema, isWrite: true),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data, {
    String schema = 'public',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/$path');
      final response = await _http
          .post(
            uri,
            headers: {
              ..._headers(schema: schema, isWrite: true),
              'Prefer': 'return=representation',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return decoded.first as Map<String, dynamic>;
        }
        return {};
      }
      throw Exception('HTTP error ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Failed to insert into Supabase: $e');
    }
  }

  Future<void> _delete(String path, {String schema = 'public'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/$path');
      await _http
          .delete(uri, headers: _headers(schema: schema, isWrite: true))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────
  // DATABASE QUERIES
  // ─────────────────────────────────────────────────────────────────

  // Fetch real medicines and join with active batches
  Future<List<Map<String, dynamic>>> fetchMedicinesWithBatches() async {
    final medicines = await _get(
      'medicines?select=*,medicine_batches(*)',
      schema: 'pharmacy',
    );
    return medicines.map((m) => m as Map<String, dynamic>).toList();
  }

  // Fetch real storage rack locations
  Future<List<Map<String, dynamic>>> fetchStorageRacks() async {
    final racks = await _get('storage_racks?select=*', schema: 'pharmacy');
    return racks.map((r) => r as Map<String, dynamic>).toList();
  }

  // Fetch real digital prescriptions
  Future<List<Map<String, dynamic>>> fetchPendingPrescriptions() async {
    final prescriptions = await _get(
      'external_prescriptions?select=*&status=neq.checked_out',
      schema: 'pharmacy',
    );
    return prescriptions.map((p) => p as Map<String, dynamic>).toList();
  }

  // Adjust stock count inside medicine batches
  Future<void> adjustBatchStock(String batchId, int newQuantity) async {
    await _patch('medicine_batches?id=eq.$batchId', {
      'quantity_in_stock': newQuantity.toString(),
    }, schema: 'pharmacy');
  }

  // Update digital prescription status
  Future<void> updatePrescriptionStatus(String rxId, String status) async {
    await _patch('external_prescriptions?id=eq.$rxId', {
      'status': status,
    }, schema: 'pharmacy');
  }

  // Insert sales checkout transaction
  Future<void> submitCheckoutTransaction({
    required double total,
    required String paymentMethod,
    required String buyerName,
    required List<Map<String, dynamic>> items,
  }) async {
    final txData = {
      'transaction_type': 'income',
      'source_type': 'pos_checkout',
      'amount': total.toString(),
      'payment_method': paymentMethod,
      'buyer_name': buyerName,
      'status': 'Sukses',
      'transaction_date': DateTime.now().toIso8601String(),
      'description': 'Transaksi Penjualan POS Kasir Apotek',
    };

    final createdTx = await _post(
      'financial_transactions',
      txData,
      schema: 'pharmacy',
    );
    final txUuid = createdTx['id'];

    if (txUuid != null) {
      for (final item in items) {
        final itemData = {
          'id_transaction': txUuid,
          'id_medicine_batch': item['batchId'],
          'quantity': item['qty'].toString(),
          'unit_price': item['price'].toString(),
          'total_amount': item['subtotal'].toString(),
        };
        await _post('transaction_items', itemData, schema: 'pharmacy');

        final currentStock = item['stock'] as int;
        final buyQty = item['qty'] as int;
        final nextStock = currentStock - buyQty >= 0
            ? currentStock - buyQty
            : 0;
        await adjustBatchStock(item['batchId'], nextStock);
      }
    }
  }

  // Fetch real financial transactions
  Future<List<Map<String, dynamic>>> fetchFinancialTransactions() async {
    final txs = await _get(
      'financial_transactions?select=*&order=transaction_date.desc',
      schema: 'pharmacy',
    );
    return txs.map((t) => t as Map<String, dynamic>).toList();
  }

  // Query a user by email or username
  Future<Map<String, dynamic>?> fetchUserByEmailOrUsername(
    String identifier,
  ) async {
    final safeId = Uri.encodeComponent(identifier);
    try {
      final users = await _get(
        'user?select=*&or=(email.eq.$safeId,username.eq.$safeId)',
        schema: 'public',
      );
      if (users.isNotEmpty) {
        return users.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Fetch patient profile and BPJS details by email
  Future<Map<String, dynamic>?> fetchPatientProfileByEmail(String email) async {
    final safeEmail = Uri.encodeComponent(email);
    try {
      final users = await _get(
        'user?select=*&email=eq.$safeEmail',
        schema: 'public',
      );
      if (users.isNotEmpty) {
        final user = Map<String, dynamic>.from(users.first as Map);
        final userId = user['id'];
        if (userId != null) {
          try {
            final details = await _get(
              'user_detail_patient?select=*&id=eq.$userId',
              schema: 'public',
            );
            if (details.isNotEmpty) {
              user['patient_details'] = details.first;
            }
          } catch (_) {}
        }
        return user;
      }
    } catch (_) {}
    return null;
  }

  // Update patient profile data in the database
  Future<void> updatePatientProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _patch('user?id=eq.$userId', data, schema: 'public');
  }

  // Fetch patient queue entries from the database
  Future<List<Map<String, dynamic>>> fetchPatientQueues(
    String patientId,
  ) async {
    try {
      final queues = await _get(
        'v_queues?select=*&id_patient=eq.$patientId',
        schema: 'public',
      );
      return queues.map((q) => q as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch clinical encounters matching a list of queue IDs
  Future<List<Map<String, dynamic>>> fetchClinicalEncounters(
    List<String> queueIds,
  ) async {
    if (queueIds.isEmpty) return [];
    try {
      final ids = queueIds.map((id) => Uri.encodeComponent(id)).join(',');
      final encounters = await _get(
        'v_clinical_encounters?select=*&id_queue=in.($ids)',
        schema: 'public',
      );
      return encounters.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch a user record by ID
  Future<Map<String, dynamic>?> fetchUserById(String userId) async {
    try {
      final users = await _get('user?select=*&id=eq.$userId', schema: 'public');
      if (users.isNotEmpty) {
        return users.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Fetch all users with patient role
  Future<List<Map<String, dynamic>>> fetchAllPatients() async {
    try {
      final users = await _get(
        'user?select=*&role=eq.pasien',
        schema: 'public',
      );
      final details = await _get(
        'user_detail_patient?select=*',
        schema: 'public',
      );

      final Map<String, Map<String, dynamic>> detailsMap = {
        for (var d in details) (d as Map<String, dynamic>)['id'] as String: d,
      };

      final List<Map<String, dynamic>> patientUsers = [];
      for (final u in users) {
        final userMap = Map<String, dynamic>.from(u as Map);
        final userId = userMap['id'] as String?;
        if (userId != null && detailsMap.containsKey(userId)) {
          userMap['patient_details'] = detailsMap[userId];
        }
        patientUsers.add(userMap);
      }
      return patientUsers;
    } catch (e) {
      throw Exception('Gagal mengambil daftar pasien: $e');
    }
  }

  // Fetch all queues
  Future<List<Map<String, dynamic>>> fetchAllQueues() async {
    try {
      final queues = await _get('v_queues?select=*', schema: 'public');
      return queues.map((q) => q as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch all clinical encounters
  Future<List<Map<String, dynamic>>> fetchAllClinicalEncounters() async {
    try {
      final encounters = await _get(
        'v_clinical_encounters?select=*',
        schema: 'public',
      );
      return encounters.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch all external prescriptions
  Future<List<Map<String, dynamic>>> fetchAllPrescriptions() async {
    try {
      final rx = await _get(
        'external_prescriptions?select=*',
        schema: 'pharmacy',
      );
      return rx.map((p) => p as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch assistants for a doctor
  Future<List<Map<String, dynamic>>> fetchDoctorAssistants(
    String doctorId,
  ) async {
    try {
      final rows = await _get(
        'user_detail_doctor_assistant?select=*,user:id(name,email,nik,phone_number,username,gender,birth_place,birth_date,address,province,district,sub_district,village,created_at)&doctor_id=eq.$doctorId',
        schema: 'public',
      );

      final List<Map<String, dynamic>> assistants = [];
      for (final row in rows) {
        final rowMap = Map<String, dynamic>.from(row as Map);
        final userMap = rowMap['user'] != null
            ? Map<String, dynamic>.from(rowMap['user'] as Map)
            : null;
        if (userMap != null) {
          assistants.add({
            'id': rowMap['id'],
            'doctor_id': rowMap['doctor_id'],
            'nama': userMap['name'] ?? '',
            'email': userMap['email'] ?? '',
            'nik': userMap['nik'] ?? '',
            'telepon': userMap['phone_number'] ?? '',
            'username': userMap['username'] ?? '',
            'gender': userMap['gender'] ?? 'Male',
            'birth_place': userMap['birth_place'] ?? '',
            'birth_date': userMap['birth_date'] ?? '',
            'address': userMap['address'] ?? '',
            'province': userMap['province'] ?? '',
            'district': userMap['district'] ?? '',
            'sub_district': userMap['sub_district'] ?? '',
            'village': userMap['village'] ?? '',
            'created_at': userMap['created_at'] ?? '',
            'sip': rowMap['sip'] ?? '-',
            'peran': rowMap['peran'] ?? 'Perawat',
            'is_bertugas': rowMap['is_bertugas'] ?? true,
            'permissions': List<String>.from(rowMap['permissions'] ?? []),
          });
        }
      }
      return assistants;
    } catch (e) {
      throw Exception('Gagal mengambil daftar asisten: $e');
    }
  }

  // Create an assistant
  Future<void> addDoctorAssistant({
    required String doctorId,
    required String assistantId,
    required String name,
    required String email,
    required String nik,
    required String phone,
    required String sip,
    required String peran,
    required List<String> permissions,
    required String username,
    required String password,
    required String gender,
    required String birthPlace,
    required String birthDate,
    required String address,
    required String province,
    required String district,
    required String subDistrict,
    required String village,
  }) async {
    try {
      // 1. Fetch doctor's instance_id from user_role
      String? instanceId;
      final doctorRoles = await _get(
        'user_role?select=id_instance&id_user=eq.$doctorId',
        schema: 'public',
      );
      if (doctorRoles.isNotEmpty) {
        instanceId =
            (doctorRoles.first as Map<String, dynamic>)['id_instance']
                as String?;
      }

      // Hash password using Bcrypt
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // 2. Insert into public.user
      final userData = {
        'id': assistantId,
        'name': name,
        'email': email.isEmpty || email == '-' ? null : email,
        'nik': nik,
        'phone_number': phone,
        'role': 'asisten_dokter',
        'username': username,
        'password': hashedPassword,
        'gender': gender,
        'birth_place': birthPlace,
        'birth_date': birthDate.isEmpty ? null : birthDate,
        'address': address,
        'province': province,
        'district': district,
        'sub_district': subDistrict,
        'village': village,
      };
      await _post('user', userData, schema: 'public');

      // 3. Insert into public.user_role
      final roleData = {
        'id_user': assistantId,
        'id_role': 4, // 4 is 'assistant'
        'type': 'assistant',
        'id_instance': instanceId,
      };
      await _post('user_role', roleData, schema: 'public');

      // 4. Insert into public.user_detail_doctor_assistant
      final assistantData = {
        'id': assistantId,
        'doctor_id': doctorId,
        'sip': sip,
        'peran': peran,
        'is_bertugas': true,
        'permissions': permissions,
      };
      await _post(
        'user_detail_doctor_assistant',
        assistantData,
        schema: 'public',
      );
    } catch (e) {
      throw Exception('Gagal mendaftarkan asisten: $e');
    }
  }

  // Update assistant personal data
  Future<void> updateDoctorAssistant({
    required String assistantId,
    required String name,
    required String email,
    required String nik,
    required String phone,
    required String sip,
    required String peran,
    required String username,
    required String gender,
    required String birthPlace,
    required String birthDate,
    required String address,
    required String province,
    required String district,
    required String subDistrict,
    required String village,
    String? password,
  }) async {
    try {
      // 1. Update user table
      final userData = {
        'name': name,
        'email': email.isEmpty || email == '-' ? null : email,
        'nik': nik,
        'phone_number': phone,
        'username': username,
        'gender': gender,
        'birth_place': birthPlace,
        'birth_date': birthDate.isEmpty ? null : birthDate,
        'address': address,
        'province': province,
        'district': district,
        'sub_district': subDistrict,
        'village': village,
        if (password != null && password.isNotEmpty)
          'password': BCrypt.hashpw(password, BCrypt.gensalt()),
      };
      await _patch('user?id=eq.$assistantId', userData, schema: 'public');

      // 2. Update user_detail_doctor_assistant table
      final assistantData = {
        'sip': sip,
        'peran': peran,
      };
      await _patch(
        'user_detail_doctor_assistant?id=eq.$assistantId',
        assistantData,
        schema: 'public',
      );
    } catch (e) {
      throw Exception('Gagal memperbarui data asisten: $e');
    }
  }

  // Delete assistant
  Future<void> deleteDoctorAssistant(String assistantId) async {
    try {
      await _delete(
        'user_detail_doctor_assistant?id=eq.$assistantId',
        schema: 'public',
      );
      await _delete('user_role?id_user=eq.$assistantId', schema: 'public');
      await _delete('user?id=eq.$assistantId', schema: 'public');
    } catch (e) {
      throw Exception('Gagal menghapus asisten: $e');
    }
  }

  // Update duty status
  Future<void> updateDoctorAssistantDuty(
    String assistantId,
    bool isBertugas,
  ) async {
    try {
      await _patch('user_detail_doctor_assistant?id=eq.$assistantId', {
        'is_bertugas': isBertugas,
      }, schema: 'public');
    } catch (e) {
      throw Exception('Gagal memperbarui status tugas: $e');
    }
  }

  // Update permissions
  Future<void> updateDoctorAssistantPermissions(
    String assistantId,
    List<String> permissions,
  ) async {
    try {
      await _patch('user_detail_doctor_assistant?id=eq.$assistantId', {
        'permissions': permissions,
      }, schema: 'public');
    } catch (e) {
      throw Exception('Gagal memperbarui izin akses: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DOCTOR'S MEDICINE (OBAT) - private_doctor schema
  // ─────────────────────────────────────────────────────────────────

  // Fetch doctor's medicines with their batches
  Future<List<Map<String, dynamic>>> fetchDoctorMedicinesWithBatches(
    String doctorId,
  ) async {
    try {
      final safeDoctorId = Uri.encodeComponent(doctorId);
      final medicines = await _get(
        'v_doctor_medicines_with_batches?select=*&id_doctor=eq.$safeDoctorId&is_deleted=eq.0',
        schema: 'public',
      );
      return medicines.map((m) => m as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Gagal mengambil daftar obat dokter: $e');
    }
  }

  // Soft delete doctor's medicine
  Future<void> deleteDoctorMedicine(String medicineId) async {
    try {
      await _post('rpc/delete_doctor_medicine', {
        'p_medicine_id': medicineId,
      }, schema: 'public');
    } catch (e) {
      throw Exception('Gagal menghapus obat dokter: $e');
    }
  }

  // Insert a new doctor medicine and its initial batch
  Future<void> addDoctorMedicine({
    required String doctorId,
    required String medicineId,
    required String name,
    required String form,
    required String? barcode,
    required double sellPrice,
    required Map<String, dynamic> initialBatch,
    String? kfaCode,
    String? kfaName,
  }) async {
    try {
      final rpcData = {
        'p_doctor_id': doctorId,
        'p_medicine_id': medicineId,
        'p_name': name,
        'p_form': form,
        'p_barcode': barcode ?? '',
        'p_sell_price': sellPrice,
        'p_initial_batch': initialBatch,
      };
      await _post('rpc/add_doctor_medicine', rpcData, schema: 'public');

      if (kfaCode != null || kfaName != null) {
        await _patch(
          'medicine?id=eq.${Uri.encodeComponent(medicineId)}',
          {
            if (kfaCode != null) 'kfa_code': kfaCode,
            if (kfaName != null) 'kfa_name': kfaName,
          },
          schema: 'private_doctor',
        );
      }
    } catch (e) {
      throw Exception('Gagal menambahkan obat dokter baru: $e');
    }
  }

  // Update doctor medicine details and upsert its batches
  Future<void> updateDoctorMedicine({
    required String medicineId,
    required double sellPrice,
    required List<Map<String, dynamic>> batches,
  }) async {
    try {
      final rpcData = {
        'p_medicine_id': medicineId,
        'p_sell_price': sellPrice,
        'p_batches': batches,
      };
      await _post('rpc/update_doctor_medicine', rpcData, schema: 'public');
    } catch (e) {
      throw Exception('Gagal memperbarui obat dokter: $e');
    }
  }

  // Update the barcode field of a medicine record
  Future<void> updateMedicineBarcode({
    required String medicineId,
    required String barcode,
  }) async {
    try {
      await _patch(
        'medicine?id=eq.${Uri.encodeComponent(medicineId)}',
        {'barcode': barcode},
        schema: 'private_doctor',
      );
    } catch (e) {
      throw Exception('Gagal memperbarui barcode obat: $e');
    }
  }

  // Fetch financial transactions for the doctor from the view
  Future<List<Map<String, dynamic>>> fetchDoctorFinancialTransactions(
    String doctorId,
  ) async {
    try {
      final safeDoctorId = Uri.encodeComponent(doctorId);
      final txs = await _get(
        'v_doctor_financial_transactions?select=*&doctor_id=eq.$safeDoctorId&order=created_at.desc',
        schema: 'public',
      );
      return txs.map((t) => t as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Gagal mengambil daftar transaksi keuangan dokter: $e');
    }
  }

  // Insert a new manual expense transaction for the doctor
  Future<void> addDoctorExpense({
    required String doctorId,
    required double amount,
    required String description,
    required String category,
  }) async {
    try {
      final rpcData = {
        'p_doctor_id': doctorId,
        'p_amount': amount,
        'p_description': description,
        'p_category': category,
      };
      await _post('rpc/add_doctor_expense', rpcData, schema: 'public');
    } catch (e) {
      throw Exception('Gagal mencatat pengeluaran baru: $e');
    }
  }

  // Insert a new manual transaction (income/expense) for the doctor
  Future<void> addDoctorManualTransaction({
    required String doctorId,
    required double amount,
    required String description,
    required String category,
    required String transactionType, // 'income' or 'expense'
  }) async {
    try {
      final txData = {
        'id_user': doctorId,
        'transaction_type': transactionType,
        'source_type': 'manual',
        'amount': amount,
        'description': description,
        'category': category,
        'status': 'active',
      };
      await _post('financial_transactions', txData, schema: 'private_doctor');
    } catch (e) {
      final action = transactionType == 'expense' ? 'pengeluaran' : 'pemasukan';
      throw Exception('Gagal mencatat $action baru: $e');
    }
  }


  // ─────────────────────────────────────────────────────────────────
  // DOCTOR'S QUEUE (ANTRIAN) - public schema view & RPCs
  // ─────────────────────────────────────────────────────────────────

  // Fetch all queue details for a doctor
  Future<List<Map<String, dynamic>>> fetchDoctorQueues(String doctorId) async {
    try {
      final safeDoctorId = Uri.encodeComponent(doctorId);
      final queues = await _get(
        'v_doctor_queue_details?select=*&id_doctor=eq.$safeDoctorId&order=date_queue.desc,created_at.asc',
        schema: 'public',
      );
      return queues.map((q) => q as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Gagal mengambil daftar antrian: $e');
    }
  }

  // Update a queue status
  Future<void> updateQueueStatus(String queueId, String status) async {
    try {
      final rpcData = {'p_queue_id': queueId, 'p_status': status};
      await _post('rpc/update_queue_status', rpcData, schema: 'public');
    } catch (e) {
      throw Exception('Gagal memperbarui status antrian: $e');
    }
  }

  // Create a new queue entry (and guest patient if applicable)
  // NOTE: Queue number (A-NNN) is now auto-generated by the database per doctor per day.
  Future<void> addDoctorQueue({
    required String doctorId,
    required String? patientId, // Null if walk-in guest
    required String patientType,
    required DateTime dateQueue,
    String? guestName,
    String? guestNik,
    String? guestPhone,
    DateTime? guestBirthDate,
    String? guestGender,
    String? guestAddress,
  }) async {
    try {
      final rpcData = {
        'p_doctor_id': doctorId,
        'p_patient_id': patientId,
        'p_patient_type': patientType,
        'p_date_queue': dateQueue.toIso8601String().substring(0, 10),
        'p_guest_name': guestName,
        'p_guest_nik': guestNik,
        'p_guest_phone': guestPhone,
        'p_guest_birth_date': guestBirthDate?.toIso8601String().substring(
          0,
          10,
        ),
        'p_guest_gender': guestGender,
        'p_guest_address': guestAddress,
      };
      await _post('rpc/add_doctor_queue', rpcData, schema: 'public');
    } catch (e) {
      throw Exception('Gagal menambahkan antrian baru: $e');
    }
  }

  // Update patient_type on a queue entry (hash-chain aware via RPC)
  Future<void> updateQueuePatientType(String queueId, String patientType) async {
    try {
      final rpcData = {
        'p_queue_id': queueId,
        'p_patient_type': patientType,
      };
      await _post('rpc/update_queue_patient_type', rpcData, schema: 'public');
    } catch (e) {
      throw Exception('Gagal memperbarui tipe pasien antrian: $e');
    }
  }

  // Delete/Cancel a queue entry
  Future<void> deleteQueue(String queueId) async {
    try {
      final rpcData = {'p_queue_id': queueId};
      await _post('rpc/delete_doctor_queue', rpcData, schema: 'public');
    } catch (e) {
      throw Exception('Gagal menghapus antrian: $e');
    }
  }

  // Fetch clinical encounters directly or with in-memory fallback
  Future<List<Map<String, dynamic>>> fetchDoctorClinicalEncounters(
    String doctorId,
  ) async {
    try {
      final safeDoctorId = Uri.encodeComponent(doctorId);
      final res = await _get(
        'clinical_encounters?select=*,queue!inner(id,id_doctor,patient_type,id_patient,id_guest_patient)&queue.id_doctor=eq.$safeDoctorId&order=created_at.desc',
        schema: 'private_doctor',
      );
      final list = res.map((e) => e as Map<String, dynamic>).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Fallback: chunked in-memory join
    try {
      final queues = await fetchDoctorQueues(doctorId);
      if (queues.isEmpty) return [];
      final queueIds = queues
          .map((q) => q['id']?.toString())
          .whereType<String>()
          .toList();

      List<Map<String, dynamic>> allEncounters = [];
      const chunkSize = 50;
      for (var i = 0; i < queueIds.length; i += chunkSize) {
        final chunk = queueIds.sublist(i, min(i + chunkSize, queueIds.length));
        final encounters = await fetchClinicalEncounters(chunk);
        allEncounters.addAll(encounters);
      }
      return allEncounters;
    } catch (err) {
      throw Exception('Gagal mengambil data sinkronisasi SatuSehat: $err');
    }
  }

  // Fetch encounter details (vitals, anamnesis, diagnosis, medicines) in parallel
  Future<Map<String, dynamic>> fetchEncounterDetails(String encounterId) async {
    try {
      final futures = await Future.wait<dynamic>([
        // 1. Vitals
        client
            .schema('private_doctor')
            .from('vital_signs')
            .select()
            .eq('id_clinical_ecounter', encounterId)
            .maybeSingle(),
        // 2. Anamnesis (complaint, exam)
        client
            .schema('private_doctor')
            .from('anamnesis_ecounter')
            .select()
            .eq('id_clinical_ecounter', encounterId)
            .maybeSingle(),
        // 3. ICD-10 Diagnosis
        client
            .schema('private_doctor')
            .from('icdx_ecounter')
            .select()
            .eq('id_clinical_ecounters', encounterId),
        // 4. Inventory Medicines
        client
            .schema('private_doctor')
            .from('medicine_ecounter')
            .select('*, detail_medicine(*, medicine(*))')
            .eq('id_clinical_encounters', encounterId),
        // 5. Electronic Prescriptions (and their items)
        client
            .schema('private_doctor')
            .from('electronic_prescriptions')
            .select('*, electronic_prescription_items(*)')
            .eq('id_clinical_encounter', encounterId)
            .maybeSingle(),
      ]);

      return {
        'vitals': futures[0] as Map<String, dynamic>?,
        'anamnesis': futures[1] as Map<String, dynamic>?,
        'diagnosis':
            (futures[2] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        'inventory_items':
            (futures[3] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        'prescription': futures[4] as Map<String, dynamic>?,
      };
    } catch (e) {
      throw Exception('Gagal mengambil rincian rekam medis: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EMR BLOCKCHAIN HASHING & SAVE EMR (CLINICAL ENCOUNTER)
  // ─────────────────────────────────────────────────────────────────

  String _generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // set version to 4
    values[8] = (values[8] & 0x3f) | 0x80; // set variant to 10
    return [
          values.sublist(0, 4),
          values.sublist(4, 6),
          values.sublist(6, 8),
          values.sublist(8, 10),
          values.sublist(10, 16),
        ]
        .map(
          (bytes) => bytes
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(),
        )
        .join('-');
  }

  Future<String> _getPreviousHash(
    String tableName, {
    String schema = 'private_doctor',
  }) async {
    try {
      final res = await client
          .schema(schema)
          .from(tableName)
          .select('current_hash')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['current_hash'] != null) {
        return res['current_hash'] as String;
      }
    } catch (_) {}
    return '0'.padLeft(64, '0');
  }

  String _computeBlockchainHash(
    Map<String, dynamic> attributes,
    String previousHash,
  ) {
    final Map<String, dynamic> hashable = {};
    final excludedKeys = {
      'current_hash',
      'previous_hash',
      'created_at',
      'updated_at',
    };

    final sortedKeys = attributes.keys.toList()..sort();
    final Map<String, dynamic> sortedMap = {};
    for (final key in sortedKeys) {
      if (!excludedKeys.contains(key) && attributes[key] != null) {
        sortedMap[key] = attributes[key];
      }
    }

    final dataString = jsonEncode(sortedMap);
    final dataToHash = dataString + previousHash;
    final bytes = utf8.encode(dataToHash);
    return sha256.convert(bytes).toString();
  }

  Future<void> adjustDoctorBatchStock(String batchId, int newQuantity) async {
    await _patch('detail_medicine?id=eq.$batchId', {
      'stock_batch': newQuantity.toString(),
    }, schema: 'private_doctor');
  }

  Future<String> saveClinicalEncounter({
    required String queueId,
    required String doctorId,
    required double serviceFee,
    required double totalBill,
    required String complaint,
    required String anamnesis,
    required String foodAllergy,
    required String airAllergy,
    required String drugAllergy,
    required String antibioticAllergy,
    required String medTherapy,
    required String nonMedTherapy,
    required String prognosis,
    required String bmhp,
    required String weight,
    required String height,
    required String spo2,
    required String temperature,
    required String bloodPressure,
    required String heartRate,
    required String respiration,
    required List<Map<String, dynamic>> diagnoses,
    required List<Map<String, dynamic>> prescriptions,
    required List<Map<String, dynamic>> manualPrescriptions,
    required String? recommendedApotekId,
    required bool isReferral,
    required String referralRs,
    required String referralPoli,
    required String referralNotes,
    required String referralNo,
  }) async {
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. Insert clinical encounter
      final String encounterId = _generateUuidV4();
      final double totalPrice = isReferral ? serviceFee : totalBill;

      final encounterData = {
        'id': encounterId,
        'id_queue': queueId,
        'total_price': totalPrice,
        'doctor_price': serviceFee,
        'is_rujukan': isReferral,
        'rujukan_rumah_sakit': isReferral ? referralRs : null,
        'rujukan_poli': isReferral ? referralPoli : null,
        'rujukan_nomor': isReferral ? referralNo : null,
        'rujukan_catatan': isReferral ? referralNotes : null,
        'satusehat_sync_status': 'unsent',
        'satusehat_last_error': null,
        'satusehat_encounter_id': null,
        'created_at': nowStr,
      };

      final encounterPrevHash = await _getPreviousHash('clinical_encounters');
      encounterData['current_hash'] = _computeBlockchainHash(
        encounterData,
        encounterPrevHash,
      );
      encounterData['previous_hash'] = encounterPrevHash;

      await _post(
        'clinical_encounters',
        encounterData,
        schema: 'private_doctor',
      );

      // 2. Insert vital signs
      final vitalId = _generateUuidV4();
      final vitalData = {
        'id': vitalId,
        'id_clinical_ecounter': encounterId,
        'body_weight': weight,
        'body_height': height,
        'oxygen_saturation': spo2,
        'body_temperature': temperature,
        'blood_pressure': bloodPressure,
        'heart_rate': heartRate,
        'respiratory_rate': respiration,
        'created_at': nowStr,
      };

      final vitalPrevHash = await _getPreviousHash('vital_signs');
      vitalData['current_hash'] = _computeBlockchainHash(
        vitalData,
        vitalPrevHash,
      );
      vitalData['previous_hash'] = vitalPrevHash;

      await _post('vital_signs', vitalData, schema: 'private_doctor');

      // 3. Insert anamnesis
      final anamnesisId = _generateUuidV4();
      final anamnesisData = {
        'id': anamnesisId,
        'id_clinical_ecounter': encounterId,
        'main_complaint': complaint,
        'anamnesis': anamnesis,
        'food_allergy_history': foodAllergy,
        'environmental_allergy_history': airAllergy,
        'drug_allergy_history': drugAllergy,
        'drug_allergy_antibiotic': antibioticAllergy,
        'other_allergy_history': '',
        'medication_therapy': medTherapy,
        'non_medication_therapy': nonMedTherapy,
        'medical_supplies': bmhp,
        'prognosis': prognosis,
        'created_at': nowStr,
      };

      final anamnesisPrevHash = await _getPreviousHash('anamnesis_ecounter');
      anamnesisData['current_hash'] = _computeBlockchainHash(
        anamnesisData,
        anamnesisPrevHash,
      );
      anamnesisData['previous_hash'] = anamnesisPrevHash;

      await _post(
        'anamnesis_ecounter',
        anamnesisData,
        schema: 'private_doctor',
      );

      // 4. Insert ICD-10 Diagnoses
      for (final diag in diagnoses) {
        final diagId = _generateUuidV4();
        final diagData = {
          'id': diagId,
          'id_clinical_ecounters': encounterId,
          'icdx_code': diag['code'] ?? '',
          'description': diag['description'] ?? '',
          'created_at': nowStr,
        };

        final diagPrevHash = await _getPreviousHash('icdx_ecounter');
        diagData['current_hash'] = _computeBlockchainHash(
          diagData,
          diagPrevHash,
        );
        diagData['previous_hash'] = diagPrevHash;

        await _post('icdx_ecounter', diagData, schema: 'private_doctor');
      }

      // 5. Insert Medicine Ecounter (Prescriptions) with stock decrement (FEFO)
      for (final rx in prescriptions) {
        final dynamic obatRaw = rx['obat'];
        if (obatRaw == null) continue;

        final List<dynamic> batches = List.from(obatRaw.batches);

        DateTime parseExpDate(String dateStr) {
          try {
            final parts = dateStr.split('/');
            if (parts.length == 3) {
              final day = int.parse(parts[0].trim());
              final month = int.parse(parts[1].trim());
              final year = int.parse(parts[2].trim());
              return DateTime(year, month, day);
            }
          } catch (_) {}
          return DateTime(2099, 12, 31);
        }

        batches.sort((a, b) {
          final aDate = parseExpDate(a.expDate);
          final bDate = parseExpDate(b.expDate);
          return aDate.compareTo(bDate);
        });

        int qtyRemaining = rx['jumlah'] as int;

        for (final batch in batches) {
          if (qtyRemaining <= 0) break;
          final batchId = batch.id;
          final currentStock = batch.stok as int;
          if (currentStock <= 0 || batchId == null) continue;

          final int take = min(qtyRemaining, currentStock);

          final medId = _generateUuidV4();
          final medData = {
            'id': medId,
            'id_clinical_encounters': encounterId,
            'id_detail_medicine': batchId,
            'quantity': take.toDouble(),
            'dosage_instructions': rx['aturan'] ?? '',
            'notes': '',
            'created_at': nowStr,
          };

          final medPrevHash = await _getPreviousHash('medicine_ecounter');
          medData['current_hash'] = _computeBlockchainHash(
            medData,
            medPrevHash,
          );
          medData['previous_hash'] = medPrevHash;

          await _post('medicine_ecounter', medData, schema: 'private_doctor');

          final nextStock = currentStock - take;
          await adjustDoctorBatchStock(batchId, nextStock);

          qtyRemaining -= take;
        }
      }

      // 6. Insert Electronic Prescription & items
      if (recommendedApotekId != null ||
          manualPrescriptions.isNotEmpty ||
          prescriptions.isNotEmpty) {
        final prescriptionId = _generateUuidV4();

        final prescriptionData = {
          'id': prescriptionId,
          'id_clinical_encounter': encounterId,
          'prescription_source': 'private_doctor',
          'qr_code_data': '',
          'qr_code': prescriptionId,
          'recommended_pharmacy_id': recommendedApotekId,
          'created_at': nowStr,
        };

        final epPrevHash = await _getPreviousHash('electronic_prescriptions');
        prescriptionData['current_hash'] = _computeBlockchainHash(
          prescriptionData,
          epPrevHash,
        );
        prescriptionData['previous_hash'] = epPrevHash;

        await _post(
          'electronic_prescriptions',
          prescriptionData,
          schema: 'private_doctor',
        );

        final List<Map<String, dynamic>> qrItems = [];

        for (final manual in manualPrescriptions) {
          final itemId = _generateUuidV4();
          final itemData = {
            'id': itemId,
            'id_electronic_prescription': prescriptionId,
            'id_catalog_item': null,
            'medicine_name': manual['nama'] ?? '',
            'quantity': (manual['jumlah'] ?? 1).toString(),
            'dosage_instructions': manual['aturan'] ?? '',
            'kfa_code': manual['kfa_code'],
            'notes': '',
            'created_at': nowStr,
          };

          final itemPrevHash = await _getPreviousHash(
            'electronic_prescription_items',
          );
          itemData['current_hash'] = _computeBlockchainHash(
            itemData,
            itemPrevHash,
          );
          itemData['previous_hash'] = itemPrevHash;

          await _post(
            'electronic_prescription_items',
            itemData,
            schema: 'private_doctor',
          );

          qrItems.add({
            'source': 'manual',
            'name': manual['nama'] ?? '',
            'qty': (manual['jumlah'] ?? 1).toString(),
            'dosage': manual['aturan'] ?? '',
          });
        }

        for (final rx in prescriptions) {
          final dynamic obatRaw = rx['obat'];
          if (obatRaw == null) continue;
          final itemId = _generateUuidV4();
          final itemData = {
            'id': itemId,
            'id_electronic_prescription': prescriptionId,
            'id_catalog_item': obatRaw.id,
            'medicine_name': obatRaw.nama,
            'quantity': (rx['jumlah'] ?? 1).toString(),
            'dosage_instructions': rx['aturan'] ?? '',
            'kfa_code': obatRaw.kfaCode,
            'notes': '',
            'created_at': nowStr,
          };

          final itemPrevHash = await _getPreviousHash(
            'electronic_prescription_items',
          );
          itemData['current_hash'] = _computeBlockchainHash(
            itemData,
            itemPrevHash,
          );
          itemData['previous_hash'] = itemPrevHash;

          await _post(
            'electronic_prescription_items',
            itemData,
            schema: 'private_doctor',
          );

          qrItems.add({
            'source': 'catalog',
            'name': obatRaw.nama,
            'qty': (rx['jumlah'] ?? 1).toString(),
            'dosage': rx['aturan'] ?? '',
          });
        }

        final qrPayload = {
          'prescription_id': prescriptionId,
          'encounter_id': encounterId,
          'doctor_id': doctorId,
          'created_at': nowStr,
          'items': qrItems,
        };

        final String verificationHash = sha256
            .convert(utf8.encode(jsonEncode(qrPayload)))
            .toString();
        qrPayload['verification_hash'] = verificationHash;

        await _patch(
          'electronic_prescriptions?id=eq.$prescriptionId',
          {'qr_code_data': jsonEncode(qrPayload)},
          schema: 'private_doctor',
        );
      }
      return encounterId;
    } catch (e) {
      throw Exception('Gagal menyimpan Rekam Medis (EMR): $e');
    }
  }

  // Fetch all doctors with their user profile details and queues
  Future<List<Map<String, dynamic>>> fetchAllDoctors() async {
    try {
      final doctorsRaw = await _get('user_detail_doctor?select=*,user:id(*)', schema: 'public');
      
      List<dynamic> queuesRaw = [];
      try {
        queuesRaw = await _get('doctor_queues?select=*', schema: 'public');
      } catch (e) {
        print('Error fetching doctor queues statistics: $e');
      }

      final Map<String, Map<String, dynamic>> queuesMap = {
        for (var q in queuesRaw) 
          if (q is Map && q['id_doctor'] != null)
            (q['id_doctor'] as String): Map<String, dynamic>.from(q),
      };

      final List<Map<String, dynamic>> doctorsList = [];
      for (final doc in doctorsRaw) {
        if (doc is! Map) continue;
        final docMap = Map<String, dynamic>.from(doc);
        final userRaw = docMap['user'];
        if (userRaw != null && userRaw is Map) {
          final userMap = Map<String, dynamic>.from(userRaw);
          
          final doctorId = docMap['id'] as String;
          final queueInfo = queuesMap[doctorId];

          doctorsList.add({
            'id': doctorId,
            'name': userMap['name'] ?? '',
            'email': userMap['email'] ?? '',
            'avatar_url': userMap['avatar_url'] ?? docMap['satusehat_photo_url'],
            'nama_faskes': docMap['nama_faskes'] ?? 'Praktek Mandiri',
            'profession': docMap['profession'] ?? 'Dokter',
            'is_visible': docMap['is_visible'] ?? true,
            'is_bpjs': docMap['is_bpjs'] ?? false,
            'about': docMap['about'] ?? '',
            'whatsapp_number': docMap['whatsapp_number'] ?? userMap['phone_number'] ?? '',
            'latitude': docMap['latitude'],
            'longitude': docMap['longitude'],
            'default_service_fee': docMap['default_service_fee'] ?? 0.0,
            'address': userMap['address'] ?? docMap['nama_faskes'] ?? '',
            'province': userMap['province'] ?? '',
            'district': userMap['district'] ?? '',
            'sub_district': userMap['sub_district'] ?? '',
            'village': userMap['village'] ?? '',
            'active_today': queueInfo?['active_today'] ?? 0,
            'finished_total': queueInfo?['finished_total'] ?? 0,
            'practice_licenses': docMap['practice_licenses'],
            'google_maps_link': docMap['google_maps_link'] ?? '',
          });
        }
      }
      return doctorsList;
    } catch (e) {
      throw Exception('Gagal mengambil daftar dokter: $e');
    }
  }

  // Create a booking (queue) for a patient with a specific doctor on a given date
  Future<void> createBooking({
    required String doctorId,
    required String patientId,
    required DateTime date,
  }) async {
    try {
      final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      // Get count of existing queues for that doctor on that date to assign no_queue
      final existing = await _get(
        'queue?id_doctor=eq.${Uri.encodeComponent(doctorId)}&date_queue=eq.$dateStr&select=id',
        schema: 'private_doctor',
      );
      final noQueue = (existing.length + 1).toString().padLeft(3, '0');
      await _post('queue', {
        'id_doctor': doctorId,
        'id_patient': patientId,
        'no_queue': noQueue,
        'patient_type': 'umum',
        'date_queue': dateStr,
        'date_queue_ts': '${dateStr}T00:00:00',
      }, schema: 'private_doctor');
    } catch (e) {
      throw Exception('Gagal membuat booking: $e');
    }
  }

  // Fetch schedules for a specific doctor
  Future<List<Map<String, dynamic>>> fetchDoctorSchedules(String doctorId) async {
    try {
      final safeDoctorId = Uri.encodeComponent(doctorId);
      final schedules = await _get('doctor_schedules?select=*&id_doctor=eq.$safeDoctorId', schema: 'public');
      return schedules.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil jadwal dokter: $e');
    }
  }
}
