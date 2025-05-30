import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 및 타이틀
                  _buildHeader(context),

                  SizedBox(height: 48),

                  // 소셜 로그인 버튼들
                  _buildSocialLoginButtons(context, authProvider),

                  SizedBox(height: 24),

                  // 오류 메시지
                  if (authProvider.error != null)
                    _buildErrorMessage(context, authProvider),

                  SizedBox(height: 24),

                  // 서비스 이용약관
                  _buildTermsText(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            Icons.home_work,
            size: 60,
            color: Theme.of(context).primaryColor,
          ),
        ),

        SizedBox(height: 24),

        Text(
          '방토리',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),

        SizedBox(height: 8),

        Text(
          '공동 생활 관리 서비스',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),

        SizedBox(height: 16),

        Text(
          '소셜 계정으로 간편하게 시작하세요',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons(BuildContext context, AuthProvider authProvider) {
    return Column(
      children: [
        // Google 로그인
        CustomButton(
          text: 'Google로 시작하기',
          icon: Icons.g_mobiledata,
          backgroundColor: Colors.white,
          textColor: Colors.black87,
          borderColor: Colors.grey[300],
          isLoading: authProvider.isLoading,
          onPressed: () async {
            final success = await authProvider.signInWithGoogle();
            if (success) {
              Navigator.pushReplacementNamed(context, '/profile-setup');
            }
          },
        ),

        SizedBox(height: 16),

        // 카카오 로그인
        CustomButton(
          text: '카카오로 시작하기',
          backgroundColor: Color(0xFFFFE812),
          textColor: Colors.black87,
          isLoading: authProvider.isLoading,
          onPressed: () async {
            final success = await authProvider.signInWithKakao();
            if (success) {
              Navigator.pushReplacementNamed(context, '/profile-setup');
            }
          },
        ),

        SizedBox(height: 16),

        // 네이버 로그인 (임시 비활성화)
        CustomButton(
          text: '네이버로 시작하기 (준비중)',
          backgroundColor: Colors.grey[300],
          textColor: Colors.grey[600],
          onPressed: null, // 비활성화
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              authProvider.error!,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
          IconButton(
            onPressed: () => authProvider.clearError(),
            icon: Icon(Icons.close, color: Colors.red, size: 18),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsText(BuildContext context) {
    return Text(
      '로그인 시 이용약관 및 개인정보처리방침에 동의한 것으로 간주됩니다',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey[500],
      ),
      textAlign: TextAlign.center,
    );
  }
}