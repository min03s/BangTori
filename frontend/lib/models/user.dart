class User {
  final String id;
  final String socialId;
  final String provider;
  final String email;
  final String nickname;
  final String profileImage;
  final String? currentRoom;
  final LocationStatus location;
  final NotificationSettings notifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.socialId,
    required this.provider,
    required this.email,
    required this.nickname,
    required this.profileImage,
    this.currentRoom,
    required this.location,
    required this.notifications,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      socialId: json['socialId'],
      provider: json['provider'],
      email: json['email'],
      nickname: json['nickname'],
      profileImage: json['profileImage'] ?? '',
      currentRoom: json['currentRoom'],
      location: LocationStatus.fromJson(json['location'] ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'socialId': socialId,
      'provider': provider,
      'email': email,
      'nickname': nickname,
      'profileImage': profileImage,
      'currentRoom': currentRoom,
      'location': location.toJson(),
      'notifications': notifications.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    String? nickname,
    String? profileImage,
    String? currentRoom,
    LocationStatus? location,
    NotificationSettings? notifications,
  }) {
    return User(
      id: id,
      socialId: socialId,
      provider: provider,
      email: email,
      nickname: nickname ?? this.nickname,
      profileImage: profileImage ?? this.profileImage,
      currentRoom: currentRoom ?? this.currentRoom,
      location: location ?? this.location,
      notifications: notifications ?? this.notifications,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class LocationStatus {
  final String status; // 'home' | 'out'
  final bool allowTracking;
  final DateTime lastUpdated;

  LocationStatus({
    required this.status,
    required this.allowTracking,
    required this.lastUpdated,
  });

  factory LocationStatus.fromJson(Map<String, dynamic> json) {
    return LocationStatus(
      status: json['status'] ?? 'home',
      allowTracking: json['allowTracking'] ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'allowTracking': allowTracking,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class NotificationSettings {
  final bool push;
  final String? token;

  NotificationSettings({
    required this.push,
    this.token,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      push: json['push'] ?? true,
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push': push,
      'token': token,
    };
  }
}