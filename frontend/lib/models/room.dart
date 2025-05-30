import 'user.dart';

class Room {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final AppUser owner;
  final List<AppUser> members;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.owner,
    required this.members,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      inviteCode: json['inviteCode'],
      owner: AppUser.fromJson(json['owner']),
      members: (json['members'] as List)
          .map((memberJson) => AppUser.fromJson(memberJson))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
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
      'createdAt': createdAt.toIso8601String(),
    };
  }
}