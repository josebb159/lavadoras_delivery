import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<Map<String, dynamic>> post(
    String action,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('${AppConstants.baseUrl}?action=$action');

    print(
      '----------------------------------------------------------------------',
    );
    print('📡 Request POST: $uri');
    print('📤 Body: ${json.encode(data)}');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');
      print(
        '----------------------------------------------------------------------',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error en ApiService ($action): $e');
      rethrow;
    }
  }
}
