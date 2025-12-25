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
    final timestamp = DateTime.now().toIso8601String();
    final stopwatch = Stopwatch()..start();

    print('\n' + '=' * 80);
    print('🚀 API REQUEST - $timestamp');
    print('=' * 80);
    print('🎯 Action: $action');
    print('🌐 URL: $uri');
    print('� Headers:');
    print('   Content-Type: application/json');
    print('   Accept: application/json');
    print('📤 Request Body (JSON):');
    print('   ${json.encode(data)}');
    print('📤 Request Body (Pretty):');
    final prettyRequest = JsonEncoder.withIndent('  ').convert(data);
    prettyRequest.split('\n').forEach((line) => print('   $line'));
    print('-' * 80);

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;

      print('📥 RESPONSE RECEIVED');
      print('⏱️  Duration: ${duration}ms');
      print('📊 Status Code: ${response.statusCode}');
      print('� Response Headers:');
      response.headers.forEach((key, value) {
        print('   $key: $value');
      });
      print('📥 Response Body (Raw):');
      print('   ${response.body}');

      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(response.body);
          print('📥 Response Body (Parsed JSON):');
          final prettyResponse = JsonEncoder.withIndent('  ').convert(decoded);
          prettyResponse.split('\n').forEach((line) => print('   $line'));
          print('✅ SUCCESS - Request completed in ${duration}ms');
          print('=' * 80 + '\n');
          return decoded;
        } catch (e) {
          print('⚠️  JSON Parse Error: $e');
          print('🔥 FAILED - Invalid JSON response');
          print('=' * 80 + '\n');
          throw Exception('Error al parsear JSON: $e');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('📄 Error Body: ${response.body}');
        print('🔥 FAILED - HTTP ${response.statusCode}');
        print('=' * 80 + '\n');
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      print('💥 EXCEPTION OCCURRED');
      print('⏱️  Failed after: ${stopwatch.elapsedMilliseconds}ms');
      print('🔥 Error Type: ${e.runtimeType}');
      print('🔥 Error Message: $e');
      print('📚 Stack Trace:');
      stackTrace.toString().split('\n').take(5).forEach((line) {
        print('   $line');
      });
      print('🔥 FAILED - Exception thrown');
      print('=' * 80 + '\n');
      rethrow;
    }
  }
}
