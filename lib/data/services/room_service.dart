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
  bool _wasRoomClosedByHost = false;

  RoomModel? get currentRoom => _currentRoom;
  bool get isInRoom => _currentRoom != null;
  String? get lastError => _lastError;
  bool get wasRoomClosedByHost => _wasRoomClosedByHost;

  void resetRoomClosedFlag() {
    _wasRoomClosedByHost = false;
  }

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

  /// Inicia el polling de sincronización en tiempo real desde MongoDB Atlas (cada 1500 ms)
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      await _syncFromDatabase();
    });
  }

  /// Sincroniza el estado más reciente de la sala desde MongoDB Atlas y evalúa coincidencias
  Future<void> _syncFromDatabase() async {
    if (_currentRoom == null || _mongoService == null) return;
    try {
      final remoteRoom = await _mongoService!.getRoomByCode(_currentRoom!.code);
      if (remoteRoom == null || remoteRoom.status == RoomStatus.closed) {
        debugPrint('[RoomService] Sala cerrada por el anfitrión o no encontrada en Atlas.');
        _syncTimer?.cancel();
        _syncTimer = null;
        _expirationTimer?.cancel();
        _expirationTimer = null;
        _currentRoom = null;
        _wasRoomClosedByHost = true;
        notifyListeners();
        return;
      }

      // Fusionar categoryLikes (likes locales + likes remotos de Atlas)
      final mergedCategoryLikes = Map<int, List<String>>.from(remoteRoom.categoryLikes);
      _currentRoom!.categoryLikes.forEach((genreId, localLikers) {
        final existing = mergedCategoryLikes[genreId] ?? [];
        final set = {...existing, ...localLikers};
        mergedCategoryLikes[genreId] = set.toList();
      });

      // Fusionar movieLikes (likes locales + likes remotos de Atlas)
      final mergedMovieLikes = Map<int, List<String>>.from(remoteRoom.movieLikes);
      _currentRoom!.movieLikes.forEach((movieId, localLikers) {
        final existing = mergedMovieLikes[movieId] ?? [];
        final set = {...existing, ...localLikers};
        mergedMovieLikes[movieId] = set.toList();
      });

      bool hasChanges = remoteRoom.phase != _currentRoom!.phase ||
          remoteRoom.status != _currentRoom!.status ||
          remoteRoom.members.length != _currentRoom!.members.length ||
          remoteRoom.matchedCategories.length != _currentRoom!.matchedCategories.length ||
          remoteRoom.matchedMovie?.id != _currentRoom!.matchedMovie?.id ||
          mergedCategoryLikes.toString() != _currentRoom!.categoryLikes.toString() ||
          mergedMovieLikes.toString() != _currentRoom!.movieLikes.toString();

      _currentRoom = remoteRoom.copyWith(
        categoryLikes: mergedCategoryLikes,
        movieLikes: mergedMovieLikes,
        movieDeck: remoteRoom.movieDeck.isNotEmpty ? remoteRoom.movieDeck : _currentRoom!.movieDeck,
      );

      // Evaluar consensos con los nuevos votos sincronizados desde Atlas
      if (_currentRoom!.phase == RoomPhase.categories) {
        _evaluateCategoryConsensus(GenreModel.defaultGenres);
      } else if (_currentRoom!.phase == RoomPhase.movies && _currentRoom!.movieDeck.isNotEmpty) {
        _evaluateMovieConsensus(_currentRoom!.movieDeck);
      }

      if (hasChanges) {
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
      await _mongoService!.updateRoomPhase(
        roomCode: _currentRoom!.code,
        phase: RoomPhase.categories,
      );
    }

    notifyListeners();
  }

  /// Guarda y sincroniza la baraja compartida de películas para todos los participantes
  Future<void> setRoomMovieDeck(List<MovieModel> deck) async {
    if (_currentRoom == null || deck.isEmpty) return;
    _currentRoom = _currentRoom!.copyWith(movieDeck: deck);
    if (_mongoService != null) {
      await _mongoService!.setRoomMovieDeck(
        roomCode: _currentRoom!.code,
        deck: deck,
      );
    }
    notifyListeners();
  }

  /// Registrar voto real de categoría de un usuario (Atómico en Atlas)
  Future<void> castCategoryVote({
    required String userId,
    required int genreId,
    required bool approved,
    required List<GenreModel> allAvailableGenres,
  }) async {
    if (_currentRoom == null) return;

    // 1. Actualizar mapa local de categoryLikes
    final updatedCategoryLikes = Map<int, List<String>>.from(_currentRoom!.categoryLikes);
    final currentLikes = List<String>.from(updatedCategoryLikes[genreId] ?? []);
    if (approved) {
      if (!currentLikes.contains(userId)) currentLikes.add(userId);
    } else {
      currentLikes.remove(userId);
    }
    updatedCategoryLikes[genreId] = currentLikes;

    // Actualizar también en el miembro
    final updatedMembers = _currentRoom!.members.map((member) {
      if (member.userId == userId) {
        final updatedVotes = Map<int, bool>.from(member.categoryVotes);
        updatedVotes[genreId] = approved;
        return member.copyWith(categoryVotes: updatedVotes);
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(
      categoryLikes: updatedCategoryLikes,
      members: updatedMembers,
    );

    // 2. Enviar actualización atómica a MongoDB Atlas sin sobreescribir otros miembros
    if (_mongoService != null) {
      _mongoService!.castRoomCategoryVote(
        roomCode: _currentRoom!.code,
        userId: userId,
        genreId: genreId,
        approved: approved,
      );
    }

    // 3. Evaluar si se alcanzó la meta de categorías coincidentes
    _evaluateCategoryConsensus(allAvailableGenres);

    notifyListeners();
  }

  /// Evaluar coincidencia de categorías entre todos los miembros
  void _evaluateCategoryConsensus(List<GenreModel> allGenres) {
    if (_currentRoom == null) return;
    if (_currentRoom!.phase != RoomPhase.categories) return;

    final members = _currentRoom!.members;
    if (members.length < 2) return;

    final memberIds = members.map((m) => m.userId).toSet();
    final matched = <GenreModel>[];

    for (final genre in allGenres) {
      // Verificar si el género fue aprobado en categoryLikes por todos los participantes
      final likers = _currentRoom!.categoryLikes[genre.id] ?? [];
      final likersSet = likers.toSet();

      // Compatibilidad con member.categoryVotes
      final allApprovedInMembers = members.every((m) => m.categoryVotes[genre.id] == true);
      final allApprovedInLikes = memberIds.every((id) => likersSet.contains(id));

      if (allApprovedInLikes || allApprovedInMembers) {
        matched.add(genre);
      }
    }

    // Si alcanzamos el matchThreshold de categorías configurado
    if (matched.length >= _currentRoom!.matchThreshold) {
      debugPrint('[RoomService] ¡COINCIDENCIA DE CATEGORÍAS ALCANZADA! (${matched.length}): ${matched.map((g) => g.name).join(", ")}');
      _currentRoom = _currentRoom!.copyWith(
        matchedCategories: matched,
        status: RoomStatus.categories,
        phase: RoomPhase.categoryMatch,
      );

      if (_mongoService != null) {
        _mongoService!.updateRoomPhase(
          roomCode: _currentRoom!.code,
          phase: RoomPhase.categoryMatch,
          matchedCategories: matched,
        );
      }
      notifyListeners();
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
      await _mongoService!.updateRoomPhase(
        roomCode: _currentRoom!.code,
        phase: RoomPhase.categoryMatch,
        matchedCategories: cats,
      );
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
      await _mongoService!.updateRoomPhase(
        roomCode: _currentRoom!.code,
        phase: RoomPhase.movies,
      );
    }

    notifyListeners();
  }

  /// Registrar voto real de película de un usuario en Fase 2 (Atómico en Atlas)
  Future<void> castMovieVote({
    required String userId,
    required MovieModel movie,
    required bool approved,
    required List<MovieModel> roomDeck,
  }) async {
    if (_currentRoom == null) return;

    // 1. Actualizar mapa local de movieLikes
    final updatedMovieLikes = Map<int, List<String>>.from(_currentRoom!.movieLikes);
    final currentLikes = List<String>.from(updatedMovieLikes[movie.id] ?? []);
    if (approved) {
      if (!currentLikes.contains(userId)) currentLikes.add(userId);
    } else {
      currentLikes.remove(userId);
    }
    updatedMovieLikes[movie.id] = currentLikes;

    final updatedMembers = _currentRoom!.members.map((member) {
      if (member.userId == userId) {
        final updatedVotes = Map<int, bool>.from(member.movieVotes);
        updatedVotes[movie.id] = approved;
        return member.copyWith(movieVotes: updatedVotes);
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(
      movieLikes: updatedMovieLikes,
      members: updatedMembers,
    );

    // 2. Registrar atómicamente en Atlas sin colisiones
    if (_mongoService != null) {
      _mongoService!.castRoomMovieVote(
        roomCode: _currentRoom!.code,
        userId: userId,
        movieId: movie.id,
        approved: approved,
      );
    }

    // 3. Evaluar si todos los miembros aprobaron esta película
    _evaluateMovieConsensus(roomDeck);

    notifyListeners();
  }

  /// Verificar si todos los miembros aprobaron la misma película
  void _evaluateMovieConsensus(List<MovieModel> roomDeck) {
    if (_currentRoom == null) return;
    if (_currentRoom!.phase != RoomPhase.movies) return;

    final members = _currentRoom!.members;
    if (members.length < 2) return;

    final memberIds = members.map((m) => m.userId).toSet();

    // 1. Comprobar si TODOS los miembros dieron like a alguna película
    for (final movie in roomDeck) {
      final likers = _currentRoom!.movieLikes[movie.id] ?? [];
      final likersSet = likers.toSet();

      final allApprovedInLikes = memberIds.every((id) => likersSet.contains(id));
      final allApprovedInMembers = members.every((m) => m.movieVotes[movie.id] == true);

      if (allApprovedInLikes || allApprovedInMembers) {
        debugPrint('[RoomService] ¡MATCH UNÁNIME DE PELÍCULA ENCONTRADO! ${movie.title}');
        _currentRoom = _currentRoom!.copyWith(
          matchedMovie: movie,
          isRandomizerResult: false,
          status: RoomStatus.completed,
          phase: RoomPhase.result,
        );

        if (_mongoService != null) {
          _mongoService!.updateRoomPhase(
            roomCode: _currentRoom!.code,
            phase: RoomPhase.result,
            matchedMovie: movie,
            isRandomizer: false,
          );
        }
        notifyListeners();
        return;
      }
    }

    // 2. Si todos los miembros votaron todas las películas del deck y no hubo coincidencia, fallback
    final allVotedAllMovies = members.every(
      (m) => roomDeck.every((movie) => m.movieVotes.containsKey(movie.id)),
    );

    if (allVotedAllMovies) {
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
      await _mongoService!.updateRoomPhase(
        roomCode: _currentRoom!.code,
        phase: RoomPhase.result,
        matchedMovie: chosen,
        isRandomizer: true,
      );
    }

    notifyListeners();
  }

  /// Salir o destruir la sala grupal sincronizando en MongoDB Atlas
  Future<void> leaveRoom({String? userId, bool isHost = false}) async {
    final room = _currentRoom;
    _syncTimer?.cancel();
    _syncTimer = null;
    _expirationTimer?.cancel();
    _expirationTimer = null;
    _currentRoom = null;
    _lastError = null;

    if (room != null && _mongoService != null) {
      try {
        final hostLeaving = isHost || (userId != null && room.hostId == userId);
        if (hostLeaving) {
          debugPrint('[RoomService] El anfitrión cerró la sala ${room.code}');
          await _mongoService!.closeRoom(room.code);
        } else if (userId != null) {
          debugPrint('[RoomService] Participante $userId abandonó la sala ${room.code}');
          await _mongoService!.removeMemberFromRoom(
            roomCode: room.code,
            userId: userId,
          );
        }
      } catch (e) {
        debugPrint('[RoomService] Error al notificar salida a MongoDB: $e');
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}
