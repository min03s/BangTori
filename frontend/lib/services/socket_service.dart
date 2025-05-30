import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;

  static bool get isConnected => _isConnected;

  // Socket 연결
  static void connect() {
    try {
      print('🔌 Socket 연결 시도: ${AppConfig.socketUrl}');

      _socket = IO.io(AppConfig.socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 10000,
      });

      _socket!.connect();

      _socket!.on('connect', (_) {
        print('✅ Socket 연결 성공');
        _isConnected = true;
      });

      _socket!.on('disconnect', (_) {
        print('❌ Socket 연결 해제');
        _isConnected = false;
      });

      _socket!.on('connect_error', (error) {
        print('❌ Socket 연결 오류: $error');
        _isConnected = false;
      });

    } catch (e) {
      print('❌ Socket 초기화 오류: $e');
    }
  }

  // 방 참여
  static void joinRoom(String roomId) {
    if (_socket != null && _isConnected) {
      print('📍 Socket: 방 참여 - $roomId');
      _socket!.emit('join_room', roomId);
    }
  }

  // 방 나가기
  static void leaveRoom(String roomId) {
    if (_socket != null && _isConnected) {
      print('🚪 Socket: 방 나가기 - $roomId');
      _socket!.emit('leave_room', roomId);
    }
  }

  // 방 업데이트 전송
  static void emitRoomUpdate(String roomId, Map<String, dynamic> data) {
    if (_socket != null && _isConnected) {
      print('📤 Socket: 방 업데이트 전송 - $roomId');
      _socket!.emit('room_updated', {
        'roomId': roomId,
        ...data,
      });
    }
  }

  // 멤버 참여 이벤트 수신
  static void onMemberJoined(Function(dynamic) callback) {
    _socket?.on('member_joined', (data) {
      print('👥 Socket: 멤버 참여 - $data');
      callback(data);
    });
  }

  // 멤버 나가기 이벤트 수신
  static void onMemberLeft(Function(dynamic) callback) {
    _socket?.on('member_left', (data) {
      print('👥 Socket: 멤버 나가기 - $data');
      callback(data);
    });
  }

  // 방 업데이트 이벤트 수신
  static void onRoomUpdated(Function(dynamic) callback) {
    _socket?.on('room_updated', (data) {
      print('🏠 Socket: 방 업데이트 - $data');
      callback(data);
    });
  }

  // 방 삭제 이벤트 수신
  static void onRoomDeleted(Function(dynamic) callback) {
    _socket?.on('room_deleted', (data) {
      print('🗑️ Socket: 방 삭제 - $data');
      callback(data);
    });
  }

  // 모든 이벤트 리스너 제거
  static void removeAllListeners() {
    _socket?.off('member_joined');
    _socket?.off('member_left');
    _socket?.off('room_updated');
    _socket?.off('room_deleted');
  }

  // Socket 연결 해제
  static void disconnect() {
    if (_socket != null) {
      print('🔌 Socket 연결 해제');
      removeAllListeners();
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
}