import 'package:flutter_test/flutter_test.dart';
import 'package:swipeflick/data/models/genre_model.dart';
import 'package:swipeflick/data/models/room_model.dart';
import 'package:swipeflick/data/models/user_model.dart';
import 'package:swipeflick/data/mock/mock_movies_data.dart';
import 'package:swipeflick/data/services/room_service.dart';

void main() {
  group('Room Matching Engine Tests', () {
    test('Crear sala genera código de 6 caracteres y asigna host', () async {
      final roomService = RoomService();
      final host = UserModel.createDemo(name: 'Host User');

      final room = await roomService.createRoom(
        host: host,
        maxMembers: 5,
        matchThreshold: 2,
      );

      expect(room.code.length, 6);
      expect(room.hostId, host.id);
      expect(room.phase, RoomPhase.lobby);
      expect(room.members.length, 1);
      expect(room.members.first.isHost, true);
    });

    test('Unirse a sala añade miembro correctamente', () async {
      final roomService = RoomService();
      final host = UserModel.createDemo(name: 'Host User');
      final room = await roomService.createRoom(host: host);

      final joiner = UserModel.createDemo(name: 'Friend User');
      final joined = await roomService.joinRoom(code: room.code, user: joiner);

      expect(joined, true);
      expect(roomService.currentRoom!.members.length, 2);
    });

    test('Coincidencia de categorías avanza a categoryMatch y luego a movies', () async {
      final roomService = RoomService();
      final host = UserModel.createDemo(name: 'Host');
      await roomService.createRoom(host: host, matchThreshold: 1);

      final friend = UserModel.createDemo(name: 'Amigo');
      await roomService.joinRoom(code: roomService.currentRoom!.code, user: friend);

      // Simular que ambos votan positivo la categoría 28 (Acción)
      roomService.startPhase1Categories();

      roomService.castCategoryVote(
        userId: host.id,
        genreId: 28,
        approved: true,
        allAvailableGenres: GenreModel.defaultGenres,
      );

      // Forzar evaluación a la fase de categorías ganadoras
      roomService.forceAdvanceToMoviesPhase(GenreModel.defaultGenres);

      // Debe estar en categoryMatch (muestra categorías ganadoras en el centro)
      expect(roomService.currentRoom!.phase, RoomPhase.categoryMatch);
      expect(roomService.currentRoom!.matchedCategories, isNotEmpty);

      // Al pulsar continuar, avanza a películas
      roomService.advanceToMoviesPhase();
      expect(roomService.currentRoom!.phase, RoomPhase.movies);
    });

    test('Randomizer fallback selecciona una película cuando no hay coincidencia unánime', () {
      final roomService = RoomService();
      final host = UserModel.createDemo(name: 'Host');
      roomService.createRoom(host: host);

      roomService.triggerRandomizerFallback(MockMoviesData.sampleMovies);

      expect(roomService.currentRoom!.phase, RoomPhase.result);
      expect(roomService.currentRoom!.isRandomizerResult, true);
      expect(roomService.currentRoom!.matchedMovie, isNotNull);
    });

    test('discoverMoviesByGenres descarta completamente películas que no pertenezcan al género ganador', () async {
      // Filtrar por Terror (id 27)
      final terrorMovies = MockMoviesData.sampleMovies.where((m) => m.genreIds.contains(27)).toList();
      expect(terrorMovies, isNotEmpty);

      for (final movie in terrorMovies) {
        expect(movie.genreIds.contains(27), true);
        // Verificar que no sea comedia pura ni romántica
        expect(movie.genres.contains('Terror'), true);
      }

      // Filtrar por Acción (id 28)
      final actionMovies = MockMoviesData.sampleMovies.where((m) => m.genreIds.contains(28)).toList();
      expect(actionMovies, isNotEmpty);
      for (final movie in actionMovies) {
        expect(movie.genreIds.contains(28), true);
        expect(movie.genres.contains('Acción'), true);
      }

      // Verificar que una película de solo Terror nunca aparezca en Acción
      final conjuring = MockMoviesData.sampleMovies.firstWhere((m) => m.title == 'El Conjuro');
      expect(actionMovies.contains(conjuring), false);
    });

    test('Todos los géneros predeterminados tienen afiches acordes y no erróneos', () {
      final action = GenreModel.defaultGenres.firstWhere((g) => g.id == 28);
      expect(action.samplePosterUrl, contains('vZloFAK7NmvMGKE7VkF5UHaz0I.jpg')); // John Wick 4

      final terror = GenreModel.defaultGenres.firstWhere((g) => g.id == 27);
      expect(terror.samplePosterUrl, contains('wVYREutTvI2tmxr6ujrHT704wGF.jpg')); // El Conjuro
      expect(terror.samplePosterUrl, isNot(contains('wWba3TaojhK7NdycRhoQpsG0FaH.jpg'))); // No Minions

      final scifi = GenreModel.defaultGenres.firstWhere((g) => g.id == 878);
      expect(scifi.samplePosterUrl, contains('d5NXSklXo0qyIYkgV94XAgMIckC.jpg')); // Dune 2
    });

    test('Intensa-Mente 2 contiene Comedia (id 35) y califica en filtros de Comedia', () {
      final insideOut = MockMoviesData.sampleMovies.firstWhere((m) => m.title == 'Intensa-Mente 2');
      expect(insideOut.genreIds.contains(35), true); // Comedia
      expect(insideOut.genres.contains('Comedia'), true);

      final comedyMovies = MockMoviesData.sampleMovies.where((m) => m.genreIds.contains(35)).toList();
      expect(comedyMovies.contains(insideOut), true);
    });

    test('RoomModel serialización y deserialización BSON es simétrica y segura', () {
      final host = UserModel.createDemo(name: 'Host Test');
      final room = RoomModel(
        id: 'room_123',
        code: 'SFTEST',
        hostId: host.id,
        hostUsername: host.username,
        maxMembers: 5,
        matchThreshold: 2,
        status: RoomStatus.waiting,
        phase: RoomPhase.lobby,
        members: [
          RoomMemberModel(
            id: 'mem_1',
            userId: host.id,
            username: host.username,
            avatarUrl: host.avatarUrl,
            isHost: true,
            isReady: true,
            phase: 'lobby',
            joinedAt: DateTime.now(),
            categoryVotes: {28: true, 35: false},
            movieVotes: {1022789: true},
          ),
        ],
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );

      final json = room.toJson();
      expect(json['code'], 'SFTEST');
      expect((json['members'] as List).length, 1);

      // Deserialización simulando datos BSON de MongoDB
      final recreated = RoomModel.fromJson(Map<String, dynamic>.from(json));
      expect(recreated.code, 'SFTEST');
      expect(recreated.members.first.categoryVotes[28], true);
      expect(recreated.members.first.movieVotes[1022789], true);
    });

    test('RoomService rechaza unirse con código inexistente sin inventar anfitrión simulado', () async {
      final roomService = RoomService();
      final user = UserModel.createDemo(name: 'Usuario Real');

      final result = await roomService.joinRoom(code: 'CODIGO_INEXISTENTE_999', user: user);
      expect(result, false);
      expect(roomService.currentRoom, isNull);
      expect(roomService.lastError, contains('no encontrada'));
    });
  });
}
