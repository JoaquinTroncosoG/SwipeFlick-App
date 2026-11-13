import 'movie_model.dart';
import 'genre_model.dart';

enum RoomPhase {
  lobby,          // Esperando participantes
  categories,     // Fase 1: votación de categorías
  categoryMatch,  // Celebración de categorías ganadoras antes de películas
  movies,         // Fase 2: votación de películas de categorías coincidentes
  result,         // Match encontrado o fallback del randomizer
}

enum RoomStatus {
  waiting,
  categories,
  movies,
  completed,
  expired,
  closed,
}

class RoomMemberModel {
  final String id;
  final String userId;
  final String email;
  final String username;
  final String avatarUrl;
  final bool isHost;
  final bool isReady;
  final String phase;
  final DateTime joinedAt;
  final Map<int, bool> categoryVotes; // genreId -> approved
  final Map<int, bool> movieVotes;    // movieId -> approved

  const RoomMemberModel({
    required this.id,
    required this.userId,
    this.email = '',
    required this.username,
    required this.avatarUrl,
    this.isHost = false,
    this.isReady = false,
    this.phase = 'lobby',
    required this.joinedAt,
    this.categoryVotes = const {},
    this.movieVotes = const {},
  });

  RoomMemberModel copyWith({
    String? id,
    String? userId,
    String? email,
    String? username,
    String? avatarUrl,
    bool? isHost,
    bool? isReady,
    String? phase,
    DateTime? joinedAt,
    Map<int, bool>? categoryVotes,
    Map<int, bool>? movieVotes,
  }) {
    return RoomMemberModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      phase: phase ?? this.phase,
      joinedAt: joinedAt ?? this.joinedAt,
      categoryVotes: categoryVotes ?? this.categoryVotes,
      movieVotes: movieVotes ?? this.movieVotes,
    );
  }

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) {
    return RoomMemberModel(
      id: json['id'] as String? ?? json['_id']?.toString() ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? 'Invitado',
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String? ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      isHost: json['is_host'] as bool? ?? json['isHost'] as bool? ?? false,
      isReady: json['is_ready'] as bool? ?? json['isReady'] as bool? ?? false,
      phase: json['phase'] as String? ?? 'lobby',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now()
          : (json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now() : DateTime.now()),
      categoryVotes: (json['category_votes'] as Map?)?.map(
            (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v == true),
          ) ??
          (json['categoryVotes'] as Map?)?.map(
            (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v == true),
          ) ??
          {},
      movieVotes: (json['movie_votes'] as Map?)?.map(
            (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v == true),
          ) ??
          (json['movieVotes'] as Map?)?.map(
            (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v == true),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
      'is_host': isHost,
      'is_ready': isReady,
      'phase': phase,
      'joined_at': joinedAt.toIso8601String(),
      'category_votes': categoryVotes.map((k, v) => MapEntry(k.toString(), v)),
      'movie_votes': movieVotes.map((k, v) => MapEntry(k.toString(), v)),
    };
  }
}

class RoomModel {
  final String id;
  final String code; // 6 dígitos alfanuméricos
  final String hostId;
  final String hostUsername;
  final int maxMembers; // Personalizable por el host (mínimo 2)
  final int matchThreshold; // 1 a 5 categorías necesarias para coincidir
  final bool excludeMatches; // Considerar/excluir películas ya vistas o matches de los miembros
  final RoomStatus status;
  final RoomPhase phase;
  final List<RoomMemberModel> members;
  final List<GenreModel> matchedCategories;
  final MovieModel? matchedMovie;
  final bool isRandomizerResult;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<int, List<String>> categoryLikes; // genreId -> [userId1, userId2]
  final Map<int, List<String>> movieLikes;    // movieId -> [userId1, userId2]
  final List<MovieModel> movieDeck;           // Baraja compartida sincronizada

  const RoomModel({
    required this.id,
    required this.code,
    required this.hostId,
    required this.hostUsername,
    this.maxMembers = 5,
    this.matchThreshold = 2,
    this.excludeMatches = false,
    this.status = RoomStatus.waiting,
    this.phase = RoomPhase.lobby,
    this.members = const [],
    this.matchedCategories = const [],
    this.matchedMovie,
    this.isRandomizerResult = false,
    required this.createdAt,
    required this.expiresAt,
    this.categoryLikes = const {},
    this.movieLikes = const {},
    this.movieDeck = const [],
  });

  bool get isFull => members.length >= maxMembers;

  RoomModel copyWith({
    String? id,
    String? code,
    String? hostId,
    String? hostUsername,
    int? maxMembers,
    int? matchThreshold,
    bool? excludeMatches,
    RoomStatus? status,
    RoomPhase? phase,
    List<RoomMemberModel>? members,
    List<GenreModel>? matchedCategories,
    MovieModel? matchedMovie,
    bool? isRandomizerResult,
    DateTime? createdAt,
    DateTime? expiresAt,
    Map<int, List<String>>? categoryLikes,
    Map<int, List<String>>? movieLikes,
    List<MovieModel>? movieDeck,
  }) {
    return RoomModel(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      hostUsername: hostUsername ?? this.hostUsername,
      maxMembers: maxMembers ?? this.maxMembers,
      matchThreshold: matchThreshold ?? this.matchThreshold,
      excludeMatches: excludeMatches ?? this.excludeMatches,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      members: members ?? this.members,
      matchedCategories: matchedCategories ?? this.matchedCategories,
      matchedMovie: matchedMovie ?? this.matchedMovie,
      isRandomizerResult: isRandomizerResult ?? this.isRandomizerResult,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      categoryLikes: categoryLikes ?? this.categoryLikes,
      movieLikes: movieLikes ?? this.movieLikes,
      movieDeck: movieDeck ?? this.movieDeck,
    );
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    Map<int, List<String>> parseLikesMap(dynamic raw) {
      if (raw is! Map) return {};
      final result = <int, List<String>>{};
      raw.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v is List) {
          result[id] = v.map((e) => e.toString()).toList();
        }
      });
      return result;
    }

    return RoomModel(
      id: json['id'] as String? ?? json['_id']?.toString() ?? '',
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      hostId: json['host_id'] as String? ?? json['hostId'] as String? ?? '',
      hostUsername: json['host_username'] as String? ?? json['hostUsername'] as String? ?? 'Host',
      maxMembers: json['max_members'] as int? ?? json['maxMembers'] as int? ?? 5,
      matchThreshold: json['match_threshold'] as int? ?? json['matchThreshold'] as int? ?? 2,
      excludeMatches: json['exclude_matches'] as bool? ?? json['excludeMatches'] as bool? ?? false,
      status: RoomStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RoomStatus.waiting,
      ),
      phase: RoomPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => RoomPhase.lobby,
      ),
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => RoomMemberModel.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          [],
      matchedCategories: (json['matched_categories'] as List<dynamic>?)
              ?.map((c) => GenreModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          (json['matchedCategories'] as List<dynamic>?)
              ?.map((c) => GenreModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [],
      matchedMovie: json['matched_movie'] != null
          ? MovieModel.fromJson(Map<String, dynamic>.from(json['matched_movie'] as Map))
          : (json['matchedMovie'] != null
              ? MovieModel.fromJson(Map<String, dynamic>.from(json['matchedMovie'] as Map))
              : null),
      isRandomizerResult: json['is_randomizer_result'] as bool? ?? json['isRandomizerResult'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now()),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString()) ??
              DateTime.now().add(const Duration(minutes: 30))
          : (json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) ?? DateTime.now().add(const Duration(minutes: 30)) : DateTime.now().add(const Duration(minutes: 30))),
      categoryLikes: parseLikesMap(json['category_likes'] ?? json['categoryLikes']),
      movieLikes: parseLikesMap(json['movie_likes'] ?? json['movieLikes']),
      movieDeck: (json['movie_deck'] as List<dynamic>?)
              ?.map((m) => MovieModel.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          (json['movieDeck'] as List<dynamic>?)
              ?.map((m) => MovieModel.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'host_id': hostId,
      'host_username': hostUsername,
      'max_members': maxMembers,
      'match_threshold': matchThreshold,
      'exclude_matches': excludeMatches,
      'status': status.name,
      'phase': phase.name,
      'members': members.map((m) => m.toJson()).toList(),
      'matched_categories': matchedCategories.map((c) => c.toJson()).toList(),
      'matched_movie': matchedMovie?.toJson(),
      'is_randomizer_result': isRandomizerResult,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'category_likes': categoryLikes.map((k, v) => MapEntry(k.toString(), v)),
      'movie_likes': movieLikes.map((k, v) => MapEntry(k.toString(), v)),
      'movie_deck': movieDeck.map((m) => m.toJson()).toList(),
    };
  }
}
