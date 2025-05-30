class AppUser {
  final String id;
  final String nickname;
  final String? profileColor;
  final DateTime? createdAt;
  final DateTime? lastActive;

  AppUser({
    required this.id,
    required this.nickname,
    this.profileColor,
    this.createdAt,
    this.lastActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? json['_id'] ?? '',
      nickname: json['nickname'] ?? '',
      profileColor: json['profileColor'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'profileColor': profileColor,
      'createdAt': createdAt?.toIso8601String(),
      'lastActive': lastActive?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? nickname,
    String? profileColor,
  }) {
    return AppUser(
      id: id,
      nickname: nickname ?? this.nickname,
      profileColor: profileColor ?? this.profileColor,
      createdAt: createdAt,
      lastActive: DateTime.now(),
    );
  }
}