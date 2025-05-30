import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;

  // HTTP 클라이언트 설정
  static final http.Client _client = http.Client();

  // 공통 헤더
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // 사용자 생성
  static Future<Map<String, dynamic>> createUser(String nickname) async {
    try {
      print('🔵 API: 사용자 생성 시작 - $nickname');

      final response = await _client.post(
        Uri.parse('$baseUrl/users'),
        headers: _headers,
        body: json.encode({'nickname': nickname}),
      ).timeout(Duration(seconds: 10));

      print('🔵 API: 사용자 생성 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 사용자 생성 오류 - $e');
      throw ApiException('사용자 생성 중 오류가 발생했습니다: $e');
    }
  }

  // 방 생성
  static Future<Map<String, dynamic>> createRoom({
    required String name,
    required String description,
    required String ownerId,
  }) async {
    try {
      print('🟢 API: 방 생성 시작 - $name');

      final response = await _client.post(
        Uri.parse('$baseUrl/rooms'),
        headers: _headers,
        body: json.encode({
          'name': name,
          'description': description,
          'ownerId': ownerId,
        }),
      ).timeout(Duration(seconds: 10));

      print('🟢 API: 방 생성 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 방 생성 오류 - $e');
      throw ApiException('방 생성 중 오류가 발생했습니다: $e');
    }
  }

  // 방 참여
  static Future<Map<String, dynamic>> joinRoom({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      print('🟡 API: 방 참여 시작 - $inviteCode');

      final response = await _client.post(
        Uri.parse('$baseUrl/rooms/join'),
        headers: _headers,
        body: json.encode({
          'inviteCode': inviteCode.toUpperCase(),
          'userId': userId,
        }),
      ).timeout(Duration(seconds: 10));

      print('🟡 API: 방 참여 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 방 참여 오류 - $e');
      throw ApiException('방 참여 중 오류가 발생했습니다: $e');
    }
  }

  // 초대 코드로 방 조회
  static Future<Map<String, dynamic>> getRoomByInviteCode(String inviteCode) async {
    try {
      print('🔍 API: 방 조회 시작 - $inviteCode');

      final response = await _client.get(
        Uri.parse('$baseUrl/rooms/invite/${inviteCode.toUpperCase()}'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      print('🔍 API: 방 조회 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 방 조회 오류 - $e');
      throw ApiException('방 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 사용자의 방 목록 조회
  static Future<Map<String, dynamic>> getUserRooms(String userId) async {
    try {
      print('📋 API: 사용자 방 목록 조회 - $userId');

      final response = await _client.get(
        Uri.parse('$baseUrl/rooms/user/$userId'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      print('📋 API: 방 목록 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 방 목록 조회 오류 - $e');
      throw ApiException('방 목록 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 방에서 나가기
  static Future<Map<String, dynamic>> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      print('🚪 API: 방 나가기 - $roomId');

      final response = await _client.delete(
        Uri.parse('$baseUrl/rooms/$roomId/leave/$userId'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      print('🚪 API: 방 나가기 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 방 나가기 오류 - $e');
      throw ApiException('방 나가기 중 오류가 발생했습니다: $e');
    }
  }

  // 방 정보 조회
  static Future<Map<String, dynamic>> getRoom(String roomId) async {
    try {
      print('🏠 API: 방 정보 조회 - $roomId');

      final response = await _client.get(
        Uri.parse('$baseUrl/rooms/$roomId'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      print('🏠 API: 방 정보 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 방 정보 조회 오류 - $e');
      throw ApiException('방 정보 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 사용자 정보 조회
  static Future<Map<String, dynamic>> getUser(String userId) async {
    try {
      print('👤 API: 사용자 정보 조회 - $userId');

      final response = await _client.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      print('👤 API: 사용자 정보 응답 - ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ API: 사용자 정보 조회 오류 - $e');
      throw ApiException('사용자 정보 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 연결 상태 확인
  static Future<bool> checkConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl.replaceAll('/api', '')}/health'),
        headers: _headers,
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ 서버 연결 확인 실패: $e');
      return false;
    }
  }

  // 응답 처리
  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('📨 응답 코드: ${response.statusCode}');
    print('📨 응답 본문: ${response.body}');

    if (response.body.isEmpty) {
      throw ApiException('서버에서 빈 응답을 받았습니다');
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(response.body);
    } catch (e) {
      throw ApiException('서버 응답을 파싱할 수 없습니다');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      final message = data['message'] ?? '알 수 없는 오류가 발생했습니다';
      throw ApiException(message);
    }
  }

  // 클라이언트 정리
  static void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}