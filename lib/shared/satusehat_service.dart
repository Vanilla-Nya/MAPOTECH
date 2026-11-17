import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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

  /// Universal FHIR caller that routes through Supabase Edge Function to avoid browser CORS issues
  Future<Map<String, dynamic>> _callFhirProxy({
    required String method,
    required String endpoint,
    required String token,
    dynamic payload,
  }) async {
    final environment = (env ?? 'production').toLowerCase();

    // 1. Try Supabase Edge Function proxy first (Bypasses browser CORS & Geo-blocking)
    try {
      final edgeResponse = await SupabaseService.client.functions.invoke(
        'satusehat-proxy',
        body: {
          'method': method,
          'endpoint': endpoint,
          'token': token,
          'env': environment,
          'payload': ?payload,
        },
      );

      final data = edgeResponse.data as Map<String, dynamic>?;
      if (data != null && data['status'] == true) {
        return {'status': true, 'data': data['data']};
      } else if (data != null) {
        return {
          'status': false,
          'message': data['message'] ?? 'Error dari proxy SatuSehat',
          'statusCode': data['statusCode'],
        };
      }
    } catch (e) {
      debugPrint('SatuSehat proxy invoke fallback: $e');
    }

    // 2. Direct HTTP call (Fallback for Native Android / iOS / Desktop where CORS is not enforced)
    try {
      final clean = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$baseUrl$clean');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      http.Response response;
      if (method.toUpperCase() == 'GET') {
        response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      } else {
        response = await http.post(
          uri,
          headers: headers,
          body: payload != null ? jsonEncode(payload) : null,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': true, 'data': jsonDecode(response.body)};
      }
      return {
        'status': false,
        'message': 'API Error ${response.statusCode}: ${response.body}',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Search patient by NIK to get IHIS ID
  Future<Map<String, dynamic>> getPatientIdByNik(String nik) async {
    var token = await getToken();
    if (token == null) {
      return {'status': false, 'message': 'Failed to obtain SatuSehat token'};
    }

    var res = await _callFhirProxy(
      method: 'GET',
      endpoint: '/Patient?identifier=https://fhir.kemkes.go.id/id/nik|$nik',
      token: token,
    );

    // If token expired or invalid (401), clear token cache and retry once
    if (res['status'] != true &&
        (res['message']?.toString().contains('401') == true ||
            res['message']?.toString().contains('invalid_token') == true)) {
      _token = null;
      token = await getToken();
      if (token != null) {
        res = await _callFhirProxy(
          method: 'GET',
          endpoint: '/Patient?identifier=https://fhir.kemkes.go.id/id/nik|$nik',
          token: token,
        );
      }
    }

    if (res['status'] == true) {
      final data = res['data'];
      if (data != null && data['entry'] != null && (data['entry'] as List).isNotEmpty) {
        final patientId = data['entry'][0]['resource']?['id']?.toString();
        if (patientId != null) {
          return {'status': true, 'id': patientId};
        }
      }
      return {'status': false, 'message': 'Pasien tidak ditemukan di SatuSehat'};
    }
    return {'status': false, 'message': res['message'] ?? 'Gagal mencari pasien'};
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

    final token = _token ?? headers['Authorization']?.replaceAll('Bearer ', '').trim() ?? '';
    final res = await _callFhirProxy(
      method: 'POST',
      endpoint: '/Encounter',
      token: token,
      payload: payload,
    );

    if (res['status'] == true) {
      return {'status': true, 'data': res['data']};
    }
    return {'status': false, 'message': 'Failed to create Encounter: ${res['message']}'};
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

    final token = _token ?? headers['Authorization']?.replaceAll('Bearer ', '').trim() ?? '';
    final res = await _callFhirProxy(
      method: 'POST',
      endpoint: '/Condition',
      token: token,
      payload: payload,
    );
    return res['status'] == true;
  }

  /// Create Observation for vital-signs / antropometri (LOINC) in SatuSehat FHIR R4
  Future<Map<String, dynamic>> createObservation({
    required Map<String, String> headers,
    required String patientId,
    required String patientName,
    required String encounterId,
    required String loincCode,
    required String loincDisplay,
    required double value,
    required String unit,
    String? practitionerId,
    String? practitionerName,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      "resourceType": "Observation",
      "status": "final",
      "category": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/observation-category",
              "code": "vital-signs",
              "display": "Vital Signs"
            }
          ]
        }
      ],
      "code": {
        "coding": [
          {
            "system": "http://loinc.org",
            "code": loincCode,
            "display": loincDisplay
          }
        ]
      },
      "subject": {
        "reference": "Patient/$patientId",
        "display": patientName,
      },
      "encounter": {
        "reference": "Encounter/$encounterId",
        "display": "Pemeriksaan Antropometri Balita $patientName"
      },
      "effectiveDateTime": now,
      "issued": now,
      if (practitionerId != null)
        "performer": [
          {
            "reference": "Practitioner/$practitionerId",
            "display": practitionerName ?? "Petugas Kesehatan"
          }
        ],
      "valueQuantity": {
        "value": value,
        "unit": unit,
        "system": "http://unitsofmeasure.org",
        "code": unit
      }
    };

    final token = _token ?? headers['Authorization']?.replaceAll('Bearer ', '').trim() ?? '';
    final res = await _callFhirProxy(
      method: 'POST',
      endpoint: '/Observation',
      token: token,
      payload: payload,
    );

    if (res['status'] == true) {
      return {'status': true, 'id': res['data']?['id'], 'data': res['data']};
    }
    return {'status': false, 'message': res['message'] ?? 'Gagal membuat Observation'};
  }

  /// Helper untuk mengirim seluruh paket observasi antropometri (BB, PB/TB, LiLA, LK, LP) ke SatuSehat
  Future<Map<String, dynamic>> sendAnthropometryData({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required String encounterId,
    required double weightKg,
    required double heightCm,
    required bool isRecumbent,
    double? headCircumferenceCm,
    double? lilaCm,
    double? waistCm,
    String? diagnosisCode,
    String? diagnosisDesc,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'status': false, 'message': 'Gagal mendapatkan token SatuSehat'};
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final results = <String, dynamic>{
      'status': true,
      'observations': <Map<String, dynamic>>[],
    };

    // 1. Berat Badan (LOINC 29463-7)
    final bbRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: '29463-7',
      loincDisplay: 'Body weight',
      value: weightKg,
      unit: 'kg',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'Berat Badan', 'result': bbRes});

    // 2. Panjang / Tinggi Badan (LOINC 8306-3 lying / 8302-2 standing)
    final tbCode = isRecumbent ? '8306-3' : '8302-2';
    final tbDisplay = isRecumbent ? 'Body height --lying' : 'Body height';
    final tbRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: tbCode,
      loincDisplay: tbDisplay,
      value: heightCm,
      unit: 'cm',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'Panjang/Tinggi Badan', 'result': tbRes});

    // 3. Lingkar Kepala (LOINC 9843-4) jika ada
    if (headCircumferenceCm != null && headCircumferenceCm > 0) {
      final lkRes = await createObservation(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        loincCode: '9843-4',
        loincDisplay: 'Head Occipital-frontal circumference',
        value: headCircumferenceCm,
        unit: 'cm',
        practitionerId: doctorId,
        practitionerName: doctorName,
      );
      results['observations'].add({'name': 'Lingkar Kepala', 'result': lkRes});
    }

    // 4. LiLA (LOINC 56072-2) jika ada
    if (lilaCm != null && lilaCm > 0) {
      final lilaRes = await createObservation(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        loincCode: '56072-2',
        loincDisplay: 'Circumference Mid upper arm',
        value: lilaCm,
        unit: 'cm',
        practitionerId: doctorId,
        practitionerName: doctorName,
      );
      results['observations'].add({'name': 'LiLA', 'result': lilaRes});
    }

    // 5. Lingkar Perut (LOINC 8280-0) jika ada
    if (waistCm != null && waistCm > 0) {
      final lpRes = await createObservation(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        loincCode: '8280-0',
        loincDisplay: 'Waist Circumference at umbilicus',
        value: waistCm,
        unit: 'cm',
        practitionerId: doctorId,
        practitionerName: doctorName,
      );
      results['observations'].add({'name': 'Lingkar Perut', 'result': lpRes});
    }

    // 6. Condition Diagnosis ICD-10 (stunting/gizi kurang/sehat)
    if (diagnosisCode != null && diagnosisCode.isNotEmpty) {
      await createCondition(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        diag: {
          'code': diagnosisCode,
          'description': diagnosisDesc ?? 'Status Pertumbuhan dan Gizi Balita',
        },
      );
    }

    return results;
  }

  /// Helper untuk mengirim paket data Antenatal Care (ANC 10T) ke SATUSEHAT RME
  Future<Map<String, dynamic>> sendAntenatalCareData({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required String encounterId,
    required double weightKg,
    required double heightCm,
    required double lilaCm,
    required double sistoleMmHg,
    required double diastoleMmHg,
    double? tfuCm,
    double? djjBpm,
    double? hbGdl,
    List<Map<String, String>>? diagnosisList,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'status': false, 'message': 'Gagal mendapatkan token SatuSehat'};
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final results = <String, dynamic>{
      'status': true,
      'observations': <Map<String, dynamic>>[],
    };

    // 1. T1: Berat Badan (LOINC 29463-7) & Tinggi Badan (LOINC 8302-2)
    final bbRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: '29463-7',
      loincDisplay: 'Body weight',
      value: weightKg,
      unit: 'kg',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'Berat Badan', 'result': bbRes});

    final tbRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: '8302-2',
      loincDisplay: 'Body height',
      value: heightCm,
      unit: 'cm',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'Tinggi Badan', 'result': tbRes});

    // 2. T2: Tekanan Darah (Sistole 8480-6 & Diastole 8462-4)
    final sisRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: '8480-6',
      loincDisplay: 'Systolic blood pressure',
      value: sistoleMmHg,
      unit: 'mm[Hg]',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'Sistole', 'result': sisRes});

    final diaRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: '8462-4',
      loincDisplay: 'Diastolic blood pressure',
      value: diastoleMmHg,
      unit: 'mm[Hg]',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'Diastole', 'result': diaRes});

    // 3. T3: LiLA (LOINC 56072-2)
    final lilaRes = await createObservation(
      headers: headers,
      patientId: patientId,
      patientName: patientName,
      encounterId: encounterId,
      loincCode: '56072-2',
      loincDisplay: 'Circumference Mid upper arm',
      value: lilaCm,
      unit: 'cm',
      practitionerId: doctorId,
      practitionerName: doctorName,
    );
    results['observations'].add({'name': 'LiLA Ibu Hamil', 'result': lilaRes});

    // 4. T4: TFU (LOINC 11881-0) jika ada
    if (tfuCm != null && tfuCm > 0) {
      final tfuRes = await createObservation(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        loincCode: '11881-0',
        loincDisplay: 'Uterus Fundal height',
        value: tfuCm,
        unit: 'cm',
        practitionerId: doctorId,
        practitionerName: doctorName,
      );
      results['observations'].add({'name': 'Tinggi Fundus Uteri', 'result': tfuRes});
    }

    // 5. T5: DJJ (LOINC 55283-6) jika ada
    if (djjBpm != null && djjBpm > 0) {
      final djjRes = await createObservation(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        loincCode: '55283-6',
        loincDisplay: 'Fetal Heart rate',
        value: djjBpm,
        unit: '{beats}/min',
        practitionerId: doctorId,
        practitionerName: doctorName,
      );
      results['observations'].add({'name': 'Denyut Jantung Janin', 'result': djjRes});
    }

    // 6. T8: Hb (LOINC 718-7) jika ada
    if (hbGdl != null && hbGdl > 0) {
      final hbRes = await createObservation(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        encounterId: encounterId,
        loincCode: '718-7',
        loincDisplay: 'Hemoglobin [Mass/volume] in Blood',
        value: hbGdl,
        unit: 'g/dL',
        practitionerId: doctorId,
        practitionerName: doctorName,
      );
      results['observations'].add({'name': 'Kadar Hemoglobin', 'result': hbRes});
    }

    // 7. Conditions / Diagnosa Maternal
    if (diagnosisList != null && diagnosisList.isNotEmpty) {
      for (final diag in diagnosisList) {
        await createCondition(
          headers: headers,
          patientId: patientId,
          patientName: patientName,
          encounterId: encounterId,
          diag: diag,
        );
      }
    }

    return results;
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
    final token = _token ?? headers['Authorization']?.replaceAll('Bearer ', '').trim() ?? '';
    final medResponse = await _callFhirProxy(
      method: 'POST',
      endpoint: '/Medication',
      token: token,
      payload: medicationPayload,
    );

    if (medResponse['status'] != true) {
      return {'status': false, 'message': 'Gagal membuat Medication: ${medResponse['message']}'};
    }
    medicationId = medResponse['data']?['id']?.toString() ?? '';

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

    final response = await _callFhirProxy(
      method: 'POST',
      endpoint: '/MedicationRequest',
      token: token,
      payload: requestPayload,
    );

    if (response['status'] == true) {
      return {'status': true, 'data': response['data']};
    }
    return {'status': false, 'message': 'Gagal membuat MedicationRequest: ${response['message']}'};
  }

  /// Search KFA products by keyword using SatuSehat KFA v2 API
  Future<Map<String, dynamic>> searchKfaProducts({
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    var token = await getToken();
    if (token == null) {
      return _getMockKfaFallback(keyword);
    }

    final environment = (env ?? 'production').toLowerCase();
    final kfaBaseUrl = (environment == 'development' || environment == 'dev' || environment == 'stg')
        ? 'https://api-satusehat-stg.dto.kemkes.go.id/kfa-v2'
        : 'https://api-satusehat.kemkes.go.id/kfa-v2';

    // 1. Try Direct Call first
    try {
      var response = await http.get(
        Uri.parse('$kfaBaseUrl/products/all?keyword=${Uri.encodeComponent(keyword)}&page=$page&size=$size&product_type=farmasi'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 401) {
        _token = null;
        token = await getToken();
        if (token != null) {
          response = await http.get(
            Uri.parse('$kfaBaseUrl/products/all?keyword=${Uri.encodeComponent(keyword)}&page=$page&size=$size&product_type=farmasi'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'status': true, 'data': data};
      }

      if (response.statusCode == 403 || response.statusCode == 401) {
        throw Exception('API $response.statusCode');
      }
      return {'status': false, 'message': 'API Error $response.statusCode: $response.body'};
    } catch (e) {
      // 2. Fallback: Call Supabase Edge Function to bypass CORS and Cloudflare
      try {
        final edgeResponse = await SupabaseService.client.functions.invoke(
          'kfa-search',
          body: {
            'keyword': keyword,
            'token': token,
            'env': environment,
            'page': page,
            'size': size,
          },
        );

        final data = edgeResponse.data as Map<String, dynamic>?;
        if (data != null && data['status'] == true) {
          return {'status': true, 'data': data['data']};
        }
        return _getMockKfaFallback(keyword);
      } catch (_) {
        // 3. Fallback: Local curated KFA catalog for demo / presentation
        return _getMockKfaFallback(keyword);
      }
    }
  }

  /// Curated KFA items for presentation / offline demo resilience
  Map<String, dynamic> _getMockKfaFallback(String keyword) {
    final lower = keyword.toLowerCase().trim();
    final allProducts = [
      {'name': 'Paracetamol 500 mg Tablet', 'kfa_code': '93000001', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Amoxicillin 500 mg Kapsul', 'kfa_code': '93000002', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Kapsul'}},
      {'name': 'Asam Mefenamat 500 mg Kaplet', 'kfa_code': '93000003', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Kaplet'}},
      {'name': 'Ibuprofen 400 mg Tablet', 'kfa_code': '93000004', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Cetirizine 10 mg Tablet', 'kfa_code': '93000005', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Omeprazole 20 mg Kapsul', 'kfa_code': '93000006', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Kapsul'}},
      {'name': 'Cefixime 100 mg Kapsul', 'kfa_code': '93000007', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Kapsul'}},
      {'name': 'Metformin 500 mg Tablet', 'kfa_code': '93000008', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Amlodipine 5 mg Tablet', 'kfa_code': '93000009', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Amlodipine 10 mg Tablet', 'kfa_code': '93000010', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Vitamin C 500 mg Tablet', 'kfa_code': '93000011', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Dexamethasone 0.5 mg Tablet', 'kfa_code': '93000012', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Antasida Doen Tablet Kunyah', 'kfa_code': '93000013', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Salbutamol 2 mg Tablet', 'kfa_code': '93000014', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
      {'name': 'Ciprofloxacin 500 mg Tablet', 'kfa_code': '93000015', 'farmalkes_type': {'name': 'Generik'}, 'uom': {'name': 'Tablet'}},
    ];

    final matched = allProducts.where((p) => p['name']!.toString().toLowerCase().contains(lower)).toList();
    return {
      'status': true,
      'data': {
        'items': {
          'data': matched.isNotEmpty ? matched : allProducts.take(6).toList(),
        }
      }
    };
  }
}