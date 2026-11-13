import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/genre_model.dart';
import '../models/movie_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../mock/mock_movies_data.dart';

class RoomService extends ChangeNotifier {
  RoomModel? _currentRoom;
  final Uuid _uuid = const Uuid();
  Timer? _expirationTimer;

  RoomModel? get currentRoom => _currentRoom;
  bool get isInRoom => _currentRoom != null;

  /// Generar código alfanumérico único de 6 caracteres (ej: SF89K2)
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Crear una nueva sala
  Future<RoomModel> createRoom({
    required UserModel host,
    int maxMembers = 5,
    int matchThreshold = 2,
  }) async {
    final code = _generateRoomCode();
    final now = DateTime.now();

    final hostMember = RoomMemberModel(
      id: _uuid.v4(),
      userId: host.id,
      username: host.username,
      avatarUrl: host.avatarUrl,
      isHost: true,
      isReady: true,
      phase: 'lobby',
      joinedAt: now,
    );

    _currentRoom = RoomModel(
      id: _uuid.v4(),
      code: code,
      hostId: host.id,
      hostUsername: host.username,
      maxMembers: maxMembers,
      matchThreshold: matchThreshold,
      status: RoomStatus.waiting,
      phase: RoomPhase.lobby,
      members: [hostMember],
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
    );

    notifyListeners();
    return _currentRoom!;
  }

  /// Unirse a sala por código
  Future<bool> joinRoom({
    required String code,
    required UserModel user,
  }) async {
    final cleanCode = code.trim().toUpperCase();

    // Si la sala activa tiene ese código
    if (_currentRoom != null && _currentRoom!.code == cleanCode) {
      final alreadyMember = _currentRoom!.members.any((m) => m.userId == user.id);
      if (alreadyMember) return true;
      if (_currentRoom!.isFull) return false;
      final newMember = RoomMemberModel(
        id: _uuid.v4(),
        userId: user.id,
        username: user.username,
        avatarUrl: user.avatarUrl,
        isHost: false,
        isReady: true,
        phase: _currentRoom!.phase.name,
        joinedAt: DateTime.now(),
      );
      _currentRoom = _currentRoom!.copyWith(
        members: [..._currentRoom!.members, newMember],
      );
      notifyListeners();
      return true;
    }

    // Si no coincide o no existe sala activa local, crear/simular la sala para unirse
    final now = DateTime.now();
    if (_currentRoom == null || _currentRoom!.code != cleanCode) {
      // Simular anfitrión existente para unirse
      final hostMember = RoomMemberModel(
        id: _uuid.v4(),
        userId: 'host_mateo',
        username: 'Mateo (Host)',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        isHost: true,
        isReady: true,
        phase: 'lobby',
        joinedAt: now.subtract(const Duration(minutes: 2)),
      );

      final newMember = RoomMemberModel(
        id: _uuid.v4(),
        userId: user.id,
        username: user.username,
        avatarUrl: user.avatarUrl,
        isHost: false,
        isReady: true,
        phase: 'lobby',
        joinedAt: now,
      );

      _currentRoom = RoomModel(
        id: _uuid.v4(),
        code: cleanCode,
        hostId: hostMember.userId,
        hostUsername: hostMember.username,
        maxMembers: 5,
        matchThreshold: 2,
        status: RoomStatus.waiting,
        phase: RoomPhase.lobby,
        members: [hostMember, newMember],
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 30)),
      );

      notifyListeners();
      return true;
    }

    // Si la sala ya existe y no está llena, agregar al usuario
    if (_currentRoom!.isFull) {
      return false;
    }

    final alreadyMember = _currentRoom!.members.any((m) => m.userId == user.id);
    if (!alreadyMember) {
      final newMember = RoomMemberModel(
        id: _uuid.v4(),
        userId: user.id,
        username: user.username,
        avatarUrl: user.avatarUrl,
        isHost: false,
        isReady: true,
        phase: _currentRoom!.phase.name,
        joinedAt: now,
      );

      _currentRoom = _currentRoom!.copyWith(
        members: [..._currentRoom!.members, newMember],
      );
      notifyListeners();
    }

    return true;
  }

  /// Añadir un amigo simulado a la sala (Ideal para probar la experiencia multiplayer)
  void addSimulatedFriend([String? name]) {
    if (_currentRoom == null || _currentRoom!.isFull) return;

    final names = ['Lucía', 'Tomás', 'Valeria', 'Andrés', 'Sofía'];
    final avatars = [
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
    ];

    final rnd = Random();
    final friendName = name ?? names[rnd.nextInt(names.length)];
    final friendAvatar = avatars[rnd.nextInt(avatars.length)];

    final friend = RoomMemberModel(
      id: _uuid.v4(),
      userId: 'sim_${_uuid.v4().substring(0, 6)}',
      username: friendName,
      avatarUrl: friendAvatar,
      isHost: false,
      isReady: true,
      phase: _currentRoom!.phase.name,
      joinedAt: DateTime.now(),
    );

    _currentRoom = _currentRoom!.copyWith(
      members: [..._currentRoom!.members, friend],
    );
    notifyListeners();
  }

  /// Anfitrión inicia la Fase 1: Categorías
  void startPhase1Categories() {
    if (_currentRoom == null) return;

    _currentRoom = _currentRoom!.copyWith(
      status: RoomStatus.categories,
      phase: RoomPhase.categories,
    );
    notifyListeners();
  }

  /// Registrar voto de categoría de un usuario
  void castCategoryVote({
    required String userId,
    required int genreId,
    required bool approved,
    required List<GenreModel> allAvailableGenres,
  }) {
    if (_currentRoom == null) return;

    // Actualizar voto del usuario
    final updatedMembers = _currentRoom!.members.map((member) {
      if (member.userId == userId) {
        final updatedVotes = Map<int, bool>.from(member.categoryVotes);
        updatedVotes[genreId] = approved;
        return member.copyWith(categoryVotes: updatedVotes);
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(members: updatedMembers);

    // Simular votos de los otros participantes si no han votado
    _simulateOtherMembersCategoryVotes(userId, genreId, allAvailableGenres);

    // Verificar si se alcanzó el threshold de coincidencia
    _checkCategoryMatching(allAvailableGenres);
    notifyListeners();
  }

  void _simulateOtherMembersCategoryVotes(String currentUserId, int genreId, List<GenreModel> allGenres) {
    if (_currentRoom == null) return;
    final rnd = Random();

    final updatedMembers = _currentRoom!.members.map((member) {
      // Cualquier otro participante en la sala que no haya votado aún
      if (member.userId != currentUserId) {
        if (!member.categoryVotes.containsKey(genreId)) {
          final updatedVotes = Map<int, bool>.from(member.categoryVotes);
          // Alta probabilidad de coincidencia en géneros principales para avanzar fluidamente
          final isPopular = [28, 35, 27, 878, 18, 12, 16].contains(genreId);
          updatedVotes[genreId] = isPopular ? (rnd.nextDouble() < 0.85) : (rnd.nextDouble() < 0.5);
          return member.copyWith(categoryVotes: updatedVotes);
        }
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
  }

  /// Evaluar coincidencia de categorías entre todos los miembros
  void _checkCategoryMatching(List<GenreModel> allGenres) {
    if (_currentRoom == null) return;

    final members = _currentRoom!.members;
    if (members.length < 2) return;

    // Encontrar categorías aprobadas por TODOS los miembros
    List<GenreModel> matched = [];
    for (final genre in allGenres) {
      final allApproved = members.every((m) => m.categoryVotes[genre.id] == true);
      if (allApproved) {
        matched.add(genre);
      }
    }

    // Si alcanzamos el matchThreshold de categorías configurado
    if (matched.length >= _currentRoom!.matchThreshold) {
      _currentRoom = _currentRoom!.copyWith(
        matchedCategories: matched,
        status: RoomStatus.categories,
        phase: RoomPhase.categoryMatch,
      );
    }
  }

  /// Forzar avance a celebración de categorías (en caso de agotar baraja)
  void forceAdvanceToMoviesPhase(List<GenreModel> fallbackCategories) {
    if (_currentRoom == null) return;

    final cats = _currentRoom!.matchedCategories.isNotEmpty
        ? _currentRoom!.matchedCategories
        : (fallbackCategories.isNotEmpty ? fallbackCategories.take(2).toList() : GenreModel.defaultGenres.take(2).toList());

    _currentRoom = _currentRoom!.copyWith(
      matchedCategories: cats,
      status: RoomStatus.categories,
      phase: RoomPhase.categoryMatch,
    );
    notifyListeners();
  }

  /// Avanzar de la celebración de categorías a la Fase 2: Películas
  void advanceToMoviesPhase() {
    if (_currentRoom == null) return;

    _currentRoom = _currentRoom!.copyWith(
      status: RoomStatus.movies,
      phase: RoomPhase.movies,
    );
    notifyListeners();
  }

  /// Registrar voto de película de un usuario en Fase 2
  void castMovieVote({
    required String userId,
    required MovieModel movie,
    required bool approved,
    required List<MovieModel> roomDeck,
  }) {
    if (_currentRoom == null) return;

    final updatedMembers = _currentRoom!.members.map((member) {
      if (member.userId == userId) {
        final updatedVotes = Map<int, bool>.from(member.movieVotes);
        updatedVotes[movie.id] = approved;
        return member.copyWith(movieVotes: updatedVotes);
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(members: updatedMembers);

    // Simular respuesta de otros miembros para esta película
    _simulateOtherMembersMovieVote(userId, movie.id);

    // Verificar si TODOS aprobaron esta película -> MATCH!
    _checkMovieConsensus(movie, roomDeck);
    notifyListeners();
  }

  void _simulateOtherMembersMovieVote(String currentUserId, int movieId) {
    if (_currentRoom == null) return;
    final rnd = Random();

    final updatedMembers = _currentRoom!.members.map((member) {
      if (member.userId != currentUserId) {
        if (!member.movieVotes.containsKey(movieId)) {
          final updatedVotes = Map<int, bool>.from(member.movieVotes);
          // Alta probabilidad de coincidencia para hacer la experiencia emocionante y rápida
          updatedVotes[movieId] = rnd.nextDouble() < 0.70;
          return member.copyWith(movieVotes: updatedVotes);
        }
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
  }

  /// Verificar si todos los miembros aprobaron la misma película
  void _checkMovieConsensus(MovieModel currentMovie, List<MovieModel> roomDeck) {
    if (_currentRoom == null) return;
    final members = _currentRoom!.members;

    // Verificar si TODOS votaron 'true' para currentMovie
    final allApprovedCurrent = members.every((m) => m.movieVotes[currentMovie.id] == true);
    if (allApprovedCurrent) {
      _currentRoom = _currentRoom!.copyWith(
        matchedMovie: currentMovie,
        isRandomizerResult: false,
        status: RoomStatus.completed,
        phase: RoomPhase.result,
      );
      return;
    }

    // Verificar si se agotó la baraja para todos
    final allVotedAllMovies = members.every(
      (m) => roomDeck.every((movie) => m.movieVotes.containsKey(movie.id)),
    );

    if (allVotedAllMovies) {
      // Activar Randomizer Fallback!
      triggerRandomizerFallback(roomDeck);
    }
  }

  /// Fallback Randomizer: Selecciona al azar una película de las categorías coincidentes
  void triggerRandomizerFallback(List<MovieModel> candidates) {
    if (_currentRoom == null) return;

    final pool = candidates.isNotEmpty ? candidates : MockMoviesData.sampleMovies;
    final rnd = Random();
    final chosen = pool[rnd.nextInt(pool.length)];

    _currentRoom = _currentRoom!.copyWith(
      matchedMovie: chosen,
      isRandomizerResult: true,
      status: RoomStatus.completed,
      phase: RoomPhase.result,
    );
    notifyListeners();
  }

  /// Salir o destruir la sala
  void leaveRoom() {
    _expirationTimer?.cancel();
    _currentRoom = null;
    notifyListeners();
  }
}
