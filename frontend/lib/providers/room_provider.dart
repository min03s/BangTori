import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/room.dart';
import '../models/user.dart';
import '../utils/code_generator.dart';

class RoomProvider with ChangeNotifier {
  Room? _currentRoom;
  AppUser? _currentUser;
  List<Room> _myRooms = [];
  bool _isLoading = false;
  String? _error;

  Room? get currentRoom => _currentRoom;
  AppUser? get currentUser => _currentUser;
  List<Room> get myRooms => _myRooms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 초기화
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadUserData();
      await _loadRoomData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // 사용자 생성 또는 로드
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');

    if (userJson != null) {
      _currentUser = AppUser.fromJson(json.decode(userJson));
    }
  }

  // 방 데이터 로드
  Future<void> _loadRoomData() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = prefs.getStringList('my_rooms') ?? [];

    _myRooms = roomsJson
        .map((roomStr) => Room.fromJson(json.decode(roomStr)))
        .toList();

    final currentRoomJson = prefs.getString('current_room');
    if (currentRoomJson != null) {
      _currentRoom = Room.fromJson(json.decode(currentRoomJson));
    }
  }

  // 사용자 생성
  Future<void> createUser(String nickname) async {
    try {
      _setLoading(true);

      _currentUser = AppUser(
        id: CodeGenerator.generateUserId(),
        nickname: nickname,
        profileColor: CodeGenerator.getRandomColor(),
      );

      await _saveUserData();
      _setLoading(false);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
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

      final room = Room(
        id: CodeGenerator.generateUserId(),
        name: name,
        description: description,
        inviteCode: CodeGenerator.generateRoomCode(),
        owner: _currentUser!,
        members: [_currentUser!],
        createdAt: DateTime.now(),
      );

      _currentRoom = room;
      _myRooms.add(room);

      await _saveRoomData();
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

      // 실제로는 서버에서 코드 검증하지만, 여기서는 로컬 저장소에서 찾기
      final existingRoom = _myRooms.firstWhere(
            (room) => room.inviteCode == inviteCode,
        orElse: () => _createDemoRoom(inviteCode),
      );

      // 이미 멤버인지 확인
      if (!existingRoom.members.any((member) => member.id == _currentUser!.id)) {
        final updatedMembers = [...existingRoom.members, _currentUser!];
        final updatedRoom = Room(
          id: existingRoom.id,
          name: existingRoom.name,
          description: existingRoom.description,
          inviteCode: existingRoom.inviteCode,
          owner: existingRoom.owner,
          members: updatedMembers,
          createdAt: existingRoom.createdAt,
        );

        _currentRoom = updatedRoom;

        // 기존 방 업데이트
        final roomIndex = _myRooms.indexWhere((room) => room.id == existingRoom.id);
        if (roomIndex != -1) {
          _myRooms[roomIndex] = updatedRoom;
        } else {
          _myRooms.add(updatedRoom);
        }
      } else {
        _currentRoom = existingRoom;
      }

      await _saveRoomData();
      _setLoading(false);
      return true;

    } catch (e) {
      _error = '유효하지 않은 초대 코드입니다';
      _setLoading(false);
      return false;
    }
  }

  // 데모 방 생성 (실제로는 서버에서 처리)
  Room _createDemoRoom(String inviteCode) {
    return Room(
      id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      name: '테스트 방',
      description: '초대 코드로 참여한 방입니다',
      inviteCode: inviteCode,
      owner: AppUser(id: 'demo_owner', nickname: '방장', profileColor: '#2196F3'),
      members: [
        AppUser(id: 'demo_owner', nickname: '방장', profileColor: '#2196F3'),
        AppUser(id: 'demo_member1', nickname: '멤버1', profileColor: '#4CAF50'),
      ],
      createdAt: DateTime.now(),
    );
  }

  // 방 나가기
  Future<void> leaveRoom() async {
    _currentRoom = null;
    await _saveRoomData();
    notifyListeners();
  }

  // 방 선택
  void selectRoom(Room room) {
    _currentRoom = room;
    _saveRoomData();
    notifyListeners();
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
}