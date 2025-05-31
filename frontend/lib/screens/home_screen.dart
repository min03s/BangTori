import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../widgets/connection_status.dart';
import 'room_create_screen.dart';
import 'room_join_screen.dart';
import 'room_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nicknameController = TextEditingController();
  bool _isButtonEnabled = false; // 버튼 활성화 상태 추가

  @override
  void initState() {
    super.initState();

    // 텍스트 변화 감지 리스너 추가
    _nicknameController.addListener(() {
      setState(() {
        _isButtonEnabled = _nicknameController.text.trim().length >= 2;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoomProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 연결 상태 표시
            ConnectionStatus(),

            // 메인 콘텐츠
            Expanded(
              child: Consumer<RoomProvider>(
                builder: (context, roomProvider, child) {
                  if (roomProvider.isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('로딩 중...'),
                        ],
                      ),
                    );
                  }

                  // 현재 방에 있다면 방 상세 화면
                  if (roomProvider.currentRoom != null) {
                    return RoomDetailScreen();
                  }

                  // 사용자가 없다면 닉네임 설정
                  if (roomProvider.currentUser == null) {
                    return _buildNicknameSetup(roomProvider);
                  }

                  // 방 선택 화면
                  return _buildRoomSelection(roomProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNicknameSetup(RoomProvider roomProvider) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 100, color: Colors.blue),
          SizedBox(height: 24),
          Text(
            '방토리에 오신 것을 환영합니다!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '사용할 닉네임을 입력해주세요',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 32),
          CustomInput(
            label: '닉네임',
            hint: '닉네임을 입력하세요',
            controller: _nicknameController,
            maxLength: 20,
          ),
          SizedBox(height: 24),
          CustomButton(
            text: '시작하기',
            onPressed: _isButtonEnabled  // 수정된 부분
                ? () => _createUser(roomProvider)
                : null,
            isLoading: roomProvider.isLoading,
          ),
          if (roomProvider.error != null) ...[
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
                      roomProvider.error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    onPressed: () => roomProvider.clearError(),
                    icon: Icon(Icons.close, color: Colors.red, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomSelection(RoomProvider roomProvider) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // 헤더
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: roomProvider.currentUser!.profileColor != null
                        ? Color(int.parse(roomProvider.currentUser!.profileColor!.substring(1), radix: 16) + 0xFF000000)
                        : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      roomProvider.currentUser!.nickname[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '안녕하세요, ${roomProvider.currentUser!.nickname}님!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '어떻게 시작하시겠어요?',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                if (!roomProvider.isConnected) ...[
                  SizedBox(height: 8),
                  Text(
                    '(현재 오프라인 모드)',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 32),

          // 방 생성/참여 버튼
          CustomButton(
            text: '새 방 만들기',
            icon: Icons.add_home,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoomCreateScreen()),
            ),
          ),

          SizedBox(height: 16),

          CustomButton(
            text: '초대 코드로 참여하기',
            icon: Icons.meeting_room,
            backgroundColor: Colors.green,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoomJoinScreen()),
            ),
          ),

          SizedBox(height: 32),

          // 내 방 목록
          if (roomProvider.myRooms.isNotEmpty) ...[
            Text(
              '내 방 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: roomProvider.myRooms.length,
                itemBuilder: (context, index) {
                  final room = roomProvider.myRooms[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.home, color: Colors.blue),
                      title: Text(room.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${room.members.length}명 참여 중'),
                          Text(
                            '초대 코드: ${room.inviteCode}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!roomProvider.isConnected)
                            Icon(Icons.cloud_off,
                                color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                      onTap: () {
                        roomProvider.selectRoom(room);
                      },
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Text(
                  '아직 참여한 방이 없습니다.\n새 방을 만들거나 초대 코드로 참여해보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createUser(RoomProvider roomProvider) async {
    try {
      await roomProvider.createUser(_nicknameController.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사용자 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nicknameController.removeListener(() {}); // 리스너 제거
    _nicknameController.dispose();
    super.dispose();
  }
}