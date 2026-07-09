import 'dart:convert';
import 'package:http/http.dart' as http;

class Region {
  final String id;
  final String name;

  Region({required this.id, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Region && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class LocationService {
  static const String _baseUrl = 'https://www.emsifa.com/api-wilayah-indonesia/api';

  static Future<List<Region>> getProvinces() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/provinces.json'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Region.fromJson(json)).toList();
      }
      throw Exception('Failed to load provinces');
    } catch (e) {
      print('Error loading provinces: $e');
      return [];
    }
  }

  static Future<List<Region>> getRegencies(String provinceId) async {
    if (provinceId.isEmpty) return [];
    try {
      final response = await http.get(Uri.parse('$_baseUrl/regencies/$provinceId.json'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Region.fromJson(json)).toList();
      }
      throw Exception('Failed to load regencies');
    } catch (e) {
      print('Error loading regencies for province $provinceId: $e');
      return [];
    }
  }

  static Future<List<Region>> getDistricts(String regencyId) async {
    if (regencyId.isEmpty) return [];
    try {
      final response = await http.get(Uri.parse('$_baseUrl/districts/$regencyId.json'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Region.fromJson(json)).toList();
      }
      throw Exception('Failed to load districts');
    } catch (e) {
      print('Error loading districts for regency $regencyId: $e');
      return [];
    }
  }

  static Future<List<Region>> getVillages(String districtId) async {
    if (districtId.isEmpty) return [];
    try {
      final response = await http.get(Uri.parse('$_baseUrl/villages/$districtId.json'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Region.fromJson(json)).toList();
      }
      throw Exception('Failed to load villages');
    } catch (e) {
      print('Error loading villages for district $districtId: $e');
      return [];
    }
  }
}
