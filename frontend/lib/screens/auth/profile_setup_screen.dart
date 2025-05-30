import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/profile_avatar.dart';
import 'dart:io';  // File 클래스용
import 'package:image_picker/image_picker.dart';  // 이미지 선택용
import '../../widgets/custom_button.dart';  // CustomButton 위젯용

class ProfileSetupScreen extends StatefulWidget {
  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _nicknameController.text = authProvider.user!.nickname;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 이미 방에 속해있다면 홈으로
    if (authProvider.user?.currentRoom != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('프로필 설정'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _skipToRoomSelection(),
            child: Text('건너뛰기'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 32),

                        // 프로필 사진 설정
                        _buildProfileImageSection(),

                        SizedBox(height: 40),

                        // 닉네임 입력
                        _buildNicknameSection(),

                        SizedBox(height: 24),

                        // 안내 텍스트
                        _buildInfoText(),
                      ],
                    ),
                  ),
                ),

                // 하단 버튼들
                _buildBottomButtons(authProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    final authProvider = Provider.of<AuthProvider>(context);

    return Column(
      children: [
        Text(
          '프로필 사진을 설정해주세요',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 8),

        Text(
          '나중에 변경할 수 있습니다',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),

        SizedBox(height: 32),

        Stack(
          children: [
            ProfileAvatar(
              imageUrl: _selectedImage != null
                  ? _selectedImage!.path
                  : authProvider.user?.profileImage,
              size: 120,
              isEditable: true,
              onTap: _showImagePickerOptions,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNicknameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '닉네임',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: 8),

        TextFormField(
          controller: _nicknameController,
          decoration: InputDecoration(
            hintText: '사용할 닉네임을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '닉네임을 입력해주세요';
            }
            if (value.trim().length < 2) {
              return '닉네임은 2자 이상이어야 합니다';
            }
            if (value.trim().length > 20) {
              return '닉네임은 20자 이하여야 합니다';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildInfoText() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '프로필 설정 후 방을 생성하거나 기존 방에 참여할 수 있습니다.',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(AuthProvider authProvider) {
    return Column(
      children: [
        CustomButton(
          text: '완료',
          isLoading: authProvider.isLoading,
          onPressed: _nicknameController.text.trim().length >= 2
              ? () => _updateProfile(authProvider)
              : null,
        ),

        SizedBox(height: 12),

        TextButton(
          onPressed: () => _skipToRoomSelection(),
          child: Text('나중에 설정하기'),
        ),

        if (authProvider.error != null) ...[
          SizedBox(height: 16),
          Container(
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
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera),
              title: Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null ||
                (Provider.of<AuthProvider>(context, listen: false).user?.profileImage?.isNotEmpty ?? false))
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('사진 삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다')),
      );
    }
  }

  Future<void> _updateProfile(AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    String? imageBase64;
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        imageBase64 = 'data:image/jpeg;base64,${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 처리 중 오류가 발생했습니다')),
        );
        return;
      }
    }

    final success = await authProvider.updateProfile(
      nickname: _nicknameController.text.trim(),
      profileImage: imageBase64,
    );

    if (success) {
      _skipToRoomSelection();
    }
  }

  void _skipToRoomSelection() {
    Navigator.pushReplacementNamed(context, '/room-selection');
  }
}