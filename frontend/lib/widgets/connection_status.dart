import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';

class ConnectionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, child) {
        if (roomProvider.isConnected) {
          return SizedBox.shrink(); // 연결되어 있으면 표시하지 않음
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange[100],
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange[700], size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '오프라인 모드 - 일부 기능이 제한될 수 있습니다',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}