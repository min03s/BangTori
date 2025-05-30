import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/profile_avatar.dart';

class RoomSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 헤더
              _buildHeader(context, authProvider),

              SizedBox(height: 48),

              // 선택 옵션들
              Expanded(
                child: _buildOptions(context),
              ),

              // 하단 로그아웃 버튼
              _buildLogoutButton(context, authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Column(
      children: [
        ProfileAvatar(
          imageUrl: authProvider.user?.profileImage,
          nickname: authProvider.user?.nickname,
          size: 80,
        ),

        SizedBox(height: 16),

        Text(
          '안녕하세요, ${authProvider.user?.nickname}님!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 8),

        Text(
          '어떻게 시작하시겠어요?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 방 생성 옵션
        _buildOptionCard(
          context,
          icon: Icons.add_home,
          title: '새 방 만들기',
          description: '새로운 공동생활 공간을 만들어보세요',
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, '/room/create'),
        ),

        SizedBox(height: 24),

        // 방 참여 옵션
        _buildOptionCard(
          context,
          icon: Icons.meeting_room,
          title: '기존 방 참여하기',
          description: '초대 코드로 기존 방에 참여하세요',
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, '/room/join'),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String description,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),

              SizedBox(height: 16),

              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8),

              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return Column(
      children: [
        Divider(),

        SizedBox(height: 16),

        Row(
          children: [
            ProfileAvatar(
              imageUrl: authProvider.user?.profileImage,
              size: 40,
            ),

            SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProvider.user?.nickname ?? '',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    authProvider.user?.email ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            TextButton(
              onPressed: () => _showLogoutDialog(context, authProvider),
              child: Text('로그아웃'),
            ),
          ],
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('로그아웃'),
        content: Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}