class UserModel {
  final String id;
  final String email;
  final String username;
  final String avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? 'user-demo-1',
      email: json['email'] as String? ?? 'cinefilo@swipeflick.app',
      username: json['username'] as String? ?? 'Cinéfilo',
      avatarUrl: json['avatar_url'] as String? ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _demoCounter = 1;

  static UserModel createDemo({String? id, String? name, String? email}) {
    return UserModel(
      id: id ?? 'usr_${_demoCounter++}_${DateTime.now().microsecondsSinceEpoch}',
      email: email ?? 'cinefilo@swipeflick.app',
      username: name ?? 'Alex Cinéfilo',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      createdAt: DateTime.now(),
    );
  }
}
