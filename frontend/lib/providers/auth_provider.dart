import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;

  // 초기화
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final user = await AuthService.tryAutoLogin();
      if (user != null) {
        _user = user;
        _isAuthenticated = true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Google 로그인
  Future<bool> signInWithGoogle() async {
    return await _performLogin(() => AuthService.signInWithGoogle());
  }

  // 카카오 로그인
  Future<bool> signInWithKakao() async {
    return await _performLogin(() => AuthService.signInWithKakao());
  }

  // 네이버 로그인
  Future<bool> signInWithNaver() async {
    return await _performLogin(() => AuthService.signInWithNaver());
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await AuthService.signOut();
      _user = null;
      _isAuthenticated = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 프로필 업데이트
  Future<bool> updateProfile({
    required String nickname,
    String? profileImage,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final updatedUser = await AuthService.updateProfile(
        nickname: nickname,
        profileImage: profileImage,
      );

      _user = updatedUser;
      _setLoading(false);
      return true;

    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // 공통 로그인 처리
  Future<bool> _performLogin(Future<User?> Function() loginFunction) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await loginFunction();
      if (user != null) {
        _user = user;
        _isAuthenticated = true;
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        return false;
      }

    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}