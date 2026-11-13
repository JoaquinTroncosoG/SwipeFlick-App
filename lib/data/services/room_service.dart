import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/genre_model.dart';
import '../models/movie_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../mock/mock_movies_data.dart';
import 'mongodb_service.dart';

class RoomService extends ChangeNotifier {
  RoomModel? _currentRoom;
  final Uuid _uuid = const Uuid();
  Timer? _expirationTimer;
  Timer? _syncTimer;
  MongoDbService? _mongoService;
  String? _lastError;

  RoomModel? get currentRoom => _currentRoom;
  bool get isInRoom => _currentRoom != null;
  String? get lastError => _lastError;

  /// Conecta el servicio con MongoDB Atlas para persistencia y sincronización en tiempo real
  void attachMongoDb(MongoDbService mongo) {
    _mongoService = mongo;
  }

  /// Generar código alfanumérico único de 6 caracteres (ej: SF89K2)
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Inicia el polling de sincronización en tiempo real desde MongoDB Atlas
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _syncFromDatabase();
    });
  }

  /// Sincroniza el estado más reciente de la sala desde MongoDB Atlas
  Future<void> _syncFromDatabase() async {
    if (_currentRoom == null || _mongoService == null) return;
    try {
      final remoteRoom = await _mongoService!.getRoomByCode(_currentRoom!.code);
      if (remoteRoom == null) return;

      bool hasChanges = false;
      if (remoteRoom.members.length != _currentRoom!.members.length ||
          remoteRoom.phase != _currentRoom!.phase ||
          remoteRoom.status != _currentRoom!.status ||
          remoteRoom.matchedCategories.length != _currentRoom!.matchedCategories.length ||
          remoteRoom.matchedMovie?.id != _currentRoom!.matchedMovie?.id) {
        hasChanges = true;
      } else {
        // Verificar si algún participante actualizó votos
        for (final rm in remoteRoom.members) {
          final lm = _currentRoom!.members.firstWhere(
            (m) => m.userId == rm.userId,
            orElse: () => rm,
          );
          if (rm.categoryVotes.length != lm.categoryVotes.length ||
              rm.movieVotes.length != lm.movieVotes.length) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        _currentRoom = remoteRoom;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[RoomService] Error al sincronizar sala desde Atlas: $e');
    }
  }

  /// Crear una nueva sala en MongoDB Atlas
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

    // Guardar en MongoDB Atlas
    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    _startSyncTimer();
    notifyListeners();
    return _currentRoom!;
  }

  /// Unirse a sala real por código consultando MongoDB Atlas
  Future<bool> joinRoom({
    required String code,
    required UserModel user,
  }) async {
    _lastError = null;
    final cleanCode = code.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      _lastError = 'El código no puede estar vacío.';
      return false;
    }

    // 1. Si hay servicio de MongoDB Atlas conectado, consultar la sala real en la nube
    if (_mongoService != null) {
      await _mongoService!.ensureConnected();
      final remoteRoom = await _mongoService!.getRoomByCode(cleanCode);

      if (remoteRoom == null) {
        _lastError = 'No se encontró ninguna sala con el código "$cleanCode". Verifica que el host haya creado la sala.';
        notifyListeners();
        return false;
      }

      if (remoteRoom.isFull) {
        final alreadyIn = remoteRoom.members.any((m) => m.userId == user.id);
        if (!alreadyIn) {
          _lastError = 'La sala "$cleanCode" ya alcanzó su capacidad máxima (${remoteRoom.maxMembers} participantes).';
          notifyListeners();
          return false;
        }
      }

      // Si el usuario ya estaba en la sala, simplemente reanudar
      final existingIndex = remoteRoom.members.indexWhere((m) => m.userId == user.id);
      if (existingIndex >= 0) {
        _currentRoom = remoteRoom;
        _startSyncTimer();
        notifyListeners();
        return true;
      }

      // Añadir al nuevo miembro a la sala real
      final newMember = RoomMemberModel(
        id: _uuid.v4(),
        userId: user.id,
        username: user.username,
        avatarUrl: user.avatarUrl,
        isHost: false,
        isReady: true,
        phase: remoteRoom.phase.name,
        joinedAt: DateTime.now(),
      );

      final updatedRoom = remoteRoom.copyWith(
        members: [...remoteRoom.members, newMember],
      );

      final saved = await _mongoService!.saveRoom(updatedRoom);
      if (!saved) {
        _lastError = 'Error de conexión al unirse a la sala en la nube.';
        notifyListeners();
        return false;
      }

      _currentRoom = updatedRoom;
      _startSyncTimer();
      notifyListeners();
      return true;
    }

    // 2. Modo local o pruebas unitarias (sin MongoDB activo)
    if (_currentRoom != null && _currentRoom!.code == cleanCode) {
      final alreadyMember = _currentRoom!.members.any((m) => m.userId == user.id);
      if (alreadyMember) return true;
      if (_currentRoom!.isFull) {
        _lastError = 'La sala está llena.';
        return false;
      }
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

    _lastError = 'Sala "$cleanCode" no encontrada.';
    notifyListeners();
    return false;
  }

  /// Anfitrión inicia la Fase 1: Categorías
  Future<void> startPhase1Categories() async {
    if (_currentRoom == null) return;

    _currentRoom = _currentRoom!.copyWith(
      status: RoomStatus.categories,
      phase: RoomPhase.categories,
    );

    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    notifyListeners();
  }

  /// Registrar voto real de categoría de un usuario
  Future<void> castCategoryVote({
    required String userId,
    required int genreId,
    required bool approved,
    required List<GenreModel> allAvailableGenres,
  }) async {
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

    // Evaluar si se alcanzó la meta de categorías entre los miembros conectados
    _checkCategoryMatching(allAvailableGenres);

    // Guardar en Atlas para que el resto de participantes lo reciba
    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    notifyListeners();
  }

  /// Evaluar coincidencia de categorías entre todos los miembros
  void _checkCategoryMatching(List<GenreModel> allGenres) {
    if (_currentRoom == null) return;

    final members = _currentRoom!.members;
    if (members.length < 2) return;

    // Encontrar categorías aprobadas por TODOS los miembros reales
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
  Future<void> forceAdvanceToMoviesPhase(List<GenreModel> fallbackCategories) async {
    if (_currentRoom == null) return;

    final cats = _currentRoom!.matchedCategories.isNotEmpty
        ? _currentRoom!.matchedCategories
        : (fallbackCategories.isNotEmpty ? fallbackCategories.take(2).toList() : GenreModel.defaultGenres.take(2).toList());

    _currentRoom = _currentRoom!.copyWith(
      matchedCategories: cats,
      status: RoomStatus.categories,
      phase: RoomPhase.categoryMatch,
    );

    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    notifyListeners();
  }

  /// Avanzar de la celebración de categorías a la Fase 2: Películas
  Future<void> advanceToMoviesPhase() async {
    if (_currentRoom == null) return;

    _currentRoom = _currentRoom!.copyWith(
      status: RoomStatus.movies,
      phase: RoomPhase.movies,
    );

    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    notifyListeners();
  }

  /// Registrar voto real de película de un usuario en Fase 2
  Future<void> castMovieVote({
    required String userId,
    required MovieModel movie,
    required bool approved,
    required List<MovieModel> roomDeck,
  }) async {
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

    // Verificar si TODOS los miembros aprobaron esta película -> MATCH!
    _checkMovieConsensus(movie, roomDeck);

    // Guardar en Atlas
    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    notifyListeners();
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
  Future<void> triggerRandomizerFallback(List<MovieModel> candidates) async {
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

    if (_mongoService != null) {
      await _mongoService!.saveRoom(_currentRoom!);
    }

    notifyListeners();
  }

  /// Salir o destruir la sala
  void leaveRoom() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _expirationTimer?.cancel();
    _expirationTimer = null;
    _currentRoom = null;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}
