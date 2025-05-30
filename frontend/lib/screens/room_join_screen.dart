import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';

class RoomJoinScreen extends StatefulWidget {
  @override
  _RoomJoinScreenState createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends State<RoomJoinScreen> {
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('방 참여하기'),
      ),
      body: SafeArea(
        child: Consumer<RoomProvider>(
          builder: (context, roomProvider, child) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.meeting_room, size: 80, color: Colors.green),
                        SizedBox(height: 24),
                        Text(
                          '초대 코드를 입력하세요',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '방장에게서 받은 6자리 코드를 입력해주세요',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32),

                        CustomInput(
                          label: '초대 코드',
                          hint: '예: ABC123',
                          controller: _codeController,
                          maxLength: 6,
                          keyboardType: TextInputType.text,
                        ),

                        SizedBox(height: 16),

                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '테스트용 코드: TEST01',
                                  style: TextStyle(color: Colors.green[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  CustomButton(
                    text: '참여하기',
                    backgroundColor: Colors.green,
                    onPressed: _codeController.text.trim().length >= 6
                        ? () => _joinRoom(roomProvider)
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
          },
        ),
      ),
    );
  }

  Future<void> _joinRoom(RoomProvider roomProvider) async {
    final success = await roomProvider.joinRoom(_codeController.text.trim());

    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}