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

      // Send onboarding welcome email via Resend API asynchronously
      sendWelcomeEmail(
        email: email,
        name: name,
        role: role,
      ).catchError((e) {
        print('Failed to send welcome email: $e');
        return false;
      });

      return {
        'success': true,
        'user': response.user,
        'message':
            'Pendaftaran berhasil! Akun Anda telah aktif dan siap digunakan.',
      };
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  /// Checks if an email is already registered in the public.user table.
  /// Returns true if it exists, false otherwise.
  Future<bool> checkEmailExists(String email) async {
    try {
      final rows = await _get('user?email=eq.${Uri.encodeComponent(email)}&limit=1');
      return rows.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  /// Checks if a NIK is already registered with the same role in the public.user table.
  /// Returns true if a duplicate NIK with the same role exists, false otherwise.
  Future<bool> checkNikExists(String nik, String role) async {
    try {
      String roleQuery;
      if (role == 'pasien' || role == 'patient') {
        roleQuery = 'role=in.(pasien,patient)';
      } else if (role == 'dokter' || role == 'praktikmandiri') {
        roleQuery = 'role=in.(dokter,praktikmandiri)';
      } else {
        roleQuery = 'role=eq.${Uri.encodeComponent(role)}';
      }
      final rows = await _get(
        'user?nik=eq.${Uri.encodeComponent(nik)}&$roleQuery&limit=1',
      );
      return rows.isNotEmpty;
    } catch (e) {
      print('Error checking NIK: $e');
      return false;
    }
  }

  /// Sends a welcome email using the Resend API.
  Future<bool> sendWelcomeEmail({
    required String email,
    required String name,
    required String role,
  }) async {
    try {
      final apiKey = dotenv.env['RESEND_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('Resend API Key is not configured in env file');
        return false;
      }

      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'from': 'MAPOTECH <no-reply@Relvastudio.com>',
          'to': email,
          'subject': 'Welcome to MAPOTECH!',
          'html': '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>Welcome to MAPOTECH</title>
    <style type="text/css">
        body { width:100% !important; -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%; margin:0; padding:0; background-color: #f0faf8; font-family: 'Segoe UI', Helvetica, Arial, sans-serif; }
        h1, h2, h3 { color: #1B4F42 !important; }
        a { color: #48C9B0; }
    </style>
</head>
<body style="background-color: #f0faf8; margin: 0; padding: 40px 0;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <tr>
            <td align="center" style="padding: 0 16px;">
                <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #ffffff; border-radius: 24px; overflow: hidden; box-shadow: 0 8px 40px rgba(27, 79, 66, 0.12);">
                    <tr>
                        <td align="center" style="background: linear-gradient(135deg, #1B4F42 0%, #2d7a66 100%); padding: 40px 40px 32px;">
                            <table border="0" cellpadding="0" cellspacing="0">
                                <tr>
                                    <td valign="middle" style="padding-right: 12px;"><div style="width: 10px; height: 10px; border-radius: 50%; background: #48C9B0;"></div></td>
                                    <td valign="middle"><h1 style="color: #ffffff; font-size: 28px; font-weight: 900; letter-spacing: -1px; margin: 0; padding: 0; line-height: 1;">MAPOTECH</h1></td>
                                    <td valign="middle" style="padding-left: 12px;"><div style="width: 10px; height: 10px; border-radius: 50%; background: #48C9B0;"></div></td>
                                </tr>
                            </table>
                            <p style="color: rgba(255,255,255,0.6); font-size: 11px; font-weight: 700; letter-spacing: 0.2em; text-transform: uppercase; margin: 12px 0 0 0; line-height: 1;">Digital Health System</p>
                        </td>
                    </tr>
                    <tr>
                        <td align="center" style="padding: 44px 40px 36px;">
                            <h2 style="font-size: 22px; font-weight: 700; color: #1B4F42; margin: 0 0 8px 0; line-height: 1.2;">Registration Complete!</h2>
                            <p style="font-size: 14px; color: #6b7280; font-weight: 500; margin: 0 0 20px 0; line-height: 1.6; text-align: left;">
                                Hello <strong>$name</strong>,<br/><br/>
                                You have successfully registered on MAPOTECH! Your account is active and verified, so there is no need for further confirmation.
                            </p>
                            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #E8F8F5; border-radius: 12px; margin-bottom: 24px;">
                                <tr>
                                    <td style="padding: 16px; font-size: 13px; color: #1B4F42; line-height: 1.5;">
                                        <strong>Account Info:</strong><br/>
                                        • Email: $email<br/>
                                        • Registered As: ${role == 'patient' ? 'Patient (Masyarakat)' : role == 'praktikmandiri' ? 'Private Practice (Doctor)' : 'Pharmacy (Apotek)'}
                                    </td>
                                </tr>
                            </table>
                            <p style="font-size: 13px; color: #6b7280; line-height: 1.6; margin-bottom: 24px; text-align: left;">
                                You can log in now to the portal or launch the application via the link below:
                            </p>
                            <table border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                                <tr>
                                    <td align="center" bgcolor="#1B4F42" style="border-radius: 8px;">
                                        <a href="https://mapotech.app" target="_blank" style="font-size: 14px; font-weight: 700; color: #ffffff; text-decoration: none; padding: 12px 24px; display: inline-block;">Login to MAPOTECH</a>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td align="center" style="background: #f8fffe; border-top: 1px solid #e0f5f0; padding: 24px 40px;">
                            <p style="color: #9ca3af; font-size: 12px; font-weight: 500; line-height: 1.8; margin: 0;">
                                © 2026 <span style="color: #48C9B0; font-weight: 800;">MAPOTECH</span> Digital Health System. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
''',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Failed to send welcome email: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending welcome email: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // AUTH — OTP (send & verify via otp_verifications table)
  // ─────────────────────────────────────────────────────────────────

  Future<String> sendOtp(String email) async {
    try {
      // Invoke Supabase Edge Function to send email without CORS errors
      final response = await client.functions.invoke(
        'otp-handler',
        body: {
          'action': 'send',
          'email': email,
        },
      );

      if (response.status != 200) {
        throw Exception('Server error status ${response.status}');
      }

      // Query the database to retrieve the generated OTP code for dev mode/debug display
      final rows = await _get(
        'otp_verifications?email=eq.${Uri.encodeComponent(email)}&order=created_at.desc&limit=1',
      );
      if (rows.isNotEmpty) {
        final row = rows.first as Map<String, dynamic>;
        return row['otp_code'] as String;
      }
      return '';
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

  // Fetch public health center (puskesmas) details by user ID
  Future<Map<String, dynamic>?> fetchPuskesmasDetail(String id) async {
    try {
      final details = await _get(
        'user_detail_public_health_center?select=*&id=eq.$id',
        schema: 'public',
      );
      if (details.isNotEmpty) {
        return details.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Save public health center (puskesmas) details
  Future<void> savePuskesmasDetail(String id, Map<String, dynamic> data) async {
    try {
      await client.from('user_detail_public_health_center').upsert({
        'id': id,
        ...data,
      });
    } catch (e) {
      await _patch('user_detail_public_health_center?id=eq.$id', data, schema: 'public');
    }
  }

  // Save public health center (puskesmas) map location
  Future<void> savePuskesmasMapLocation({
    required String puskesmasId,
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    try {
      await client.from('user_detail_public_health_center').upsert({
        'id': puskesmasId,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'address': locationName,
      });
    } catch (e) {
      print('Error saving puskesmas map location: $e');
    }
  }


  // Fetch village clinic (ponkesdes) details by user ID
  Future<Map<String, dynamic>?> fetchPonkesdesDetail(String id) async {
    try {
      final details = await _get(
        'user_detail_village_clinic?select=*&id=eq.$id',
        schema: 'public',
      );
      if (details.isNotEmpty) {
        return details.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Save village clinic (ponkesdes) details
  Future<void> savePonkesdesDetail(String id, Map<String, dynamic> data) async {
    await _patch('user_detail_village_clinic?id=eq.$id', data, schema: 'public');
  }

  // Update patient profile data and patient_details in the database
  Future<void> updatePatientProfile(
    String userId,
    Map<String, dynamic> data, {
    Map<String, dynamic>? patientDetailData,
  }) async {
    try {
      await client.from('user').update(data).eq('id', userId);
    } catch (e) {
      print('Error updating user: $e');
    }

    if (patientDetailData != null && patientDetailData.isNotEmpty) {
      try {
        await client.from('user_detail_patient').upsert({
          'id': userId,
          ...patientDetailData,
        });
      } catch (e) {
        print('Error updating user_detail_patient: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PATIENT FAMILY MEMBERS CRUD (patient_family_members table)
  // ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchFamilyMembers(String patientId) async {
    try {
      final response = await client
          .from('patient_family_members')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching family members: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> addFamilyMember(Map<String, dynamic> memberData) async {
    try {
      final response = await client
          .from('patient_family_members')
          .insert(memberData)
          .select();
      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
    } catch (e) {
      print('Error adding family member: $e');
    }
    return null;
  }

  Future<bool> disbandKkGroup(String patientId) async {
    try {
      // 1. Update status is_kepala_keluarga to false
      await client.from('user_detail_patient').upsert({
        'id': patientId,
        'is_kepala_keluarga': false,
      });

      // 2. Remove all family members connected under this patient
      await client
          .from('patient_family_members')
          .delete()
          .eq('patient_id', patientId);
      return true;
    } catch (e) {
      print('Error disbanding KK group: $e');
      return false;
    }
  }

  Future<bool> updateKepalaKeluargaStatus(String patientId, bool isKepala, {String? noKk}) async {
    try {
      final payload = <String, dynamic>{
        'id': patientId,
        'is_kepala_keluarga': isKepala,
        'accept_kk': true,
      };
      if (noKk != null && noKk.isNotEmpty) {
        payload['no_kk'] = noKk;
      }
      await client.from('user_detail_patient').upsert(payload);
      return true;
    } catch (e) {
      print('Error updating status kepala keluarga: $e');
      return false;
    }
  }

  Future<bool> deleteFamilyMember(String id) async {
    try {
      await client
          .from('patient_family_members')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting family member: $e');
      return false;
    }
  }

  // Search registered patients in public.user table
  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    try {
      final safe = Uri.encodeComponent(query);
      final response = await client
          .from('user')
          .select('id, name, nik, gender, birth_date, phone_number')
          .or('role.eq.pasien,role.eq.patient')
          .or('name.ilike.%$safe%,nik.ilike.%$safe%')
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching patients: $e');
      return [];
    }
  }

  // Request to join a KK by 16-digit KK number (accept_kk = false)
  Future<bool> joinKkByNumber({
    required String patientId,
    required String patientName,
    required String patientNik,
    required String noKk,
  }) async {
    try {
      // 1. Find if there's any host patient with this no_kk in user_detail_patient
      final hostRows = await client
          .from('user_detail_patient')
          .select('id, no_kk')
          .eq('no_kk', noKk)
          .neq('id', patientId)
          .limit(1);

      final String hostPatientId = hostRows.isNotEmpty
          ? hostRows.first['id'].toString()
          : patientId;

      // 2. Set user_detail_patient for joining user to accept_kk = false
      await client.from('user_detail_patient').upsert({
        'id': patientId,
        'no_kk': noKk,
        'accept_kk': false,
      });

      // 3. Add row to patient_family_members under host's patient_id with accept_kk = false
      await client.from('patient_family_members').insert({
        'patient_id': hostPatientId,
        'member_user_id': patientId,
        'nama': patientName,
        'nik': patientNik,
        'hubungan': 'Anggota KK (Permintaan Gabung)',
        'status_kesehatan': 'Menunggu Persetujuan KK',
        'accept_kk': false,
      });

      return true;
    } catch (e) {
      print('Error joining KK: $e');
      return false;
    }
  }

  // Accept or reject a family member join request
  Future<bool> updateFamilyMemberAcceptStatus(String memberId, {required bool accept, String? memberUserId}) async {
    try {
      if (accept) {
        await client
            .from('patient_family_members')
            .update({'accept_kk': true, 'status_kesehatan': 'Disetujui / Aktif'})
            .eq('id', memberId);

        if (memberUserId != null) {
          await client
              .from('user_detail_patient')
              .update({'accept_kk': true})
              .eq('id', memberUserId);
        }
      } else {
        await client
            .from('patient_family_members')
            .delete()
            .eq('id', memberId);
      }
      return true;
    } catch (e) {
      print('Error updating accept_kk status: $e');
      return false;
    }
  }

  /// Returns the corresponding detail user table name for a given user role.
  static String? getDetailTableNameForRole(String? role) {
    if (role == null) return null;
    final r = role.toLowerCase().trim();
    if (r == 'dokter' || r == 'doctor' || r == 'praktikmandiri') {
      return 'user_detail_doctor';
    } else if (r == 'pasien' || r == 'patient') {
      return 'user_detail_patient';
    } else if (r == 'apotek' || r == 'pharmacy' || r == 'pharmacist') {
      return 'user_detail_pharmacist';
    } else if (r == 'puskesmas' || r == 'public_health_center') {
      return 'user_detail_public_health_center';
    } else if (r == 'ponkesdes' || r == 'village_clinic' || r == 'clinic') {
      return 'user_detail_village_clinic';
    } else if (r == 'asisten_dokter' || r == 'assistant') {
      return 'user_detail_doctor_assistant';
    } else if (r == 'asisten_apotek' || r == 'pharmacist_staff') {
      return 'user_detail_pharmacist_staff';
    }
    return null;
  }

  /// Fetches favorite menu items from the user's detail table (JSONB column favorite_menus).
  Future<Set<String>?> fetchFavoriteMenusFromUserDetail(
    String userId,
    String? role,
  ) async {
    final tableName = getDetailTableNameForRole(role);
    if (tableName == null) return null;
    try {
      final res = await client
          .from(tableName)
          .select('favorite_menus')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && res['favorite_menus'] != null) {
        final raw = res['favorite_menus'];
        if (raw is List) {
          return raw.map((e) => e.toString()).toSet();
        } else if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              return decoded.map((e) => e.toString()).toSet();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error fetching favorite_menus from $tableName: $e');
    }
    return null;
  }

  /// Saves favorite menu items into the user's detail table (JSONB column favorite_menus).
  Future<void> saveFavoriteMenusToUserDetail(
    String userId,
    String? role,
    List<String> favoriteMenus,
  ) async {
    final tableName = getDetailTableNameForRole(role);
    if (tableName == null) return;
    try {
      await client
          .from(tableName)
          .upsert({
            'id': userId,
            'favorite_menus': favoriteMenus,
          });
    } catch (e) {
      print('Error saving favorite_menus to $tableName: $e');
    }
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

  // Fetch private clinical encounters directly from the private_doctor schema (for detailed columns)
  Future<List<Map<String, dynamic>>> fetchPrivateClinicalEncounters(
    List<String> queueIds,
  ) async {
    if (queueIds.isEmpty) return [];
    try {
      final res = await client
          .schema('private_doctor')
          .from('clinical_encounters')
          .select('*')
          .inFilter('id_queue', queueIds);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('Error fetching private clinical encounters: $e');
      return [];
    }
  }

  // Fetch diagnoses associated with a clinical encounter
  Future<List<Map<String, dynamic>>> fetchClinicalEncounterDiagnoses(
    String encounterId,
  ) async {
    try {
      final res = await client
          .schema('private_doctor')
          .from('icdx_ecounter')
          .select('*')
          .eq('id_clinical_ecounters', encounterId);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('Error fetching encounter diagnoses: $e');
      return [];
    }
  }

  // Fetch vital signs associated with a clinical encounter
  Future<Map<String, dynamic>?> fetchEncounterVitals(String encounterId) async {
    try {
      final res = await client
          .schema('private_doctor')
          .from('vital_signs')
          .select('*')
          .eq('id_clinical_ecounter', encounterId)
          .maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // Fetch anamnesis associated with a clinical encounter
  Future<Map<String, dynamic>?> fetchEncounterAnamnesis(String encounterId) async {
    try {
      final res = await client
          .schema('private_doctor')
          .from('anamnesis_ecounter')
          .select('*')
          .eq('id_clinical_ecounter', encounterId)
          .maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // Fetch medicines and manual prescriptions associated with a clinical encounter
  Future<List<Map<String, dynamic>>> fetchClinicalEncounterMedicines(
    String encounterId,
  ) async {
    final List<Map<String, dynamic>> medicinesList = [];
    try {
      // 1. Catalog medicines from medicine_ecounter
      final medicinesRes = await client
          .schema('private_doctor')
          .from('medicine_ecounter')
          .select('quantity, id_detail_medicine')
          .eq('id_clinical_encounters', encounterId);

      for (final medRow in medicinesRes) {
        final qty = double.tryParse(medRow['quantity']?.toString() ?? '0') ?? 0.0;
        final detailMedId = medRow['id_detail_medicine'];
        if (detailMedId != null) {
          final dmRes = await client
              .schema('private_doctor')
              .from('detail_medicine')
              .select('id_medicine')
              .eq('id', detailMedId)
              .maybeSingle();

          if (dmRes != null) {
            final medId = dmRes['id_medicine'];
            String medicineName = 'Obat';
            if (medId != null) {
              final mRes = await client
                  .schema('private_doctor')
                  .from('medicine')
                  .select('medicine_name')
                  .eq('id', medId)
                  .maybeSingle();
              if (mRes != null) {
                medicineName = mRes['medicine_name']?.toString() ?? 'Obat';
              }
            }
            medicinesList.add({
              'name': medicineName,
              'quantity': qty.toInt(),
              'rules': 'Sesuai petunjuk',
            });
          }
        }
      }
    } catch (e) {
      print('Error loading catalog medicines: $e');
    }

    try {
      // 2. Electronic prescriptions (manual items)
      final epRes = await client
          .schema('private_doctor')
          .from('electronic_prescriptions')
          .select('*, electronic_prescription_items(*)')
          .eq('id_clinical_encounter', encounterId)
          .maybeSingle();

      if (epRes != null) {
        final items = epRes['electronic_prescription_items'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
            medicinesList.add({
              'name': item['medicine_name']?.toString() ?? 'Obat Resep',
              'quantity': qty.toInt(),
              'rules': item['dosage_instructions']?.toString() ?? '3 x 1',
            });
          }
        }
      }
    } catch (e) {
      print('Error loading electronic prescriptions: $e');
    }

    return medicinesList;
  }

  // Fetch transaction items for a financial transaction
  Future<List<Map<String, dynamic>>> fetchTransactionItems(
    String transactionId,
  ) async {
    try {
      final res = await client
          .schema('pharmacy')
          .from('transaction_items')
          .select('*, medicine_batches(*, medicines(*))')
          .eq('id_transaction', transactionId);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      try {
        final resFallback = await client
            .schema('pharmacy')
            .from('transaction_items')
            .select('*, medicine_batches(*)')
            .eq('id_transaction', transactionId);
        return List<Map<String, dynamic>>.from(resFallback as List);
      } catch (e) {
        print('Error fetching transaction items: $e');
        return [];
      }
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
        'user?select=*&role=in.(pasien,patient)',
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

  // Fetch pharmacist staff
  Future<List<Map<String, dynamic>>> fetchPharmacistStaff(String apotekId) async {
    try {
      final rows = await _get(
        'user_detail_pharmacist_staff?select=*,user:id(name,email,nik,phone_number,username,gender,birth_place,birth_date,address,province,district,sub_district,village,created_at)&apotek_id=eq.$apotekId',
        schema: 'public',
      );

      final List<Map<String, dynamic>> staffList = [];
      for (final row in rows) {
        final rowMap = Map<String, dynamic>.from(row as Map);
        final userMap = rowMap['user'] != null
            ? Map<String, dynamic>.from(rowMap['user'] as Map)
            : null;
        if (userMap != null) {
          staffList.add({
            'id': rowMap['id'],
            'apotek_id': rowMap['apotek_id'],
            'nama': userMap['name'] ?? '',
            'email': userMap['email'] ?? '-',
            'nik': userMap['nik'] ?? '',
            'telepon': userMap['phone_number'] ?? '',
            'username': userMap['username'] ?? '',
            'created_at': userMap['created_at'] ?? '',
            'strttk': rowMap['sipa_number'] ?? '-',
            'peran': rowMap['job_title'] ?? 'Asisten Apoteker',
            'shift': rowMap['shift'] ?? 'Pagi',
            'isStandby': rowMap['status'] == 'Active',
            'permissions': ['POS Kasir'], // default mock permissions
          });
        }
      }
      return staffList;
    } catch (e) {
      throw Exception('Gagal mengambil daftar staff apotek: $e');
    }
  }

  // Create pharmacist staff
  Future<void> addPharmacistStaff({
    required String apotekId,
    required String staffId,
    required String name,
    required String email,
    required String nik,
    required String phone,
    required String strttk,
    required String peran,
    required String shift,
    required String username,
    required String password,
  }) async {
    try {
      // 1. Fetch pharmacist's instance_id from user_role
      String? instanceId;
      final pharmacistRoles = await _get(
        'user_role?select=id_instance&id_user=eq.$apotekId',
        schema: 'public',
      );
      if (pharmacistRoles.isNotEmpty) {
        instanceId =
            (pharmacistRoles.first as Map<String, dynamic>)['id_instance']
                as String?;
      }

      // Hash password using Bcrypt
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // 2. Insert into public.user
      final userData = {
        'id': staffId,
        'name': name,
        'email': email.isEmpty || email == '-' ? null : email,
        'nik': nik,
        'phone_number': phone,
        'role': 'asisten_apotek',
        'username': username,
        'password': hashedPassword,
      };
      await _post('user', userData, schema: 'public');

      // 3. Insert into public.user_role
      final roleData = {
        'id_user': staffId,
        'id_role': 12, // 12 is 'pharmacist_staff'
        'type': 'pharmacist',
        'id_instance': instanceId,
      };
      await _post('user_role', roleData, schema: 'public');

      // 4. Insert into public.user_detail_pharmacist_staff
      final staffData = {
        'id': staffId,
        'apotek_id': apotekId,
        'job_title': peran,
        'sipa_number': strttk,
        'shift': shift,
        'status': 'Active',
      };
      await _post(
        'user_detail_pharmacist_staff',
        staffData,
        schema: 'public',
      );
    } catch (e) {
      throw Exception('Gagal mendaftarkan staff apotek: $e');
    }
  }

  // Delete pharmacist staff
  Future<void> deletePharmacistStaff(String staffId) async {
    try {
      await _delete(
        'user_detail_pharmacist_staff?id=eq.$staffId',
        schema: 'public',
      );
      await _delete('user_role?id_user=eq.$staffId', schema: 'public');
      await _delete('user?id=eq.$staffId', schema: 'public');
    } catch (e) {
      throw Exception('Gagal menghapus staff apotek: $e');
    }
  }

  // Update duty status
  Future<void> updatePharmacistStaffDuty(String staffId, bool isActive) async {
    try {
      await _patch(
        'user_detail_pharmacist_staff?id=eq.$staffId',
        {'status': isActive ? 'Active' : 'Inactive'},
        schema: 'public',
      );
    } catch (e) {
      throw Exception('Gagal memperbarui status staff apotek: $e');
    }
  }

  // Update shift
  Future<void> updatePharmacistStaffShift(String staffId, String shift) async {
    try {
      await _patch(
        'user_detail_pharmacist_staff?id=eq.$staffId',
        {'shift': shift},
        schema: 'public',
      );
    } catch (e) {
      throw Exception('Gagal memperbarui shift staff apotek: $e');
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
    String? suratKeteranganType,
    String? suratKeperluan,
    String? suratRiwayatPenyakit,
    int? suratSakitHari,
    String? suratSakitMulai,
    String? suratSakitSelesai,
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
        'surat_keterangan_type': suratKeteranganType,
        'surat_keperluan': suratKeperluan,
        'surat_riwayat_penyakit': suratRiwayatPenyakit,
        'surat_sakit_hari': suratSakitHari,
        'surat_sakit_mulai': suratSakitMulai,
        'surat_sakit_selesai': suratSakitSelesai,
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
      
      List<dynamic> puskesmasRaw = [];
      try {
        puskesmasRaw = await _get('user_detail_public_health_center?select=*,user:id(*)', schema: 'public');
      } catch (e) {
        print('Error fetching puskesmas for search: $e');
      }

      List<dynamic> ponkesdesRaw = [];
      try {
        ponkesdesRaw = await _get('user_detail_village_clinic?select=*,user:id(*)', schema: 'public');
      } catch (e) {
        print('Error fetching ponkesdes for search: $e');
      }

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
      
      // 1. Map Doctors
      for (final doc in doctorsRaw) {
        if (doc is! Map) continue;
        final docMap = Map<String, dynamic>.from(doc);
        final userRaw = docMap['user'];
        if (userRaw != null && userRaw is Map) {
          final userMap = Map<String, dynamic>.from(userRaw);
          
          final doctorId = docMap['id'] as String;
          final queueInfo = queuesMap[doctorId];

          final subStatus = (docMap['subscription_status'] ?? 'INACTIVE').toString().toUpperCase();
          final subExpiredAt = docMap['subscription_expired_at'];
          bool isSubActive = false;
          if (subStatus == 'ACTIVE' && subExpiredAt != null) {
            try {
              final expiry = DateTime.parse(subExpiredAt.toString());
              isSubActive = expiry.isAfter(DateTime.now());
            } catch (_) {}
          }

          final isVisible = isSubActive && (docMap['is_visible'] ?? true);

          doctorsList.add({
            'id': doctorId,
            'name': userMap['name'] ?? '',
            'email': userMap['email'] ?? '',
            'avatar_url': userMap['avatar_url'] ?? docMap['satusehat_photo_url'],
            'nama_faskes': docMap['nama_faskes'] ?? 'Praktek Mandiri',
            'profession': docMap['profession'] ?? 'Dokter',
            'is_visible': isVisible,
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
            'header_bg_settings': docMap['header_bg_settings'],
          });
        }
      }

      // 2. Map Puskesmas (bypassing subscription check)
      for (final pusk in puskesmasRaw) {
        if (pusk is! Map) continue;
        final puskMap = Map<String, dynamic>.from(pusk);
        final userRaw = puskMap['user'];
        if (userRaw != null && userRaw is Map) {
          final userMap = Map<String, dynamic>.from(userRaw);
          final puskId = puskMap['id'] as String;
          final isVisible = puskMap['is_visible'] ?? true;
          
          final mapsLink = puskMap['google_maps_link'] ?? '';
          final coords = extractLatLngFromMapsLink(mapsLink);

          doctorsList.add({
            'id': puskId,
            'name': puskMap['facility_name'] ?? userMap['name'] ?? '',
            'email': userMap['email'] ?? '',
            'avatar_url': userMap['avatar_url'] ?? '',
            'nama_faskes': puskMap['facility_name'] ?? 'Puskesmas',
            'profession': puskMap['profession'] ?? 'Puskesmas',
            'is_visible': isVisible,
            'is_bpjs': puskMap['is_bpjs'] ?? true,
            'about': puskMap['about'] ?? '',
            'whatsapp_number': puskMap['phone'] ?? userMap['phone_number'] ?? '',
            'latitude': coords['latitude'],
            'longitude': coords['longitude'],
            'default_service_fee': 0.0,
            'address': puskMap['address'] ?? '',
            'province': puskMap['province'] ?? userMap['province'] ?? '',
            'district': puskMap['district'] ?? userMap['district'] ?? '',
            'sub_district': puskMap['sub_district'] ?? userMap['sub_district'] ?? '',
            'village': puskMap['village'] ?? userMap['village'] ?? '',
            'active_today': 0,
            'finished_total': 0,
            'practice_licenses': [],
            'google_maps_link': mapsLink,
            'header_bg_settings': null,
          });
        }
      }

      // 3. Map Ponkesdes (bypassing subscription check)
      for (final ponk in ponkesdesRaw) {
        if (ponk is! Map) continue;
        final ponkMap = Map<String, dynamic>.from(ponk);
        final userRaw = ponkMap['user'];
        if (userRaw != null && userRaw is Map) {
          final userMap = Map<String, dynamic>.from(userRaw);
          final ponkId = ponkMap['id'] as String;
          final isVisible = ponkMap['is_visible'] ?? true;
          
          final mapsLink = ponkMap['google_maps_link'] ?? '';
          final coords = extractLatLngFromMapsLink(mapsLink);

          doctorsList.add({
            'id': ponkId,
            'name': ponkMap['clinic_name'] ?? userMap['name'] ?? '',
            'email': userMap['email'] ?? '',
            'avatar_url': userMap['avatar_url'] ?? '',
            'nama_faskes': ponkMap['clinic_name'] ?? 'Ponkesdes',
            'profession': ponkMap['profession'] ?? 'Ponkesdes',
            'is_visible': isVisible,
            'is_bpjs': ponkMap['is_bpjs'] ?? false,
            'about': ponkMap['about'] ?? '',
            'whatsapp_number': ponkMap['phone'] ?? userMap['phone_number'] ?? '',
            'latitude': coords['latitude'],
            'longitude': coords['longitude'],
            'default_service_fee': 0.0,
            'address': ponkMap['address'] ?? '',
            'province': ponkMap['province'] ?? userMap['province'] ?? '',
            'district': ponkMap['district'] ?? userMap['district'] ?? '',
            'sub_district': ponkMap['sub_district'] ?? userMap['sub_district'] ?? '',
            'village': ponkMap['village'] ?? userMap['village'] ?? '',
            'active_today': 0,
            'finished_total': 0,
            'practice_licenses': [],
            'google_maps_link': mapsLink,
            'header_bg_settings': null,
          });
        }
      }

      return doctorsList;
    } catch (e) {
      throw Exception('Gagal mengambil daftar dokter: $e');
    }
  }

  /// Extracts coordinates from a Google Maps link.
  /// Handles both @lat,lng format and q=lat,lng format.
  static Map<String, double?> extractLatLngFromMapsLink(String urlStr) {
    if (urlStr.isEmpty) return {'latitude': null, 'longitude': null};
    
    // 1. Try matching @-7.973354,113.8801833
    final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    var match = atRegex.firstMatch(urlStr);
    if (match != null) {
      return {
        'latitude': double.tryParse(match.group(1) ?? ''),
        'longitude': double.tryParse(match.group(2) ?? ''),
      };
    }
    
    // 2. Try matching q=-7.973354,113.8801833
    final qRegex = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    match = qRegex.firstMatch(urlStr);
    if (match != null) {
      return {
        'latitude': double.tryParse(match.group(1) ?? ''),
        'longitude': double.tryParse(match.group(2) ?? ''),
      };
    }
    
    return {'latitude': null, 'longitude': null};
  }

  // Fetch all pharmacies with their user profile details
  Future<List<Map<String, dynamic>>> fetchAllPharmacies() async {
    try {
      final pharmaciesRaw = await _get('user_detail_pharmacist?select=*,user:id(*)', schema: 'public');
      
      final List<Map<String, dynamic>> pharmaciesList = [];
      for (final pharm in pharmaciesRaw) {
        if (pharm is! Map) continue;
        final pharmMap = Map<String, dynamic>.from(pharm);
        final userRaw = pharmMap['user'];
        if (userRaw != null && userRaw is Map) {
          final userMap = Map<String, dynamic>.from(userRaw);
          
          final subStatus = (pharmMap['subscription_status'] ?? 'INACTIVE').toString().toUpperCase();
          final subExpiredAt = pharmMap['subscription_expired_at'];
          bool isSubActive = false;
          if (subStatus == 'ACTIVE' && subExpiredAt != null) {
            try {
              final expiry = DateTime.parse(subExpiredAt.toString());
              isSubActive = expiry.isAfter(DateTime.now());
            } catch (_) {}
          }

          final isVisible = isSubActive && (pharmMap['is_visible'] ?? true);

          pharmaciesList.add({
            'id': pharmMap['id'] as String,
            'name': userMap['name'] ?? '',
            'email': userMap['email'] ?? '',
            'avatar_url': userMap['avatar_url'] ?? pharmMap['satusehat_photo_url'],
            'nama_faskes': pharmMap['nama_faskes'] ?? 'Apotek Mandiri',
            'latitude': pharmMap['latitude'],
            'longitude': pharmMap['longitude'],
            'address': userMap['address'] ?? pharmMap['alamat'] ?? '',
            'province': userMap['province'] ?? '',
            'district': userMap['district'] ?? '',
            'sub_district': userMap['sub_district'] ?? '',
            'village': userMap['village'] ?? '',
            'google_maps_link': pharmMap['google_maps_link'] ?? '',
            'subscription_status': subStatus,
            'subscription_expired_at': subExpiredAt,
            'about': pharmMap['about'] ?? '',
            'is_visible': isVisible,
            'whatsapp_number': pharmMap['whatsapp_number'] ?? userMap['phone_number'] ?? '',
          });
        }
      }
      return pharmaciesList;
    } catch (e) {
      throw Exception('Gagal mengambil daftar apotek: $e');
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
      final hourStr = date.hour.toString().padLeft(2, '0');
      final minuteStr = date.minute.toString().padLeft(2, '0');
      await _post('queue', {
        'id_doctor': doctorId,
        'id_patient': patientId,
        'no_queue': noQueue,
        'patient_type': 'umum',
        'date_queue': dateStr,
        'date_queue_ts': '${dateStr}T$hourStr:$minuteStr:00',
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

  /// Registers a patient account by a doctor without changing the doctor's active session.
  Future<Map<String, dynamic>> registerPatientByDoctor({
    required String email,
    required String password,
    required String name,
    required String nik,
    required String gender,
    required String birthPlace,
    required String birthDate, // e.g. "yyyy-MM-dd"
    required String address,
    required String phone,
  }) async {
    try {
      // 1. Check if email already exists
      final emailExists = await checkEmailExists(email);
      if (emailExists) {
        throw Exception('Email sudah terdaftar di sistem MAPOTECH');
      }

      // 2. Check if NIK already exists
      final nikExists = await checkNikExists(nik, 'pasien');
      if (nikExists) {
        throw Exception('NIK sudah terdaftar di sistem MAPOTECH');
      }

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://abdburxhqqwsobmzuwmz.supabase.co';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiZGJ1cnhocXF3c29ibXp1d216Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0OTMyNjYsImV4cCI6MjA5MjA2OTI2Nn0.mB3qIJAHjtWe5UKxE9Oj-RNLQCbQKFYHUZBLaF4nQwk';

      // Create a temporary client instance to register the patient.
      // This prevents the doctor (currently logged in user) from being signed out.
      final tempClient = SupabaseClient(
        supabaseUrl,
        supabaseAnonKey,
        authOptions: AuthClientOptions(
          pkceAsyncStorage: InMemoryStorageAdapter(),
        ),
      );

      final response = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'nik': nik,
          'gender': gender,
          'birth_place': birthPlace,
          'birth_date': birthDate,
          'province': '',
          'regency': '',
          'district': '',
          'village': '',
          'address': address,
          'phone_number': phone,
          'role': 'pasien',
        },
      );

      if (response.user == null) {
        throw Exception('Pendaftaran gagal. Coba lagi.');
      }

      // Send welcome email asynchronously
      sendWelcomeEmail(
        email: email,
        name: name,
        role: 'patient',
      ).catchError((e) {
        print('Failed to send welcome email: $e');
        return false;
      });

      return {
        'success': true,
        'user': response.user,
        'message': 'Pasien berhasil didaftarkan ke sistem MAPOTECH!',
      };
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e.toString().startsWith('Exception: ')) {
        rethrow;
      }
      throw Exception('Gagal mendaftarkan pasien: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PEKERJA (Public Health Center Staff) CRUD
  // ─────────────────────────────────────────────────────────────────

  static const String _staffTable = 'user_detail_public_health_center_staff';

  /// Fetches all workers registered under a given Puskesmas owner.
  Future<List<Map<String, dynamic>>> fetchPekerjaList(String ownerId) async {
    try {
      final rows = await client
          .from(_staffTable)
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Error fetching pekerja list: $e');
      return [];
    }
  }

  /// Inserts a new worker row. Returns the created row map.
  Future<Map<String, dynamic>?> insertPekerja({
    required String ownerId,
    required String nama,
    String? email,
    String? nik,
    String? idPekerja,
    String? peran,
    String? telepon,
    String? username,
    String? gender,
    String? birthPlace,
    String? birthDate,
    String? address,
    String? province,
    String? district,
    String? subDistrict,
    String? village,
    bool isBertugas = true,
    List<String> permissions = const [],
    String avatarColor = '#48C9B0',
  }) async {
    try {
      final payload = <String, dynamic>{
        'owner_id': ownerId,
        'nama': nama,
        if (email != null && email.isNotEmpty) 'email': email,
        if (nik != null && nik.isNotEmpty) 'nik': nik,
        if (idPekerja != null && idPekerja.isNotEmpty) 'id_pekerja': idPekerja,
        if (peran != null && peran.isNotEmpty) 'peran': peran,
        if (telepon != null && telepon.isNotEmpty) 'telepon': telepon,
        if (username != null && username.isNotEmpty) 'username': username,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (birthPlace != null && birthPlace.isNotEmpty) 'birth_place': birthPlace,
        if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
        if (address != null && address.isNotEmpty) 'address': address,
        if (province != null && province.isNotEmpty) 'province': province,
        if (district != null && district.isNotEmpty) 'district': district,
        if (subDistrict != null && subDistrict.isNotEmpty) 'sub_district': subDistrict,
        if (village != null && village.isNotEmpty) 'village': village,
        'is_bertugas': isBertugas,
        'permissions': permissions,
        'avatar_color': avatarColor,
      };

      final rows = await client
          .from(_staffTable)
          .insert(payload)
          .select();

      return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
    } catch (e) {
      print('Error inserting pekerja: $e');
      rethrow;
    }
  }

  /// Updates an existing worker row by its UUID.
  Future<bool> updatePekerja({
    required String workerId,
    String? nama,
    String? email,
    String? nik,
    String? idPekerja,
    String? peran,
    String? telepon,
    String? username,
    String? gender,
    String? birthPlace,
    String? birthDate,
    String? address,
    String? province,
    String? district,
    String? subDistrict,
    String? village,
    bool? isBertugas,
    List<String>? permissions,
    String? avatarColor,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (nama != null) 'nama': nama,
        if (email != null) 'email': email,
        if (nik != null) 'nik': nik,
        if (idPekerja != null) 'id_pekerja': idPekerja,
        if (peran != null) 'peran': peran,
        if (telepon != null) 'telepon': telepon,
        if (username != null) 'username': username,
        if (gender != null) 'gender': gender,
        if (birthPlace != null) 'birth_place': birthPlace,
        if (birthDate != null) 'birth_date': birthDate,
        if (address != null) 'address': address,
        if (province != null) 'province': province,
        if (district != null) 'district': district,
        if (subDistrict != null) 'sub_district': subDistrict,
        if (village != null) 'village': village,
        if (isBertugas != null) 'is_bertugas': isBertugas,
        if (permissions != null) 'permissions': permissions,
        if (avatarColor != null) 'avatar_color': avatarColor,
      };

      await client
          .from(_staffTable)
          .update(payload)
          .eq('id', workerId);

      return true;
    } catch (e) {
      print('Error updating pekerja: $e');
      return false;
    }
  }

  /// Deletes a worker row by its UUID.
  Future<bool> deletePekerja(String workerId) async {
    try {
      await client
          .from(_staffTable)
          .delete()
          .eq('id', workerId);
      return true;
    } catch (e) {
      print('Error deleting pekerja: $e');
      return false;
    }
  }

  /// Toggles the is_bertugas flag for a single worker.
  Future<bool> togglePekerjaDuty(String workerId, bool isBertugas) async {
    try {
      await client
          .from(_staffTable)
          .update({'is_bertugas': isBertugas})
          .eq('id', workerId);
      return true;
    } catch (e) {
      print('Error toggling pekerja duty: $e');
      return false;
    }
  }

  /// Updates only the permissions jsonb column for a worker.
  Future<bool> updatePekerjaPermissions(
      String workerId, List<String> permissions) async {
    try {
      await client
          .from(_staffTable)
          .update({'permissions': permissions})
          .eq('id', workerId);
      return true;
    } catch (e) {
      print('Error updating pekerja permissions: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PUSTU / PONKESDES CRUD
  // ─────────────────────────────────────────────────────────────────

  static const String _pustuTable = 'user_detail_pustu_ponkesdes';

  Future<List<Map<String, dynamic>>> fetchPustuPonkesdesList(String ownerId) async {
    try {
      final rows = await client
          .from(_pustuTable)
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Note: Supabase table $_pustuTable exception or not created yet: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> insertPustuPonkesdes({
    required String ownerId,
    required String nama,
    required String tipe,
    String? kodeUnit,
    String? penanggungJawab,
    String? nikPenanggungJawab,
    String? telepon,
    String? alamat,
    String? village,
    String? kecamatan,
    double? latitude,
    double? longitude,
    String? statusOperasional,
    String? jamLayanan,
    List<String> permissions = const [],
    String avatarColor = '#48C9B0',
  }) async {
    try {
      final payload = <String, dynamic>{
        'owner_id': ownerId,
        'nama': nama,
        'tipe': tipe,
        if (kodeUnit != null) 'kode_unit': kodeUnit,
        if (penanggungJawab != null) 'penanggung_jawab': penanggungJawab,
        if (nikPenanggungJawab != null) 'nik_penanggung_jawab': nikPenanggungJawab,
        if (telepon != null) 'telepon': telepon,
        if (alamat != null) 'alamat': alamat,
        if (village != null) 'village': village,
        if (kecamatan != null) 'kecamatan': kecamatan,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'status_operasional': statusOperasional ?? 'Aktif / Buka',
        if (jamLayanan != null) 'jam_layanan': jamLayanan,
        'permissions': permissions,
        'avatar_color': avatarColor,
      };

      final rows = await client
          .from(_pustuTable)
          .insert(payload)
          .select();

      return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
    } catch (e) {
      print('Error inserting pustu/ponkesdes: $e');
      return null;
    }
  }

  Future<bool> updatePustuPonkesdes({
    required String unitId,
    String? nama,
    String? tipe,
    String? kodeUnit,
    String? penanggungJawab,
    String? nikPenanggungJawab,
    String? telepon,
    String? alamat,
    String? village,
    String? kecamatan,
    double? latitude,
    double? longitude,
    String? statusOperasional,
    String? jamLayanan,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (nama != null) 'nama': nama,
        if (tipe != null) 'tipe': tipe,
        if (kodeUnit != null) 'kode_unit': kodeUnit,
        if (penanggungJawab != null) 'penanggung_jawab': penanggungJawab,
        if (nikPenanggungJawab != null) 'nik_penanggung_jawab': nikPenanggungJawab,
        if (telepon != null) 'telepon': telepon,
        if (alamat != null) 'alamat': alamat,
        if (village != null) 'village': village,
        if (kecamatan != null) 'kecamatan': kecamatan,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (statusOperasional != null) 'status_operasional': statusOperasional,
        if (jamLayanan != null) 'jam_layanan': jamLayanan,
      };

      await client
          .from(_pustuTable)
          .update(payload)
          .eq('id', unitId);

      return true;
    } catch (e) {
      print('Error updating pustu/ponkesdes: $e');
      return false;
    }
  }

  Future<bool> deletePustuPonkesdes(String unitId) async {
    try {
      await client
          .from(_pustuTable)
          .delete()
          .eq('id', unitId);
      return true;
    } catch (e) {
      print('Error deleting pustu/ponkesdes: $e');
      return false;
    }
  }

  Future<bool> togglePustuPonkesdesStatus(String unitId, String newStatus) async {
    try {
      await client
          .from(_pustuTable)
          .update({'status_operasional': newStatus})
          .eq('id', unitId);
      return true;
    } catch (e) {
      print('Error toggling status pustu/ponkesdes: $e');
      return false;
    }
  }
}

/// A lightweight, in-memory implementation of GotrueAsyncStorage
/// to satisfy Supabase PKCE flow requirements on secondary clients.
class InMemoryStorageAdapter extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getItem({required String key}) async {
    return _storage[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _storage[key] = value;
  }
}
