import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';

class RoomCreateScreen extends StatefulWidget {
  @override
  _RoomCreateScreenState createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends State<RoomCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('새 방 만들기'),
      ),
      body: SafeArea(
        child: Consumer<RoomProvider>(
          builder: (context, roomProvider, child) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Icon(Icons.add_home, size: 80, color: Colors.blue),
                            SizedBox(height: 24),
                            Text(
                              '새로운 공간을 만들어보세요',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '방 이름과 설명을 입력해주세요',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            SizedBox(height: 32),

                            CustomInput(
                              label: '방 이름',
                              hint: '예: 우리집, 기숙사 201호',
                              controller: _nameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '방 이름을 입력해주세요';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: 24),

                            CustomInput(
                              label: '방 설명 (선택)',
                              hint: '방에 대한 간단한 설명',
                              controller: _descriptionController,
                              maxLength: 100,
                            ),
                          ],
                        ),
                      ),
                    ),

                    CustomButton(
                      text: '방 만들기',
                      onPressed: () => _createRoom(roomProvider),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createRoom(RoomProvider roomProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await roomProvider.createRoom(
      _nameController.text.trim(),
      _descriptionController.text.trim(),
    );

    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}