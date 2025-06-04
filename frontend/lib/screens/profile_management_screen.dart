// frontend/lib/screens/profile_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';

class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() => _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  String _selectedProfileImage = '/images/profile1.png';

  // 제공되는 6개의 프로필 이미지
  final List<String> _profileImages = [
    '/images/profile1.png',
    '/images/profile2.png',
    '/images/profile3.png',
    '/images/profile4.png',
    '/images/profile5.png',
    '/images/profile6.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadUserProfile();

    setState(() {
      _nicknameController.text = appState.currentUserProfile?.nickname ?? '';
      _selectedProfileImage = appState.currentUserProfile?.profileImageUrl ?? '/images/profile1.png';
    });
  }

  Future<void> _updateProfile() async {
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await appState.updateUserProfile(
        nickname: nickname,
        profileImageUrl: _selectedProfileImage,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 수정되었습니다.'),
          backgroundColor: Colors.lightGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('프로필 수정 실패: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildProfileImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프로필 색상',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        // 현재 선택된 프로필 색상 미리보기
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: _getProfileColor(_selectedProfileImage),
                  child: Icon(
                    Icons.face,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              // 색상 선택 버튼
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showColorPickerDialog,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFA2E55),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.color_lens_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 안내 텍스트
        Center(
          child: Text(
            '색상 버튼을 눌러 프로필 색상을 변경하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

// 색상 선택 다이얼로그 메서드
  void _showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '프로필 색상 선택',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _profileImages.map((imageUrl) {
                final isSelected = imageUrl == _selectedProfileImage;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProfileImage = imageUrl;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getProfileColor(imageUrl),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFA2E55) : Colors.grey[300]!,
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                        if (isSelected)
                          BoxShadow(
                            color: const Color(0xFFFA2E55).withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '닫기',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        );
      },
    );
  }

  // 프로필 이미지별 색상 매핑
  Color _getProfileColor(String imageUrl) {
    switch (imageUrl) {
      case '/images/profile1.png':
        return const Color(0xFF4CAF50);
      case '/images/profile2.png':
        return const Color(0xFF8BC34A);
      case '/images/profile3.png':
        return const Color(0xFFFFEB3B);
      case '/images/profile4.png':
        return const Color(0xFFFF9800);
      case '/images/profile5.png':
        return const Color(0xFFFF5722);
      case '/images/profile6.png':
        return const Color(0xFFFA2E55);
      default:
        return const Color(0xFFFA2E55);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '프로필 관리',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임 입력
                const Text(
                  '닉네임',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFA2E55)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 프로필 이미지 선택
                _buildProfileImageSelector(),

                const SizedBox(height: 40),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: appState.isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA2E55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: appState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      '저장하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}