import 'user.dart';

class Room {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final AppUser owner;
  final List<RoomMember> members;
  final int maxMembers;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Room({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.owner,
    required this.members,
    this.maxMembers = 10,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      inviteCode: json['inviteCode'] ?? '',
      owner: AppUser.fromJson(json['owner'] ?? {}),
      members: (json['members'] as List? ?? [])
          .map((memberJson) => RoomMember.fromJson(memberJson))
          .toList(),
      maxMembers: json['maxMembers'] ?? 10,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'owner': owner.toJson(),
      'members': members.map((member) => member.toJson()).toList(),
      'maxMembers': maxMembers,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // 사용자가 멤버인지 확인
  bool isMember(String userId) {
    return members.any((member) => member.user.id == userId);
  }

  // 사용자가 방장인지 확인
  bool isOwner(String userId) {
    return owner.id == userId;
  }
}

class RoomMember {
  final AppUser user;
  final DateTime joinedAt;

  RoomMember({
    required this.user,
    required this.joinedAt,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      user: AppUser.fromJson(json['user'] ?? {}),
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}