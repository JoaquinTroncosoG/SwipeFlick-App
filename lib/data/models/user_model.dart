class UserModel {
  final String id;
  final String email;
  final String username;
  final String avatarUrl;
  final String country; // Código de país (ej. 'CL', 'MX', 'ES', 'AR', 'CO', 'PE', 'US')
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.avatarUrl,
    this.country = 'CL',
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? 'user-demo-1',
      email: json['email'] as String? ?? 'cinefilo@swipeflick.app',
      username: json['username'] as String? ?? 'Cinéfilo',
      avatarUrl: json['avatar_url'] as String? ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      country: json['country'] as String? ?? 'CL',
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
      'country': country,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? avatarUrl,
    String? country,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _demoCounter = 1;

  static UserModel createDemo({String? id, String? name, String? email, String? country}) {
    return UserModel(
      id: id ?? 'usr_${_demoCounter++}_${DateTime.now().microsecondsSinceEpoch}',
      email: email ?? 'cinefilo@swipeflick.app',
      username: name ?? 'Alex Cinéfilo',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      country: country ?? 'CL',
      createdAt: DateTime.now(),
    );
  }
}
