import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET 요청
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('네트워크 오류가 발생했습니다: $e');
    }
  }

  // POST 요청
  static Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> data
      ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('네트워크 오류가 발생했습니다: $e');
    }
  }

  // PUT 요청
  static Future<Map<String, dynamic>> put(
      String endpoint,
      Map<String, dynamic> data
      ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('네트워크 오류가 발생했습니다: $e');
    }
  }

  // DELETE 요청
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('네트워크 오류가 발생했습니다: $e');
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw AuthException('인증이 필요합니다');
    } else if (response.statusCode == 403) {
      throw AuthException('권한이 없습니다');
    } else if (response.statusCode == 404) {
      throw ApiException('요청한 리소스를 찾을 수 없습니다');
    } else {
      final errorData = json.decode(response.body);
      throw ApiException(errorData['message'] ?? '서버 오류가 발생했습니다');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}