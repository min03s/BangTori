import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/room.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class RoomProvider with ChangeNotifier {
  Room? _currentRoom;
  AppUser? _currentUser;
  List<Room> _myRooms = [];
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;

  Room? get currentRoom => _currentRoom;
  AppUser? get currentUser => _currentUser;
  List<Room> get myRooms => _myRooms;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _isConnected;

  // 초기화
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadUserData();

      if (_currentUser != null) {
        await _loadUserRooms();
        _setupSocketListeners();
        SocketService.connect();
      }

      await _checkServerConnection();
    } catch (e) {
      _error = e.toString();
      print('❌ 초기화 오류: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 서버 연결 확인
  Future<void> _checkServerConnection() async {
    _isConnected = await ApiService.checkConnection();
    if (!_isConnected) {
      print('⚠️ 서버에 연결할 수 없습니다. 오프라인 모드로 실행됩니다.');
    }
    notifyListeners();
  }

  // Socket 이벤트 리스너 설정
  void _setupSocketListeners() {
    SocketService.onMemberJoined((data) {
      if (data['room'] != null) {
        _updateCurrentRoom(Room.fromJson(data['room']));
      }
    });

    SocketService.onMemberLeft((data) {
      if (data['room'] != null) {
        _updateCurrentRoom(Room.fromJson(data['room']));
      }
    });

    SocketService.onRoomUpdated((data) {
      if (data['room'] != null) {
        _updateCurrentRoom(Room.fromJson(data['room']));
      }
    });

    SocketService.onRoomDeleted((data) {
      final roomId = data['roomId'];
      if (roomId != null) {
        _handleRoomDeleted(roomId);
      }
    });
  }

  // 현재 방 업데이트
  void _updateCurrentRoom(Room updatedRoom) {
    if (_currentRoom?.id == updatedRoom.id) {
      _currentRoom = updatedRoom;

      // 내 방 목록에서도 업데이트
      final index = _myRooms.indexWhere((room) => room.id == updatedRoom.id);
      if (index != -1) {
        _myRooms[index] = updatedRoom;
      }

      _saveRoomData();
      notifyListeners();
    }
  }

  // 방 삭제 처리
  void _handleRoomDeleted(String roomId) {
    if (_currentRoom?.id == roomId) {
      _currentRoom = null;
    }

    _myRooms.removeWhere((room) => room.id == roomId);
    _saveRoomData();
    notifyListeners();
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');

    if (userJson != null) {
      final userData = json.decode(userJson);
      _currentUser = AppUser.fromJson(userData);

      // 서버에서 최신 사용자 정보 가져오기 (온라인일 때)
      if (_isConnected) {
        try {
          final response = await ApiService.getUser(_currentUser!.id);
          _currentUser = AppUser.fromJson(response['data']);
          await _saveUserData();
        } catch (e) {
          print('⚠️ 사용자 정보 동기화 실패: $e');
        }
      }
    }
  }

  // 사용자 방 목록 로드
  Future<void> _loadUserRooms() async {
    if (_currentUser == null) return;

    try {
      // 로컬 데이터 먼저 로드
      final prefs = await SharedPreferences.getInstance();
      final roomsJson = prefs.getStringList('my_rooms') ?? [];
      _myRooms = roomsJson
          .map((roomStr) => Room.fromJson(json.decode(roomStr)))
          .toList();

      final currentRoomJson = prefs.getString('current_room');
      if (currentRoomJson != null) {
        _currentRoom = Room.fromJson(json.decode(currentRoomJson));
      }

      // 서버에서 최신 데이터 가져오기 (온라인일 때)
      if (_isConnected) {
        final response = await ApiService.getUserRooms(_currentUser!.id);
        final serverRooms = (response['data'] as List)
            .map((roomJson) => Room.fromJson(roomJson))
            .toList();

        _myRooms = serverRooms;

        // 현재 방이 서버 목록에 있는지 확인
        if (_currentRoom != null) {
          final currentRoomFromServer = serverRooms
              .where((room) => room.id == _currentRoom!.id)
              .firstOrNull;

          if (currentRoomFromServer != null) {
            _currentRoom = currentRoomFromServer;
          } else {
            _currentRoom = null; // 서버에 없으면 초기화
          }
        }

        await _saveRoomData();
      }
    } catch (e) {
      print('⚠️ 방 목록 로드 실패: $e');
      _error = e.toString();
    }
  }

  // 사용자 생성
  Future<void> createUser(String nickname) async {
    try {
      _setLoading(true);
      _clearError();

      if (_isConnected) {
        // 서버에서 사용자 생성
        final response = await ApiService.createUser(nickname);
        _currentUser = AppUser.fromJson(response['data']);
        print('✅ 서버에서 사용자 생성 완료: ${_currentUser!.id}');
      } else {
        // 오프라인 모드
        _currentUser = AppUser(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nickname: nickname,
          profileColor: _getRandomColor(),
          createdAt: DateTime.now(),
        );
        print('📱 오프라인 모드로 사용자 생성: ${_currentUser!.id}');
      }

      await _saveUserData();
      _setLoading(false);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      throw e;
    }
  }

  // 방 생성
  Future<bool> createRoom(String name, String description) async {
    if (_currentUser == null) {
      _error = '먼저 닉네임을 설정해주세요';
      notifyListeners();
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      Room newRoom;

      if (_isConnected) {
        // 서버에서 방 생성
        final response = await ApiService.createRoom(
          name: name,
          description: description,
          ownerId: _currentUser!.id,
        );
        newRoom = Room.fromJson(response['data']);
        print('✅ 서버에서 방 생성 완료: ${newRoom.id}');
      } else {
        // 오프라인 모드
        newRoom = Room(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          description: description,
          inviteCode: _generateInviteCode(),
          owner: _currentUser!,
          members: [RoomMember(user: _currentUser!, joinedAt: DateTime.now())],
          createdAt: DateTime.now(),
        );
        print('📱 오프라인 모드로 방 생성: ${newRoom.id}');
      }

      _currentRoom = newRoom;
      if (!_myRooms.any((room) => room.id == newRoom.id)) {
        _myRooms.add(newRoom);
      }

      await _saveRoomData();

      // Socket 방 참여
      if (SocketService.isConnected) {
        SocketService.joinRoom(newRoom.id);
      }

      _setLoading(false);
      return true;

    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // 방 참여
  Future<bool> joinRoom(String inviteCode) async {
    if (_currentUser == null) {
      _error = '먼저 닉네임을 설정해주세요';
      notifyListeners();
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      Room room;

      if (_isConnected) {
        // 서버에서 방 참여
        final response = await ApiService.joinRoom(
          inviteCode: inviteCode,
          userId: _currentUser!.id,
        );
        room = Room.fromJson(response['data']);
        print('✅ 서버에서 방 참여 완료: ${room.id}');
      } else {
        // 오프라인 모드 - 기존 방에서 찾기 또는 데모 방 생성
        final existingRoom = _myRooms.where((r) => r.inviteCode == inviteCode).firstOrNull;
        if (existingRoom != null) {
          room = existingRoom;
        } else {
          // 데모 방 생성
          room = _createDemoRoom(inviteCode);
        }
        print('📱 오프라인 모드로 방 참여: ${room.id}');
      }

      _currentRoom = room;
      if (!_myRooms.any((r) => r.id == room.id)) {
        _myRooms.add(room);
      }

      await _saveRoomData();

      // Socket 방 참여
      if (SocketService.isConnected) {
        SocketService.joinRoom(room.id);
      }

      _setLoading(false);
      return true;

    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // 방 나가기
  Future<void> leaveRoom() async {
    if (_currentRoom == null || _currentUser == null) return;

    try {
      final roomId = _currentRoom!.id;

      if (_isConnected) {
        await ApiService.leaveRoom(
          roomId: roomId,
          userId: _currentUser!.id,
        );
        print('✅ 서버에서 방 나가기 완료');
      }

      // Socket 방 나가기
      if (SocketService.isConnected) {
        SocketService.leaveRoom(roomId);
      }

      _currentRoom = null;
      await _saveRoomData();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 방 선택
  Future<void> selectRoom(Room room) async {
    _currentRoom = room;

    // 최신 방 정보 가져오기 (온라인일 때)
    if (_isConnected) {
      try {
        final response = await ApiService.getRoom(room.id);
        _currentRoom = Room.fromJson(response['data']);
      } catch (e) {
        print('⚠️ 방 정보 동기화 실패: $e');
      }
    }

    await _saveRoomData();

    // Socket 방 참여
    if (SocketService.isConnected && _currentRoom != null) {
      SocketService.joinRoom(_currentRoom!.id);
    }

    notifyListeners();
  }

  // 데모 방 생성 (오프라인 모드용)
  Room _createDemoRoom(String inviteCode) {
    return Room(
      id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      name: '테스트 방',
      description: '초대 코드로 참여한 방입니다',
      inviteCode: inviteCode.toUpperCase(),
      owner: AppUser(
        id: 'demo_owner',
        nickname: '방장',
        profileColor: '#2196F3',
        createdAt: DateTime.now(),
      ),
      members: [
        RoomMember(
          user: AppUser(
            id: 'demo_owner',
            nickname: '방장',
            profileColor: '#2196F3',
            createdAt: DateTime.now(),
          ),
          joinedAt: DateTime.now(),
        ),
        RoomMember(
          user: _currentUser!,
          joinedAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  // 초대 코드 생성 (오프라인용)
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String result = '';
    for (int i = 0; i < 6; i++) {
      result += chars[(DateTime.now().millisecondsSinceEpoch + i) % chars.length];
    }
    return result;
  }

  // 랜덤 색상 선택
  String _getRandomColor() {
    final colors = [
      '#FF5722', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFC107', '#FF9800', '#FF5722', '#795548',
    ];
    return colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }

  // 데이터 저장
  Future<void> _saveUserData() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', json.encode(_currentUser!.toJson()));
    }
  }

  Future<void> _saveRoomData() async {
    final prefs = await SharedPreferences.getInstance();

    // 내 방 목록 저장
    final roomsJson = _myRooms.map((room) => json.encode(room.toJson())).toList();
    await prefs.setStringList('my_rooms', roomsJson);

    // 현재 방 저장
    if (_currentRoom != null) {
      await prefs.setString('current_room', json.encode(_currentRoom!.toJson()));
    } else {
      await prefs.remove('current_room');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  // 정리
  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }
}