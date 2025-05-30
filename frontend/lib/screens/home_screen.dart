import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import 'room_create_screen.dart';
import 'room_join_screen.dart';
import 'room_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoomProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<RoomProvider>(
          builder: (context, roomProvider, child) {
            if (roomProvider.isLoading) {
              return Center(child: CircularProgressIndicator());
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
            onPressed: _nicknameController.text.trim().length >= 2
                ? () => _createUser(roomProvider)
                : null,
            isLoading: roomProvider.isLoading,
          ),
          if (roomProvider.error != null) ...[
            SizedBox(height: 16),
            Text(
              roomProvider.error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
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
                    color: Color(int.parse(roomProvider.currentUser!.profileColor!.substring(1), radix: 16) + 0xFF000000),
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
                      subtitle: Text('${room.members.length}명 참여 중'),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        roomProvider.selectRoom(room);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createUser(RoomProvider roomProvider) async {
    await roomProvider.createUser(_nicknameController.text.trim());
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }
}