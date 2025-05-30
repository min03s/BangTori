import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/custom_button.dart';

class RoomDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<RoomProvider>(
          builder: (context, roomProvider, child) {
            return Text(roomProvider.currentRoom?.name ?? '방');
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('초대 코드 공유'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('방 나가기', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<RoomProvider>(
        builder: (context, roomProvider, child) {
          final room = roomProvider.currentRoom;
          if (room == null) return SizedBox();

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // 방 정보 카드
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.home, size: 32, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (room.description.isNotEmpty)
                                    Text(
                                      room.description,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '생성일: ${_formatDate(room.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 초대 코드 카드
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.qr_code, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              '초대 코드',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                room.inviteCode,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: Colors.green[700],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copyToClipboard(context, room.inviteCode),
                                icon: Icon(Icons.copy, color: Colors.green[700]),
                                tooltip: '복사',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '이 코드를 친구들에게 공유하세요!',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 멤버 목록
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                '멤버 (${room.members.length}명)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: room.members.length,
                              itemBuilder: (context, index) {
                                final member = room.members[index];
                                final isOwner = member.id == room.owner.id;
                                final isMe = member.id == roomProvider.currentUser?.id;

                                return Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blue[50] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: isMe ? Border.all(color: Colors.blue[200]!) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: member.profileColor != null
                                              ? Color(int.parse(member.profileColor!.substring(1), radix: 16) + 0xFF000000)
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            member.nickname[0].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  member.nickname,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  SizedBox(width: 8),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '나',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (isOwner)
                                              Text(
                                                '방장',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isOwner)
                                        Icon(Icons.star, color: Colors.orange, size: 20),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 기능 버튼들
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: '집안일 관리',
                        icon: Icons.cleaning_services,
                        backgroundColor: Colors.purple,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('집안일 관리 기능 준비 중입니다')),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: '예약 관리',
                        icon: Icons.schedule,
                        backgroundColor: Colors.green,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('예약 관리 기능 준비 중입니다')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('초대 코드가 복사되었습니다: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    switch (action) {
      case 'invite':
        _copyToClipboard(context, roomProvider.currentRoom!.inviteCode);
        break;
      case 'leave':
        _showLeaveDialog(context, roomProvider);
        break;
    }
  }

  void _showLeaveDialog(BuildContext context, RoomProvider roomProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('방 나가기'),
        content: Text('정말로 이 방을 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              roomProvider.leaveRoom();
            },
            child: Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}