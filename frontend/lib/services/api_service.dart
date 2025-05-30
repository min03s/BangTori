class ApiService {
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    // 임시 구현 - 실제로는 HTTP 요청
    await Future.delayed(Duration(seconds: 1));

    if (endpoint.contains('/auth/')) {
      return {
        'token': 'dummy_token',
        'user': {
          'id': '1',
          'nickname': '테스트 사용자',
          'email': 'test@example.com',
          'profileImage': null,
          'currentRoom': null,
        }
      };
    }

    return {'message': 'success'};
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    await Future.delayed(Duration(seconds: 1));
    return {
      'user': {
        'id': '1',
        'nickname': '테스트 사용자',
        'email': 'test@example.com',
        'profileImage': null,
        'currentRoom': null,
      }
    };
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    await Future.delayed(Duration(seconds: 1));
    return {
      'user': {
        'id': '1',
        'nickname': data['nickname'],
        'email': 'test@example.com',
        'profileImage': data['profileImage'],
        'currentRoom': null,
      }
    };
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