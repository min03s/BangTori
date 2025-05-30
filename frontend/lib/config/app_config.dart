class AppConfig {
  // 개발 환경
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // 안드로이드 에뮬레이터용
  // static const String baseUrl = 'http://localhost:5000/api'; // iOS 시뮬레이터용
  // static const String baseUrl = 'http://192.168.1.100:5000/api'; // 실제 디바이스용 (IP 주소 확인 필요)

  static const String socketUrl = 'http://10.0.2.2:5000';

// 프로덕션 환경
// static const String baseUrl = 'https://your-server.com/api';
// static const String socketUrl = 'https://your-server.com';
}