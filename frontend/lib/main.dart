import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/room/room_selection_screen.dart';
import 'config/env.dart';
import 'utils/theme.dart';

void main() {
  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);

  runApp(BangToriApp());
}

class BangToriApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: '방토리',
        theme: AppTheme.lightTheme,
        home: AuthWrapper(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/profile-setup': (context) => ProfileSetupScreen(),
          '/room-selection': (context) => RoomSelectionScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('로딩 중...'),
                ],
              ),
            ),
          );
        }

        if (!authProvider.isAuthenticated) {
          return LoginScreen();
        }

        if (authProvider.user?.currentRoom == null) {
          return RoomSelectionScreen();
        }

        // TODO: HomeScreen으로 이동
        return Scaffold(
          body: Center(
            child: Text('홈 화면 (구현 예정)'),
          ),
        );
      },
    );
  }
}