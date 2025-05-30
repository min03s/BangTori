class User {
  final String id;
  final String nickname;
  final String email;
  final String? profileImage;
  final String? currentRoom;

  User({
    required this.id,
    required this.nickname,
    required this.email,
    this.profileImage,
    this.currentRoom,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      currentRoom: json['currentRoom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'email': email,
      'profileImage': profileImage,
      'currentRoom': currentRoom,
    };
  }
}