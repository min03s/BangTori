class AppUser {
  final String id;
  final String nickname;
  final String? profileColor;

  AppUser({
    required this.id,
    required this.nickname,
    this.profileColor,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      nickname: json['nickname'],
      profileColor: json['profileColor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'profileColor': profileColor,
    };
  }
}