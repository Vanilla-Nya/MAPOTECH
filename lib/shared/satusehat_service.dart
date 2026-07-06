import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:mapotech/shared/supabase_service.dart';


class SatuSehatService {
  final String? clientId;
  final String? clientSecret;
  final String? organizationId;
  final String? locationId;
  final String? env;

  late final String authUrl;
  late final String baseUrl;
  String? _token;

  SatuSehatService({
    required this.clientId,
    required this.clientSecret,
    required this.organizationId,
    required this.locationId,
    required this.env,
  }) {
    final environment = (env ?? 'production').toLowerCase();
    if (environment == 'development' || environment == 'dev' || environment == 'stg') {
      authUrl = 'https://api-satusehat-stg.dto.kemkes.go.id/oauth2/v1';
      baseUrl = 'https://api-satusehat-stg.dto.kemkes.go.id/fhir-r4/v1';
    } else {
      authUrl = 'https://api-satusehat.kemkes.go.id/oauth2/v1';
      baseUrl = 'https://api-satusehat.kemkes.go.id/fhir-r4/v1';
    }
  }

  bool isConfigured() {
    return clientId != null &&
        clientSecret != null &&
        organizationId != null &&
        locationId != null;
  }

  String? getConfigurationError() {
    if (clientId == null || clientSecret == null || clientId!.isEmpty || clientSecret!.isEmpty) {
      return 'SatuSehat API Client ID/Secret not set';
    }
    if (organizationId == null || organizationId!.isEmpty) {
      return 'SatuSehat Organization ID not set';
    }
    if (locationId == null || locationId!.isEmpty) {
      return 'SatuSehat Location ID not set (Check Practice Location in Profile)';
    }
    return null;
  }

  /// Get OAuth2 Token from SatuSehat
  Future<String?> getToken() async {
    if (_token != null) return _token;

    if (clientId == null || clientSecret == null) {
      throw Exception('SatuSehat API credentials missing');
    }

    try {
      final response = await http.post(
        Uri.parse('$authUrl/accesstoken?grant_type=client_credentials'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId!,
          'client_secret': clientSecret!,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _token = data['access_token']?.toString();
        return _token;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Search patient by NIK to get IHIS ID
  Future<Map<String, dynamic>> getPatientIdByNik(String nik) async {
    var token = await getToken();
    if (token == null) {
      return {'status': false, 'message': 'Failed to obtain SatuSehat token'};
    }

    try {
      var response = await http.get(
        Uri.parse('$baseUrl/Patient?identifier=https://fhir.kemkes.go.id/id/nik|$nik'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      // If token expired or invalid (401), clear token cache and retry once
      if (response.statusCode == 401 || response.body.contains('invalid_token')) {
        _token = null;
        token = await getToken();
        if (token != null) {
          response = await http.get(
            Uri.parse('$baseUrl/Patient?identifier=https://fhir.kemkes.go.id/id/nik|$nik'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data['entry'] != null && (data['entry'] as List).isNotEmpty) {
          final patientId = data['entry'][0]['resource']?['id']?.toString();
          if (patientId != null) {
            return {'status': true, 'id': patientId};
          }
        }
        return {'status': false, 'message': 'Pasien tidak ditemukan di SatuSehat'};
      }
      return {'status': false, 'message': 'Error API SatuSehat: ${response.body}'};
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Send Encounter, Condition, and MedicationRequest
  Future<Map<String, dynamic>> sendEncounterData({
    required String patientId,
    required String doctorId,
    required String patientName,
    required String doctorName,
    required String encounterId,
    required List<dynamic> diagnoses,
    required List<dynamic> prescriptions,
  }) async {
    final configError = getConfigurationError();
    if (configError != null) {
      return {'status': false, 'message': configError};
    }

    var token = await getToken();
    if (token == null) {
      return {'status': false, 'message': 'Failed to obtain SatuSehat token'};
    }

    var headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // 1. Create Encounter
    var encounterResponse = await createEncounter(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: doctorName,
      encounterId: encounterId,
    );

    // If token expired or invalid, clear token cache and retry once
    if (encounterResponse['status'] != true && 
        (encounterResponse['message']?.toString().contains('invalid_token') == true ||
         encounterResponse['message']?.toString().contains('401') == true)) {
      _token = null;
      token = await getToken();
      if (token != null) {
        headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        encounterResponse = await createEncounter(
          headers: headers,
          patientId: patientId,
          patientName: patientName,
          doctorId: doctorId,
          doctorName: doctorName,
          encounterId: encounterId,
        );
      }
    }

    if (encounterResponse['status'] != true) {
      return encounterResponse;
    }

    final ssEncounterId = encounterResponse['data']?['id']?.toString();
    if (ssEncounterId == null) {
      return {'status': false, 'message': 'Invalid Encounter response ID'};
    }

    final results = <String, dynamic>{
      'status': true,
      'encounter_id': ssEncounterId,
      'conditions': [],
      'medications': [],
      'medication_note': null,
    };

    // 2. Create Conditions
    if (diagnoses.isNotEmpty) {
      for (final diag in diagnoses) {
        final condRes = await createCondition(
          headers: headers,
          patientId: patientId,
          patientName: patientName,
          encounterId: ssEncounterId,
          diag: diag,
        );
        results['conditions'].add(condRes);
      }
    }

    // 3. Create MedicationRequest (Prescription)
    if (prescriptions.isNotEmpty) {
      final skippedMeds = <String>[];
      for (final rx in prescriptions) {
        final medRes = await createMedicationRequest(
          headers: headers,
          patientId: patientId,
          patientName: patientName,
          encounterId: ssEncounterId,
          doctorId: doctorId,
          rx: rx,
        );
        if (medRes['status'] == true) {
          results['medications'].add(medRes);
        } else {
          final medName = rx['medicine_name'] ?? rx['name'] ?? rx['namaObat'] ?? 'Obat';
          skippedMeds.add("$medName (${medRes['message'] ?? 'Gagal sync'})");
        }
      }

      if (skippedMeds.isNotEmpty) {
        results['medication_note'] = 'Beberapa obat gagal sinkronisasi: ${skippedMeds.join(', ')}';
      }
    }

    return results;
  }

  Future<Map<String, dynamic>> createEncounter({
    required Map<String, String> headers,
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required String encounterId,
  }) async {
    final now = DateTime.now();
    final arrivedStart = now.subtract(const Duration(minutes: 30)).toUtc().toIso8601String();
    final arrivedEnd = now.subtract(const Duration(minutes: 15)).toUtc().toIso8601String();
    final inProgressStart = now.subtract(const Duration(minutes: 15)).toUtc().toIso8601String();
    final currentStr = now.toUtc().toIso8601String();

    final payload = {
      "resourceType": "Encounter",
      "status": "in-progress",
      "statusHistory": [
        {
          "status": "arrived",
          "period": {
            "start": arrivedStart,
            "end": arrivedEnd,
          }
        },
        {
          "status": "in-progress",
          "period": {
            "start": inProgressStart,
            "end": currentStr,
          }
        }
      ],
      "class": {
        "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        "code": "AMB",
        "display": "ambulatory"
      },
      "subject": {
        "reference": "Patient/$patientId",
        "display": patientName,
      },
      "participant": [
        {
          "type": [
            {
              "coding": [
                {
                  "system": "http://terminology.hl7.org/CodeSystem/v3-ParticipationType",
                  "code": "ATND",
                  "display": "attender"
                }
              ]
            }
          ],
          "individual": {
            "reference": "Practitioner/$doctorId",
            "display": doctorName,
          }
        }
      ],
      "period": {
        "start": inProgressStart,
        "end": currentStr,
      },
      "location": [
        {
          "location": {
            "reference": "Location/$locationId",
            "display": "Ruang Pemeriksaan"
          }
        }
      ],
      "serviceProvider": {
        "reference": "Organization/$organizationId"
      },
      "identifier": [
        {
          "system": "http://sys-ids.kemkes.go.id/encounter/$organizationId",
          "value": encounterId
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Encounter'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': true, 'data': jsonDecode(response.body)};
      }
      return {'status': false, 'message': 'Failed to create Encounter: ${response.body}'};
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<bool> createCondition({
    required Map<String, String> headers,
    required String patientId,
    required String patientName,
    required String encounterId,
    required Map<String, dynamic> diag,
  }) async {
    final payload = {
      "resourceType": "Condition",
      "clinicalStatus": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/condition-clinical",
            "code": "active",
            "display": "Active"
          }
        ]
      },
      "category": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/condition-category",
              "code": "encounter-diagnosis",
              "display": "Encounter Diagnosis"
            }
          ]
        }
      ],
      "code": {
        "coding": [
          {
            "system": "http://hl7.org/fhir/sid/icd-10",
            "code": diag['code'] ?? 'R69',
            "display": diag['description'] ?? diag['label'] ?? 'Unknown and unspecified causes of morbidity'
          }
        ]
      },
      "subject": {
        "reference": "Patient/$patientId",
        "display": patientName,
      },
      "encounter": {
        "reference": "Encounter/$encounterId",
        "display": "Kunjungan $patientName"
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Condition'),
        headers: headers,
        body: jsonEncode(payload),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> createMedicationRequest({
    required Map<String, String> headers,
    required String patientId,
    required String patientName,
    required String encounterId,
    required String doctorId,
    required Map<String, dynamic> rx,
  }) async {
    final medicationName = rx['medicine_name'] ?? rx['name'] ?? rx['namaObat'] ?? 'Obat';
    final kfaCode = rx['kfa_code'];

    if (kfaCode == null) {
      return {'status': false, 'message': 'Kode KFA tidak ditemukan'};
    }

    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final medUuid = [
      values.sublist(0, 4),
      values.sublist(4, 6),
      values.sublist(6, 8),
      values.sublist(8, 10),
      values.sublist(10, 16)
    ].map((bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()).join('-');

    final medicationPayload = {
      "resourceType": "Medication",
      "meta": {
        "profile": ["https://fhir.kemkes.go.id/r4/StructureDefinition/Medication"]
      },
      "identifier": [
        {
          "system": "http://sys-ids.kemkes.go.id/medication/$organizationId",
          "use": "official",
          "value": medUuid,
        }
      ],
      "code": {
        "coding": [
          {
            "system": "http://sys-ids.kemkes.go.id/kfa",
            "code": kfaCode,
            "display": medicationName
          }
        ],
        "text": medicationName
      },
      "status": "active",
      "manufacturer": {
        "reference": "Organization/$organizationId"
      },
      "extension": [
        {
          "url": "https://fhir.kemkes.go.id/r4/StructureDefinition/MedicationType",
          "valueCodeableConcept": {
            "coding": [
              {
                "system": "http://terminology.kemkes.go.id/CodeSystem/medication-type",
                "code": "NC",
                "display": "Non-compound"
              }
            ]
          }
        }
      ],
      "form": {
        "coding": [
          {
            "system": "http://terminology.kemkes.go.id/CodeSystem/medication-form",
            "code": "BS026",
            "display": "Tablet"
          }
        ]
      }
    };

    String medicationId;
    try {
      final medResponse = await http.post(
        Uri.parse('$baseUrl/Medication'),
        headers: headers,
        body: jsonEncode(medicationPayload),
      );

      if (medResponse.statusCode < 200 || medResponse.statusCode >= 300) {
        return {'status': false, 'message': 'Gagal membuat Medication: ${medResponse.body}'};
      }
      medicationId = jsonDecode(medResponse.body)['id']?.toString() ?? '';
    } catch (e) {
      return {'status': false, 'message': 'Medication exception: $e'};
    }

    final reqUuidBytes = List<int>.generate(16, (i) => random.nextInt(256));
    reqUuidBytes[6] = (reqUuidBytes[6] & 0x0f) | 0x40;
    reqUuidBytes[8] = (reqUuidBytes[8] & 0x3f) | 0x80;
    final reqUuid = [
      reqUuidBytes.sublist(0, 4),
      reqUuidBytes.sublist(4, 6),
      reqUuidBytes.sublist(6, 8),
      reqUuidBytes.sublist(8, 10),
      reqUuidBytes.sublist(10, 16)
    ].map((bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()).join('-');

    final requestPayload = {
      "resourceType": "MedicationRequest",
      "identifier": [
        {
          "system": "http://sys-ids.kemkes.go.id/prescription/$organizationId",
          "use": "official",
          "value": reqUuid,
        }
      ],
      "status": "completed",
      "intent": "order",
      "medicationReference": {
        "reference": "Medication/$medicationId",
        "display": medicationName
      },
      "subject": {
        "reference": "Patient/$patientId",
        "display": patientName
      },
      "encounter": {
        "reference": "Encounter/$encounterId"
      },
      "authoredOn": DateTime.now().toUtc().toIso8601String(),
      "requester": {
        "reference": "Practitioner/$doctorId"
      },
      "dosageInstruction": [
        {
          "sequence": 1,
          "text": rx['dosage_instructions'] ?? rx['dosage'] ?? rx['aturan'] ?? 'Sesuai petunjuk dokter'
        }
      ],
      "dispenseRequest": {
        "quantity": {
          "value": double.tryParse(rx['quantity']?.toString() ?? rx['qty']?.toString() ?? '1') ?? 1.0,
          "unit": "TAB",
          "system": "http://terminology.hl7.org/CodeSystem/v3-orderableDrugForm",
          "code": "TAB"
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/MedicationRequest'),
        headers: headers,
        body: jsonEncode(requestPayload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': true, 'data': jsonDecode(response.body)};
      }
      return {'status': false, 'message': 'Gagal membuat MedicationRequest: ${response.body}'};
    } catch (e) {
      return {'status': false, 'message': 'MedicationRequest exception: $e'};
    }
  }

  /// Search KFA products by keyword using SatuSehat KFA v2 API
  Future<Map<String, dynamic>> searchKfaProducts({
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'status': false, 'message': 'Failed to obtain SatuSehat token'};
    }

    final environment = (env ?? 'production').toLowerCase();
    final kfaBaseUrl = (environment == 'development' || environment == 'dev' || environment == 'stg')
        ? 'https://api-satusehat-stg.dto.kemkes.go.id/kfa-v2'
        : 'https://api-satusehat.kemkes.go.id/kfa-v2';

    // 1. Try Direct Call first (works if not on web, or web with disabled CORS)
    try {
      final response = await http.get(
        Uri.parse('$kfaBaseUrl/products/all?keyword=${Uri.encodeComponent(keyword)}&page=$page&size=$size&product_type=farmasi'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'status': true, 'data': data};
      }
      
      // If we got blocked by Cloudflare (403) or other errors, trigger the fallback to Edge Function proxy
      if (response.statusCode == 403 || response.statusCode == 401) {
        throw Exception('API ${response.statusCode}');
      }
      return {'status': false, 'message': 'API Error ${response.statusCode}: ${response.body}'};
    } catch (e) {
      // 2. Fallback: Call Supabase Edge Function to bypass CORS and Geo-Blocking
      try {
        final edgeResponse = await SupabaseService.client.functions.invoke(
          'kfa-search',
          body: {
            'keyword': keyword,
            'token': token,
            'env': environment,
          },
        );

        final data = edgeResponse.data as Map<String, dynamic>?;
        if (data != null && data['status'] == true) {
          return {'status': true, 'data': data['data']};
        }
        return {'status': false, 'message': data?['message']?.toString() ?? 'Gagal mengambil data dari proxy Edge Function'};
      } catch (edgeErr) {
        return {'status': false, 'message': 'Direct call failed ($e) and proxy call failed ($edgeErr)'};
      }
    }
  }
}
