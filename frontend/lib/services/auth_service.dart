import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart' as AppUser; // alias 사용
import '../config/env.dart';
import 'api_service.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Google 로그인
  static Future<AppUser.User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;

      // 백엔드에 토큰 전송
      final response = await ApiService.post('/auth/google', {
        'accessToken': auth.accessToken,
        'idToken': auth.idToken,
      });

      return await _handleAuthSuccess(response);

    } catch (e) {
      throw AuthException('Google 로그인에 실패했습니다: $e');
    }
  }

  // 카카오 로그인
  static Future<AppUser.User?> signInWithKakao() async {
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 백엔드에 토큰 전송
      final response = await ApiService.post('/auth/kakao', {
        'accessToken': token.accessToken,
      });

      return await _handleAuthSuccess(response);

    } catch (e) {
      throw AuthException('카카오 로그인에 실패했습니다: $e');
    }
  }

  // 네이버 로그인 (임시 비활성화)
  static Future<AppUser.User?> signInWithNaver() async {
    try {
      throw AuthException('네이버 로그인은 현재 준비 중입니다');
    } catch (e) {
      throw AuthException('네이버 로그인에 실패했습니다: $e');
    }
  }

  // 자동 로그인
  static Future<AppUser.User?> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        final response = await ApiService.get('/auth/me');
        return AppUser.User.fromJson(response['user']);
      }

      return null;
    } catch (e) {
      await signOut();
      return null;
    }
  }

  // 로그아웃
  static Future<void> signOut() async {
    try {
      // 소셜 로그인 로그아웃
      await _googleSignIn.signOut();
      await UserApi.instance.logout();
      // 네이버 로그인 제거됨

      // 로컬 토큰 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');

    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
    }
  }

  // 프로필 업데이트
  static Future<AppUser.User> updateProfile({
    required String nickname,
    String? profileImage,
  }) async {
    try {
      final response = await ApiService.put('/users/profile', {
        'nickname': nickname,
        if (profileImage != null) 'profileImage': profileImage,
      });

      return AppUser.User.fromJson(response['user']);
    } catch (e) {
      throw ApiException('프로필 업데이트에 실패했습니다: $e');
    }
  }

  // 인증 성공 처리
  static Future<AppUser.User> _handleAuthSuccess(Map<String, dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', response['token']);

    return AppUser.User.fromJson(response['user']);
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}