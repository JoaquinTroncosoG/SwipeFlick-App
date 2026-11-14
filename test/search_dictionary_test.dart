import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipeflick/core/constants/app_constants.dart';
import 'package:swipeflick/core/utils/search_dictionary_helper.dart';
import 'package:swipeflick/core/utils/security_helper.dart';
import 'package:swipeflick/data/mock/mock_movies_data.dart';
import 'package:swipeflick/core/widgets/cinema_snackbar.dart';
import 'package:swipeflick/data/models/genre_model.dart';
import 'package:swipeflick/data/models/movie_model.dart';
import 'package:swipeflick/data/models/review_model.dart';
import 'package:swipeflick/data/models/room_model.dart';
import 'package:swipeflick/data/services/favorites_service.dart';
import 'package:swipeflick/data/services/tmdb_service.dart';
import 'package:swipeflick/data/models/user_model.dart';
import 'package:swipeflick/data/services/auth_service.dart';
import 'package:swipeflick/data/services/brevo_email_service.dart';
import 'package:swipeflick/data/services/mongodb_service.dart';
import 'package:swipeflick/data/services/rate_limit_service.dart';

void main() {
  group('SearchDictionaryHelper & Version Tracking Tests', () {
    test('Control de versión y contador de cambios actualizado', () {
      expect(AppConstants.appVersion, '1.22.0');
      expect(AppConstants.changeCounter, 23);
      expect(AppConstants.appVersionDisplay, contains('v1.22.0'));
      expect(AppConstants.appVersionDisplay, contains('Cambio #23'));
      expect(AppConstants.changeLog.length, 24);
    });

    test('Normalización diacrítica elimina tildes y diacríticos correctamente', () {
      expect(SearchDictionaryHelper.normalize('Acción'), 'accion');
      expect(SearchDictionaryHelper.normalize('CIENCIA FICCIÓN'), 'ciencia ficcion');
      expect(SearchDictionaryHelper.normalize('Parásitos'), 'parasitos');
      expect(SearchDictionaryHelper.normalize('Sueños de Fuga'), 'suenos de fuga');
      expect(SearchDictionaryHelper.normalize('Fantasía'), 'fantasia');
      expect(SearchDictionaryHelper.normalize('Animación'), 'animacion');
    });

    test('Búsqueda por género sin tilde ("accion") encuentra el género de Acción', () {
      final ids = SearchDictionaryHelper.matchGenreIds('accion');
      expect(ids.contains(28), true);

      final detected = SearchDictionaryHelper.detectGenre('accion');
      expect(detected, isNotNull);
      expect(detected!.id, 28);
      expect(detected.name, 'Acción');
    });

    test('Sinónimos populares coinciden con su género respectivo', () {
      // Disparos / Tiros -> Acción (28)
      expect(SearchDictionaryHelper.matchGenreIds('tiros').contains(28), true);
      expect(SearchDictionaryHelper.matchGenreIds('disparos').contains(28), true);

      // Miedo / Sustos -> Terror (27)
      expect(SearchDictionaryHelper.matchGenreIds('miedo').contains(27), true);
      expect(SearchDictionaryHelper.matchGenreIds('sustos').contains(27), true);

      // Dibujos / Caricaturas -> Animación (16)
      expect(SearchDictionaryHelper.matchGenreIds('dibujos').contains(16), true);
      expect(SearchDictionaryHelper.matchGenreIds('animacion').contains(16), true);

      // SciFi / Futurista -> Ciencia Ficción (878)
      expect(SearchDictionaryHelper.matchGenreIds('scifi').contains(878), true);
      expect(SearchDictionaryHelper.matchGenreIds('ciencia ficcion').contains(878), true);

      // Triller / Suspenso -> Thriller (53)
      expect(SearchDictionaryHelper.matchGenreIds('triller').contains(53), true);
      expect(SearchDictionaryHelper.matchGenreIds('suspenso').contains(53), true);
    });

    test('searchMovies devuelve películas de acción al buscar "accion" sin tilde', () {
      final results = SearchDictionaryHelper.searchMovies(
        catalog: MockMoviesData.sampleMovies,
        query: 'accion',
      );

      expect(results, isNotEmpty);
      final titles = results.map((m) => m.title).toList();
      expect(titles.contains('John Wick: Capítulo 4'), true);
      expect(titles.contains('Batman: El Caballero de la Noche'), true);
      expect(titles.contains('Mad Max: Furia en el Camino'), true);
    });

    test('searchMovies encuentra películas por título sin acentos ("parasitos", "suenos")', () {
      final parasiteResults = SearchDictionaryHelper.searchMovies(
        catalog: MockMoviesData.sampleMovies,
        query: 'parasitos',
      );
      expect(parasiteResults, isNotEmpty);
      expect(parasiteResults.first.title, 'Parásitos');

      final shawshankResults = SearchDictionaryHelper.searchMovies(
        catalog: MockMoviesData.sampleMovies,
        query: 'suenos',
      );
      expect(shawshankResults, isNotEmpty);
      expect(shawshankResults.first.title, contains('Sueños de Fuga'));
    });

    test('Actualización de perfil (avatar, email, copyWith)', () {
      final user = UserModel.createDemo(name: 'Alex', email: 'alex@swipeflick.app');
      final updated = user.copyWith(
        username: 'Alex Actualizado',
        email: 'nuevo@correo.com',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      );

      expect(updated.username, 'Alex Actualizado');
      expect(updated.email, 'nuevo@correo.com');
      expect(updated.avatarUrl, contains('photo-1494790108377-be9c29b29330'));
    });

    test('Validación estricta de contraseña actual en AuthService', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();
      await auth.init();
      await auth.signIn(email: 'alex@swipeflick.app', password: 'password123');

      // Contraseña es password123
      expect(auth.verifyCurrentPassword('password123'), true);
      expect(auth.verifyCurrentPassword('incorrecta'), false);

      // Intento de cambio con contraseña actual errónea debe fallar
      final failedChange = await auth.updatePassword(
        currentPassword: 'clave_incorrecta',
        newPassword: 'nueva_clave_segura_123',
      );
      expect(failedChange, false);

      // Cambio exitoso con la contraseña actual correcta
      final successChange = await auth.updatePassword(
        currentPassword: 'password123',
        newPassword: 'nueva_clave_segura_123',
      );
      expect(successChange, true);
      expect(auth.verifyCurrentPassword('nueva_clave_segura_123'), true);
      expect(auth.verifyCurrentPassword('password123'), false);
    });

    test('BrevoEmailService guarda credenciales e inicializa correctamente', () async {
      SharedPreferences.setMockInitialValues({});
      final brevo = BrevoEmailService();
      await brevo.init();

      await brevo.setCredentials(
        apiKey: 'mock-brevo-api-key-test-value-12345',
        senderEmail: 'soporte@swipeflick.app',
        senderName: 'SwipeFlick Official',
      );

      expect(brevo.isConfigured, true);
      expect(brevo.apiKey, 'mock-brevo-api-key-test-value-12345');
      expect(brevo.senderEmail, 'soporte@swipeflick.app');
      expect(brevo.senderName, 'SwipeFlick Official');
    });

    test('MongoDbService inicializa con defaultUri y maneja credenciales', () async {
      SharedPreferences.setMockInitialValues({'mongodb_uri': ''});
      final mongo = MongoDbService();
      await mongo.init();

      expect(mongo.status, MongoDbStatus.unconfigured);
      expect(mongo.isConnected, false);
      expect(mongo.isConfigured, false);
      expect(mongo.dbName, 'swipeflick');

      // Validar asignación de credenciales
      await mongo.saveCredentials(uri: 'mongodb://mock-cluster:27017/swipeflick', dbName: 'testdb');
      expect(mongo.isConfigured, true);
      expect(mongo.dbName, 'testdb');
      expect(mongo.uri, 'mongodb://mock-cluster:27017/swipeflick');
    });

    test('BrevoEmailService envía código de verificación OTP', () async {
      SharedPreferences.setMockInitialValues({'brevo_api_key': ''});
      final brevo = BrevoEmailService();
      await brevo.init();
      final sent = await brevo.sendVerificationCodeEmail(
        recipientEmail: 'cinefilo@swipeflick.app',
        recipientName: 'Alex',
        code: '123456',
      );
      expect(sent, isTrue);
    });

    test('SecurityHelper hashea y verifica contraseñas con sal', () {
      final hash1 = SecurityHelper.hashPassword('mi_clave_secreta', userSalt: 'user@test.com');
      expect(hash1.length, 64); // SHA-256 hex string

      // Verificación positiva
      expect(
        SecurityHelper.verifyPassword(
          candidatePassword: 'mi_clave_secreta',
          storedHash: hash1,
          userSalt: 'user@test.com',
        ),
        isTrue,
      );

      // Verificación negativa
      expect(
        SecurityHelper.verifyPassword(
          candidatePassword: 'clave_erronea',
          storedHash: hash1,
          userSalt: 'user@test.com',
        ),
        isFalse,
      );
    });

    test('SecurityHelper bloquea inyecciones NoSQL comunes y valida correos', () {
      // Intentos de inyección NoSQL
      expect(SecurityHelper.isSafeNoSqlInput(r'{"$gt": ""}'), isFalse);
      expect(SecurityHelper.isSafeNoSqlInput(r'$ne'), isFalse);
      expect(SecurityHelper.isSafeNoSqlInput(r'$regex'), isFalse);
      expect(SecurityHelper.isSafeNoSqlInput(r'$where'), isFalse);
      expect(SecurityHelper.isSafeNoSqlInput('admin; db.users.drop()'), isFalse);

      // Entradas legítimas
      expect(SecurityHelper.isSafeNoSqlInput('cinefilo@swipeflick.app'), isTrue);
      expect(SecurityHelper.isSafeNoSqlInput('Juan Perez'), isTrue);

      // Sanitización de correo
      expect(SecurityHelper.sanitizeEmail('cinefilo@swipeflick.app'), 'cinefilo@swipeflick.app');
      expect(SecurityHelper.sanitizeEmail(r'{"$gt": ""}@gmail.com'), isNull);
      expect(SecurityHelper.sanitizeEmail('correo_invalido_sin_arroba'), isNull);
    });

    test('RateLimitService limita a 5 intentos y aplica bloqueo incremental (+5min)', () async {
      SharedPreferences.setMockInitialValues({});
      final rateLimit = RateLimitService();
      await rateLimit.init();

      expect(rateLimit.failedAttempts, 0);
      expect(rateLimit.isLockedOut, isFalse);
      expect(rateLimit.remainingAttempts, 5);

      // 4 intentos fallidos
      for (int i = 0; i < 4; i++) {
        final locked = await rateLimit.recordFailedAttempt();
        expect(locked, isFalse);
      }
      expect(rateLimit.failedAttempts, 4);
      expect(rateLimit.remainingAttempts, 1);
      expect(rateLimit.isLockedOut, isFalse);

      // 5to intento fallido activa el 1er bloqueo (5 minutos)
      final locked5 = await rateLimit.recordFailedAttempt();
      expect(locked5, isTrue);
      expect(rateLimit.isLockedOut, isTrue);
      expect(rateLimit.consecutiveLockouts, 1);
      expect(rateLimit.remainingAttempts, 0);
      expect(rateLimit.remainingLockoutDuration.inMinutes, greaterThanOrEqualTo(4));

      // Intento posterior fallido incrementa a 10 minutos (2do bloqueo)
      final lockedAgain = await rateLimit.recordFailedAttempt();
      expect(lockedAgain, isTrue);
      expect(rateLimit.consecutiveLockouts, 2);
      expect(rateLimit.remainingLockoutDuration.inMinutes, greaterThanOrEqualTo(9));

      // Inicio de sesión exitoso reinicia el rate limit
      await rateLimit.recordSuccessfulLogin();
      expect(rateLimit.failedAttempts, 0);
      expect(rateLimit.isLockedOut, isFalse);
      expect(rateLimit.consecutiveLockouts, 0);
      expect(rateLimit.remainingAttempts, 5);
    });

    test('BrevoEmailService envía código de recuperación de contraseña', () async {
      SharedPreferences.setMockInitialValues({'brevo_api_key': ''});
      final brevo = BrevoEmailService();
      await brevo.init();
      final sent = await brevo.sendPasswordResetCodeEmail(
        recipientEmail: 'recuperar@swipeflick.app',
        recipientName: 'Alex Cinefilo',
        code: '987654',
      );
      expect(sent, isTrue);
    });

    test('TmdbService tiene clave de TMDB activa y catálogo en vivo habilitado por defecto', () async {
      SharedPreferences.setMockInitialValues({});
      final tmdb = TmdbService();
      await tmdb.init();

      expect(TmdbService.defaultApiKey.isNotEmpty, true);
      expect(tmdb.effectiveApiKey.isNotEmpty, true);
      expect(tmdb.hasApiKey, true);
    });

    test('CinemaSnackBar está configurado con 5 segundos de duración por defecto', () {
      expect(CinemaSnackBar.defaultDuration.inSeconds, 5);
      final snack = CinemaSnackBar.create('Prueba de aviso cinemático');
      expect(snack.duration.inSeconds, 5);
    });

    test('GenreModel.fromJson enriquece géneros sin afiche con afiches y emojis verificados', () {
      expect(GenreModel.defaultGenres.length, 19);
      // Simular respuesta cruda de TMDB que no incluye sample_poster_url
      final rawTmdbGenre = {'id': 28, 'name': 'Acción'};
      final enriched = GenreModel.fromJson(rawTmdbGenre);

      expect(enriched.id, 28);
      expect(enriched.name, 'Acción');
      expect(enriched.samplePosterUrl, isNotNull);
      expect(enriched.samplePosterUrl, contains('image.tmdb.org'));
      expect(enriched.emoji, '💥');
    });

    test('RoomModel soporta capacidad personalizada, excludeMatches y streamingOnly', () {
      final room = RoomModel(
        id: 'test-room-1',
        code: 'ABC123',
        hostId: 'host-1',
        hostUsername: 'Host Cinefilo',
        maxMembers: 14, // Personalizable
        excludeMatches: true, // Considerar/excluir matches
        streamingOnly: true, // Solo títulos en streaming
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );

      expect(room.maxMembers, 14);
      expect(room.excludeMatches, true);
      expect(room.streamingOnly, true);

      final json = room.toJson();
      expect(json['max_members'], 14);
      expect(json['exclude_matches'], true);
      expect(json['streaming_only'], true);

      final reconstructed = RoomModel.fromJson(json);
      expect(reconstructed.maxMembers, 14);
      expect(reconstructed.excludeMatches, true);
      expect(reconstructed.streamingOnly, true);
    });

    test('TmdbService discoverMoviesByGenres soporta filtro streamingOnly', () async {
      final tmdb = TmdbService();
      await tmdb.init();

      // En modo mock o sin red, discoverMoviesByGenres con streamingOnly filtra películas con streamingProviders
      final list = await tmdb.discoverMoviesByGenres([28], streamingOnly: true);
      expect(list, isNotEmpty);
      for (final m in list) {
        expect(m.genreIds.contains(28), true);
      }
    });

    test('MovieModel resuelve géneros automáticamente desde genre_ids de TMDB', () {
      // Simulación de película de TMDB descubierta en vivo sin campo 'genres' string
      final tmdbRaw = {
        'id': 99901,
        'title': 'La Leyenda del Charro Negro',
        'overview': 'Una leyenda animada.',
        'genre_ids': [16, 10751, 14], // Animación, Familia, Fantasía
        'vote_average': 8.4,
      };

      final movie = MovieModel.fromJson(tmdbRaw);
      expect(movie.displayGenres.isNotEmpty, true);
      expect(movie.displayGenres, contains('Animación'));
      expect(movie.displayGenres, contains('Familia'));
      expect(movie.displayGenres, contains('Fantasía'));
      expect(movie.displayGenresText, 'Animación, Familia, Fantasía');
    });

    test('FavoritesService permite eliminar match individual y vaciar historial', () async {
      SharedPreferences.setMockInitialValues({});
      final favs = FavoritesService();
      await favs.init();

      final movie1 = MovieModel(id: 101, title: 'Barbie', overview: 'Barbie world', rating: 7.1);
      final movie2 = MovieModel(id: 102, title: 'Oppenheimer', overview: 'Física nuclear', rating: 8.5);

      await favs.addMatchToHistory(movie1);
      await favs.addMatchToHistory(movie2);
      expect(favs.matchesHistory.length, 2);

      // Eliminar un match específico (deslizar a la izquierda)
      await favs.removeMatch(101);
      expect(favs.matchesHistory.length, 1);
      expect(favs.matchesHistory.first.id, 102);

      // Vaciar historial por completo (botón borrar historial)
      await favs.clearMatchesHistory();
      expect(favs.matchesHistory.isEmpty, true);
    });

    test('ReviewModel.ensureBalancedReviews garantiza al menos 1 positiva y 1 crítica', () {
      // Caso 1: Lista vacía (ej. El Grinch sin críticas en español)
      final emptyResult = ReviewModel.ensureBalancedReviews([], title: 'El Grinch', rating: 6.8);
      expect(emptyResult.length, 2);
      expect(emptyResult.any((r) => r.isPositive), true);
      expect(emptyResult.any((r) => !r.isPositive), true);

      // Caso 2: Solo críticas positivas
      final onlyPositive = [
        ReviewModel(
          id: '1',
          author: 'Fan',
          avatarUrl: '',
          content: 'Excelente película',
          rating: 9.0,
          isPositive: true,
          likesCount: 10,
          createdAt: DateTime.now(),
        ),
      ];
      final balanced1 = ReviewModel.ensureBalancedReviews(onlyPositive, title: 'Inception', rating: 8.8);
      expect(balanced1.length, 2);
      expect(balanced1.any((r) => r.isPositive), true);
      expect(balanced1.any((r) => !r.isPositive), true);

      // Caso 3: Ya balanceadas
      final alreadyBalanced = [
        ReviewModel(
          id: '1',
          author: 'Fan',
          avatarUrl: '',
          content: 'Excelente',
          rating: 9.0,
          isPositive: true,
          likesCount: 10,
          createdAt: DateTime.now(),
        ),
        ReviewModel(
          id: '2',
          author: 'Crítico',
          avatarUrl: '',
          content: 'Pudo mejorar',
          rating: 5.0,
          isPositive: false,
          likesCount: 5,
          createdAt: DateTime.now(),
        ),
      ];
      final balanced2 = ReviewModel.ensureBalancedReviews(alreadyBalanced, title: 'Matrix', rating: 8.7);
      expect(balanced2.length, 2);
      expect(balanced2.first.author, 'Fan');
      expect(balanced2.last.author, 'Crítico');
    });
  });
}
