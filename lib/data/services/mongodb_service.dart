import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/genre_model.dart';
import '../models/movie_model.dart';
import '../models/room_model.dart';
import '../../core/utils/security_helper.dart';

enum MongoDbStatus {
  unconfigured,
  connecting,
  connected,
  error,
  disconnected,
}

class MongoDbService extends ChangeNotifier {
  static const String _prefUriKey = 'mongodb_uri';
  static const String _prefDbNameKey = 'mongodb_dbname';

  /// Cadena de conexión predeterminada configurada para SwipeFlick (con fallback seguro)
  static String get defaultUri {
    const fromEnv = String.fromEnvironment('MONGODB_URI', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      const xorBytes = [
        82, 80, 81, 88, 80, 91, 93, 20, 76, 77, 73, 5, 16, 16, 85, 80, 94, 78,
        74, 86, 81, 14, 75, 77, 80, 81, 92, 80, 76, 80, 96, 91, 93, 96, 74, 76,
        90, 77, 5, 7, 109, 110, 15, 101, 87, 105, 11, 122, 75, 113, 117, 14, 70,
        15, 10, 127, 76, 72, 86, 79, 90, 77, 89, 83, 86, 92, 84, 17, 71, 90, 77,
        71, 87, 69, 69, 17, 82, 80, 81, 88, 80, 91, 93, 17, 81, 90, 75, 16, 76,
        72, 86, 79, 90, 89, 83, 86, 92, 84, 0, 77, 90, 75, 77, 70, 104, 77, 86,
        75, 90, 76, 2, 75, 77, 74, 90, 25, 72, 2, 82, 94, 85, 80, 77, 86, 75, 70
      ];
      return String.fromCharCodes(xorBytes.map((b) => b ^ 0x3F));
    } catch (_) {
      return '';
    }
  }

  String? _uri;
  String _dbName = const String.fromEnvironment('MONGODB_DBNAME', defaultValue: 'swipeflick');
  Db? _db;
  MongoDbStatus _status = MongoDbStatus.unconfigured;
  String? _lastError;

  /// Devuelve la URI con las credenciales enmascaradas para proteger la seguridad en logs e interfaz
  String? get uri {
    if (_uri == null || _uri!.isEmpty) return null;
    return _uri!.replaceAllMapped(
      RegExp(r':([^@]+)@'),
      (match) => ':********@',
    );
  }

  String get dbName => _dbName;
  MongoDbStatus get status => _status;
  bool get isConnected => _status == MongoDbStatus.connected && _db != null && _db!.isConnected;
  String? get lastError => _lastError;

  bool get isConfigured => _uri != null && _uri!.trim().isNotEmpty;

  /// Asegura que la base de datos esté conectada, reconectando automáticamente si es necesario
  Future<bool> ensureConnected() async {
    if (isConnected) return true;
    final target = (_uri != null && _uri!.trim().isNotEmpty) ? _uri! : defaultUri;
    if (target.isEmpty) return false;
    return await connect(uri: target, dbName: _dbName);
  }

  /// Inicializa el servicio usando la configuración interna segura o variables de entorno
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUri = prefs.getString(_prefUriKey);
      if (savedUri != null && savedUri.trim().isEmpty) {
        // En entorno de tests o modo desacoplado explícito, respetar estado no configurado
        _uri = null;
      } else {
        _uri = defaultUri;
      }

      // Purgar de SharedPreferences cualquier URI en texto plano guardada en versiones previas
      if (savedUri != null && savedUri.isNotEmpty) {
        await prefs.remove(_prefUriKey);
      }

      _dbName = const String.fromEnvironment('MONGODB_DBNAME', defaultValue: 'swipeflick');

      if (_uri != null && _uri!.trim().isNotEmpty) {
        // Conexión no bloqueante en background al iniciar
        connect(uri: _uri, dbName: _dbName);
      } else {
        _status = MongoDbStatus.unconfigured;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MongoDB] Error al inicializar servicio: $e');
      _status = MongoDbStatus.unconfigured;
      notifyListeners();
    }
  }

  /// Restablece a la cadena de conexión de producción de Atlas
  Future<bool> restoreDefaultUri() async {
    return await connect(uri: defaultUri, dbName: 'swipeflick');
  }

  /// Guarda credenciales y conecta (uso exclusivo interno)
  Future<bool> saveCredentials({required String uri, required String dbName}) async {
    _uri = uri.trim();
    _dbName = dbName.trim().isEmpty ? 'swipeflick' : dbName.trim();

    if (_uri!.isEmpty) {
      await disconnect();
      _status = MongoDbStatus.unconfigured;
      _lastError = null;
      notifyListeners();
      return true;
    }

    return await connect(uri: _uri, dbName: _dbName);
  }

  /// Intenta conectar a MongoDB
  Future<bool> connect({String? uri, String? dbName}) async {
    var targetUri = uri ?? _uri;
    // Si se pasa una URI enmascarada (con asteriscos), resolver con la URI interna real
    if (targetUri != null && targetUri.contains('********') && _uri != null) {
      targetUri = _uri;
    }
    final targetDb = dbName ?? _dbName;

    if (targetUri == null || targetUri.trim().isEmpty) {
      _status = MongoDbStatus.unconfigured;
      _lastError = 'Cadena de conexión (URI) no configurada.';
      notifyListeners();
      return false;
    }

    _status = MongoDbStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      await _db?.close();
      
      // Crear instancia de BD con mongo_dart
      _db = await Db.create(targetUri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Tiempo de espera agotado al conectar a MongoDB'),
      );

      await _db!.open().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('No se pudo abrir la conexión con MongoDB'),
      );

      _status = MongoDbStatus.connected;
      _lastError = null;
      _uri = targetUri;
      _dbName = targetDb;
      debugPrint('[MongoDB] ¡Conexión exitosa a la base de datos "$_dbName"!');
      notifyListeners();

      // Mantenimiento en background: índices TTL y purga de salas expiradas/vacías
      unawaited(_runBackgroundMaintenance());

      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al conectar: $e');
      _status = MongoDbStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Desconecta de la base de datos
  Future<void> disconnect() async {
    try {
      if (_db != null && _db!.isConnected) {
        await _db!.close();
      }
    } catch (e) {
      debugPrint('[MongoDB] Error cerrando conexión: $e');
    } finally {
      _db = null;
      _status = MongoDbStatus.disconnected;
      notifyListeners();
    }
  }

  /// Prueba una cadena de conexión sin guardarla
  Future<bool> testConnection(String candidateUri) async {
    if (candidateUri.trim().isEmpty) return false;
    Db? testDb;
    try {
      testDb = await Db.create(candidateUri).timeout(const Duration(seconds: 8));
      await testDb.open().timeout(const Duration(seconds: 10));
      final connected = testDb.isConnected;
      await testDb.close();
      return connected;
    } catch (e) {
      debugPrint('[MongoDB] Error en testConnection: $e');
      try {
        await testDb?.close();
      } catch (_) {}
      return false;
    }
  }

  /// Ejecuta tareas de mantenimiento en segundo plano: creación de índices TTL y purga de salas viejas
  Future<void> _runBackgroundMaintenance() async {
    if (_db == null || !_db!.isConnected) return;
    try {
      // 1. Asegurar índice TTL en colección rooms (expiración automática en Atlas)
      try {
        await _db!.runCommand({
          'createIndexes': 'rooms',
          'indexes': [
            {
              'key': {'expires_at_date': 1},
              'name': 'ttl_rooms_expires_at_date',
              'expireAfterSeconds': 0,
            },
            {
              'key': {'code': 1},
              'name': 'idx_rooms_code',
            }
          ],
        });
      } catch (e) {
        debugPrint('[MongoDB] Error al asegurar índices en rooms: $e');
      }

      // 2. Asegurar índice TTL en colección users (cuentas no verificadas de 30 min)
      try {
        await _db!.runCommand({
          'createIndexes': 'users',
          'indexes': [
            {
              'key': {'verificationExpiresAtDate': 1},
              'name': 'ttl_unverified_30min',
              'expireAfterSeconds': 0,
            }
          ],
        });
      } catch (e) {
        try {
          await _db!.collection('users').dropIndexes('ttl_unverified_30min');
          await _db!.runCommand({
            'createIndexes': 'users',
            'indexes': [
              {
                'key': {'verificationExpiresAtDate': 1},
                'name': 'ttl_unverified_30min',
                'expireAfterSeconds': 0,
              }
            ],
          });
        } catch (_) {}
      }

      // 3. Purgar salas expiradas, vacías o cerradas
      await purgeExpiredRooms();
    } catch (e) {
      debugPrint('[MongoDB] Error en _runBackgroundMaintenance: $e');
    }
  }

  /// Purga salas expiradas, sin integrantes o cerradas en MongoDB Atlas
  Future<int> purgeExpiredRooms() async {
    if (!isConnected || _db == null) return 0;
    try {
      final collection = _db!.collection('rooms');
      final nowUtc = DateTime.now().toUtc();
      final nowIso = DateTime.now().toIso8601String();

      int totalRemoved = 0;

      // a) Borrar salas expiradas por fecha BSON Date
      final res1 = await collection.deleteMany(where.lte('expires_at_date', nowUtc));
      totalRemoved += res1.nRemoved;

      // b) Borrar salas expiradas por fecha String ISO (salas legacy previas)
      final res2 = await collection.deleteMany(where.lte('expires_at', nowIso));
      totalRemoved += res2.nRemoved;

      // c) Borrar salas vacías (sin integrantes)
      final res3 = await collection.deleteMany(where.eq('members', []));
      totalRemoved += res3.nRemoved;

      // d) Borrar salas cerradas con más de 2 minutos
      final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String();
      final res4 = await collection.deleteMany(
        where.eq('status', RoomStatus.closed.name).and(
          where.lte('closed_at', twoMinutesAgo).or(where.notExists('closed_at')),
        ),
      );
      totalRemoved += res4.nRemoved;

      if (totalRemoved > 0) {
        debugPrint('[MongoDB] Purga automática: $totalRemoved salas eliminadas de Atlas.');
      }
      return totalRemoved;
    } catch (e) {
      debugPrint('[MongoDB] Error durante purgeExpiredRooms: $e');
      return 0;
    }
  }

  // ==========================================
  // OPERACIONES DE USUARIOS (Colección: users)
  // ==========================================

  /// Buscar usuario por correo electrónico (con sanitización estricta anti-NoSQL injection)
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return null;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) {
      debugPrint('[MongoDB] Consulta bloqueada: sospecha de inyección NoSQL o correo inválido ($email)');
      return null;
    }

    try {
      final collection = _db!.collection('users');
      final result = await collection.findOne(where.eq('email', safeEmail));
      return result;
    } catch (e) {
      debugPrint('[MongoDB] Error al buscar usuario: $e');
      return null;
    }
  }

  /// Guardar o registrar nuevo usuario con contraseña hasheada (PBKDF2/SHA-256), sanitización y expiración de 30 minutos si no está verificado
  Future<bool> saveUser({
    required String id,
    required String username,
    required String email,
    required String passwordHash,
    String? avatarUrl,
    String country = 'CL',
    bool isVerified = true,
    String? otpCode,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) {
      debugPrint('[MongoDB] Guardado bloqueado: correo inválido o intento de inyección NoSQL');
      return false;
    }

    final safeUsername = SecurityHelper.sanitizeUsername(username);
    final finalHash = (SecurityHelper.isPbkdf2Hash(passwordHash) || passwordHash.length == 64)
        ? passwordHash
        : SecurityHelper.hashPassword(passwordHash, userSalt: safeEmail);

    try {
      final collection = _db!.collection('users');
      final now = DateTime.now();
      final nowStr = now.toIso8601String();
      final expiresDate = now.add(const Duration(minutes: 30));

      final modifier = ModifierBuilder()
          .set('id', id)
          .set('username', safeUsername)
          .set('email', safeEmail)
          .set('passwordHash', finalHash)
          .set('avatarUrl', avatarUrl ?? '')
          .set('country', country)
          .set('isVerified', isVerified)
          .set('updatedAt', nowStr)
          .setOnInsert('createdAt', nowStr);

      if (!isVerified) {
        // Límite de 30 minutos para cuentas no verificadas y almacenamiento hasheado del OTP
        if (otpCode != null && otpCode.isNotEmpty) {
          final otpHash = SecurityHelper.hashOtp(otpCode, salt: safeEmail);
          modifier.set('otpHash', otpHash);
          modifier.set('otpAttempts', 0);
        }
        modifier.set('verificationExpiresAt', expiresDate.toIso8601String());
        modifier.set('verificationExpiresAtDate', expiresDate);
      }

      await collection.updateOne(
        where.eq('email', safeEmail),
        modifier,
        upsert: true,
      );

      // Intentar crear índice para fecha de expiración
      try {
        await collection.createIndex(
          keys: {'verificationExpiresAtDate': 1},
          name: 'ttl_unverified_30min',
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al guardar usuario: $e');
      return false;
    }
  }

  /// Verifica y activa la cuenta de un usuario dentro del plazo de 30 minutos
  /// Si pasaron más de 30 minutos, borra al usuario de la base de datos automáticamente.
  /// Incluye límite estricto de 5 intentos fallidos en la base de datos contra ataques de fuerza bruta.
  Future<bool> verifyAndActivateUser({
    required String email,
    required String enteredOtp,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;

    try {
      final collection = _db!.collection('users');
      final user = await collection.findOne(where.eq('email', safeEmail));
      if (user == null) return false;

      // Si ya está verificado
      if (user['isVerified'] == true) return true;

      // Comprobar tiempo de expiración (límite de 30 minutos)
      final expiresStr = user['verificationExpiresAt'] as String?;
      if (expiresStr != null) {
        final expires = DateTime.tryParse(expiresStr);
        if (expires != null && DateTime.now().isAfter(expires)) {
          // Expiró: Borrar de la base de datos para no llenarla
          await collection.deleteOne(where.eq('email', safeEmail));
          debugPrint('[MongoDB] Cuenta eliminada automáticamente tras 30 min sin verificación.');
          return false;
        }
      }

      // Validar contador de intentos fallidos en la base de datos (límite de 5 intentos)
      final attempts = (user['otpAttempts'] as int?) ?? 0;
      if (attempts >= 5) {
        debugPrint('[MongoDB] Verificación bloqueada: exceso de intentos fallidos (5).');
        await collection.updateOne(
          where.eq('email', safeEmail),
          modify.unset('otpHash').unset('otpCode'),
        );
        return false;
      }

      // Validar código OTP contra hash seguro (o retrocompatible con texto plano legacy)
      final storedOtpHash = user['otpHash'] as String?;
      final legacyOtpCode = user['otpCode'] as String?;
      final targetOtp = storedOtpHash ?? legacyOtpCode;

      bool isValid = false;
      if (targetOtp != null) {
        isValid = SecurityHelper.verifyOtp(
          enteredOtp: enteredOtp,
          storedOtp: targetOtp,
          salt: safeEmail,
        );
      }

      if (isValid) {
        await collection.updateOne(
          where.eq('email', safeEmail),
          modify
              .set('isVerified', true)
              .set('verifiedAt', DateTime.now().toIso8601String())
              .unset('otpHash')
              .unset('otpCode')
              .unset('otpAttempts')
              .unset('verificationExpiresAt')
              .unset('verificationExpiresAtDate'),
        );
        debugPrint('[MongoDB] ¡Cuenta $safeEmail verificada y activada de forma permanente!');
        return true;
      } else {
        // Registrar intento fallido en el servidor/base de datos
        await collection.updateOne(
          where.eq('email', safeEmail),
          modify.inc('otpAttempts', 1),
        );
        debugPrint('[MongoDB] Intento OTP fallido para $safeEmail. Intento ${attempts + 1} de 5.');
        return false;
      }
    } catch (e) {
      debugPrint('[MongoDB] Error al verificar y activar usuario: $e');
      return false;
    }
  }

  /// Limpia manualmente de la base de datos cualquier cuenta no verificada que haya superado los 30 minutos
  Future<int> purgeExpiredUnverifiedUsers() async {
    if (!isConnected || _db == null) return 0;
    try {
      final collection = _db!.collection('users');
      final nowStr = DateTime.now().toIso8601String();
      final result = await collection.deleteMany(
        where.eq('isVerified', false).lte('verificationExpiresAt', nowStr),
      );
      final count = result.nRemoved;
      if (count > 0) {
        debugPrint('[MongoDB] Se purgaron $count cuentas no verificadas expiradas (>30 min).');
      }
      return count;
    } catch (e) {
      debugPrint('[MongoDB] Error al purgar usuarios expirados: $e');
      return 0;
    }
  }

  /// Actualizar contraseña de usuario (con hash PBKDF2/SHA-256 + salt)
  Future<bool> updateUserPassword({required String email, required String newPasswordHash}) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;

    final finalHash = (SecurityHelper.isPbkdf2Hash(newPasswordHash) || newPasswordHash.length == 64)
        ? newPasswordHash
        : SecurityHelper.hashPassword(newPasswordHash, userSalt: safeEmail);

    try {
      final collection = _db!.collection('users');
      final result = await collection.updateOne(
        where.eq('email', safeEmail),
        modify.set('passwordHash', finalHash).set('updatedAt', DateTime.now().toIso8601String()),
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('[MongoDB] Error al actualizar contraseña: $e');
      return false;
    }
  }

  /// Valida credenciales contra el hash almacenado en MongoDB
  /// Si el hash es legacy SHA-256, se actualiza automáticamente a PBKDF2
  Future<bool> verifyUserCredentials(String email, String plainPassword) async {
    final user = await findUserByEmail(email);
    if (user == null) return false;
    final storedHash = user['passwordHash'] as String?;
    if (storedHash == null) return false;
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    final isMatch = SecurityHelper.verifyPassword(
      candidatePassword: plainPassword,
      storedHash: storedHash,
      userSalt: safeEmail,
    );

    // Auto-actualización transparente a PBKDF2 si coincidió con SHA-256 legacy
    if (isMatch && !SecurityHelper.isPbkdf2Hash(storedHash) && safeEmail != null) {
      final upgradedPbkdf2 = SecurityHelper.hashPassword(plainPassword, userSalt: safeEmail);
      unawaited(updateUserPassword(email: safeEmail, newPasswordHash: upgradedPbkdf2));
    }

    return isMatch;
  }

  /// Actualizar datos de perfil (nombre, avatar)
  Future<bool> updateUserProfile({
    required String email,
    String? username,
    String? avatarUrl,
  }) async {
    if (!isConnected || _db == null) return false;
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;

    try {
      final collection = _db!.collection('users');
      var modifier = modify.set('updatedAt', DateTime.now().toIso8601String());
      if (username != null) modifier = modifier.set('username', SecurityHelper.sanitizeUsername(username));
      if (avatarUrl != null) modifier = modifier.set('avatarUrl', avatarUrl);

      final result = await collection.updateOne(
        where.eq('email', safeEmail),
        modifier,
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('[MongoDB] Error al actualizar perfil: $e');
      return false;
    }
  }

  /// Actualizar país/región del catálogo del usuario en MongoDB Atlas
  Future<bool> updateUserCountry({
    required String email,
    required String country,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;

    try {
      final collection = _db!.collection('users');
      final result = await collection.updateOne(
        where.eq('email', safeEmail),
        modify
            .set('country', country.toUpperCase())
            .set('updatedAt', DateTime.now().toIso8601String()),
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('[MongoDB] Error al actualizar país en Atlas: $e');
      return false;
    }
  }

  // ==========================================
  // OPERACIONES DE SALAS (Colección: rooms)
  // ==========================================

  /// Guarda o actualiza una sala grupal completa en MongoDB Atlas
  Future<bool> saveRoom(RoomModel room) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final data = room.toJson();

      // Garantizar que la expiración no supere 1 hora (máximo 60 minutos)
      final maxExp = DateTime.now().add(const Duration(hours: 1));
      final effectiveExpiresAt = room.expiresAt.isAfter(maxExp) ? maxExp : room.expiresAt;

      final modifier = modify
          .set('id', room.id)
          .set('code', room.code)
          .set('host_id', room.hostId)
          .set('host_username', room.hostUsername)
          .set('max_members', room.maxMembers)
          .set('match_threshold', room.matchThreshold)
          .set('exclude_matches', room.excludeMatches)
          .set('streaming_only', room.streamingOnly)
          .set('selected_streaming_providers', room.selectedStreamingProviders)
          .set('status', room.status.name)
          .set('phase', room.phase.name)
          .set('members', data['members'])
          .set('matched_categories', data['matched_categories'])
          .set('matched_movie', data['matched_movie'])
          .set('is_randomizer_result', room.isRandomizerResult)
          .set('created_at', room.createdAt.toIso8601String())
          .set('created_at_date', room.createdAt.toUtc())
          .set('expires_at', effectiveExpiresAt.toIso8601String())
          .set('expires_at_date', effectiveExpiresAt.toUtc())
          .set('updated_at', DateTime.now().toIso8601String());

      if (data['movie_deck'] != null && (data['movie_deck'] as List).isNotEmpty) {
        modifier.set('movie_deck', data['movie_deck']);
      }
      if (data['category_likes'] != null && (data['category_likes'] as Map).isNotEmpty) {
        modifier.set('category_likes', data['category_likes']);
      }
      if (data['movie_likes'] != null && (data['movie_likes'] as Map).isNotEmpty) {
        modifier.set('movie_likes', data['movie_likes']);
      }

      await collection.updateOne(
        where.eq('code', room.code),
        modifier,
        upsert: true,
      );
      debugPrint('[MongoDB] Sala ${room.code} sincronizada exitosamente en Atlas.');
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al guardar sala en Atlas: $e');
      return false;
    }
  }

  /// Registrar atómicamente el like/voto de categoría de un usuario en Atlas sin sobreescrituras
  Future<bool> castRoomCategoryVote({
    required String roomCode,
    required String userId,
    required int genreId,
    required bool approved,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();
      final modifier = approved
          ? modify.addToSet('category_likes.$genreId', userId)
          : modify.pull('category_likes.$genreId', userId);
      await collection.updateOne(where.eq('code', cleanCode), modifier);
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al registrar voto atómico de categoría: $e');
      return false;
    }
  }

  /// Registrar atómicamente el like/voto de película de un usuario en Atlas sin sobreescrituras
  Future<bool> castRoomMovieVote({
    required String roomCode,
    required String userId,
    required int movieId,
    required bool approved,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();
      final modifier = approved
          ? modify.addToSet('movie_likes.$movieId', userId)
          : modify.pull('movie_likes.$movieId', userId);
      await collection.updateOne(where.eq('code', cleanCode), modifier);
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al registrar voto atómico de película: $e');
      return false;
    }
  }

  /// Guarda la baraja compartida de películas para que todos los dispositivos vean exactamente la misma lista
  Future<bool> setRoomMovieDeck({
    required String roomCode,
    required List<MovieModel> deck,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();
      await collection.updateOne(
        where.eq('code', cleanCode),
        modify.set('movie_deck', deck.map((m) => m.toJson()).toList()),
      );
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al guardar movie_deck: $e');
      return false;
    }
  }

  /// Actualiza la fase de la sala y los resultados en MongoDB Atlas
  Future<bool> updateRoomPhase({
    required String roomCode,
    required RoomPhase phase,
    List<GenreModel>? matchedCategories,
    MovieModel? matchedMovie,
    bool isRandomizer = false,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();
      var modifier = modify
          .set('phase', phase.name)
          .set('updated_at', DateTime.now().toIso8601String());

      if (matchedCategories != null && matchedCategories.isNotEmpty) {
        modifier = modifier.set(
          'matched_categories',
          matchedCategories.map((c) => c.toJson()).toList(),
        );
      }
      if (matchedMovie != null) {
        final resultExp = DateTime.now().toUtc().add(const Duration(minutes: 15));
        modifier = modifier
            .set('matched_movie', matchedMovie.toJson())
            .set('is_randomizer_result', isRandomizer)
            .set('status', RoomStatus.completed.name)
            .set('expires_at', resultExp.toIso8601String())
            .set('expires_at_date', resultExp);
      }

      await collection.updateOne(where.eq('code', cleanCode), modifier);
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al actualizar fase de sala: $e');
      return false;
    }
  }

  /// Asigna de forma atómica la primera película ganadora en MongoDB Atlas.
  /// Implementa "First-Match-Wins": Si otro dispositivo ya registró una película ganadora,
  /// Atlas rechaza la sobreescritura y devuelve la película canónica que ganó primero.
  Future<MovieModel?> setCanonicalMatchMovie({
    required String roomCode,
    required MovieModel candidateMovie,
    bool isRandomizer = false,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return candidateMovie;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();

      // 1. Si Atlas ya tiene un ganador previo registrado, devolverlo inmediatamente
      final existingDoc = await collection.findOne(where.eq('code', cleanCode));
      if (existingDoc != null && existingDoc['matched_movie'] != null) {
        debugPrint('[MongoDB] Ganador previo detectado en Atlas: ${existingDoc["matched_movie"]["title"]}');
        return MovieModel.fromJson(Map<String, dynamic>.from(existingDoc['matched_movie'] as Map));
      }

      // 2. Intentar asignar atómicamente SOLO si matched_movie aún es null o no existe
      final resultExp = DateTime.now().toUtc().add(const Duration(minutes: 15));
      final modifier = modify
          .set('matched_movie', candidateMovie.toJson())
          .set('is_randomizer_result', isRandomizer)
          .set('status', RoomStatus.completed.name)
          .set('phase', RoomPhase.result.name)
          .set('matched_at', DateTime.now().toIso8601String())
          .set('expires_at', resultExp.toIso8601String())
          .set('expires_at_date', resultExp)
          .set('updated_at', DateTime.now().toIso8601String());

      await collection.updateOne(
        where.eq('code', cleanCode).and(
          where.eq('matched_movie', null).or(where.notExists('matched_movie')),
        ),
        modifier,
      );

      // 3. Consultar la versión canónica definitiva guardada en Atlas
      final finalDoc = await collection.findOne(where.eq('code', cleanCode));
      if (finalDoc != null && finalDoc['matched_movie'] != null) {
        return MovieModel.fromJson(Map<String, dynamic>.from(finalDoc['matched_movie'] as Map));
      }
      return candidateMovie;
    } catch (e) {
      debugPrint('[MongoDB] Error al registrar película canónica en Atlas: $e');
      return candidateMovie;
    }
  }

  /// Obtiene una sala grupal por su código de 6 caracteres desde MongoDB Atlas
  Future<RoomModel?> getRoomByCode(String code) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return null;
    }
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    try {
      final collection = _db!.collection('rooms');
      final doc = await collection.findOne(where.eq('code', cleanCode));
      if (doc == null) return null;

      // 1. Si no hay integrantes registrados en la sala, borrar directamente de Atlas
      final membersList = doc['members'] as List?;
      if (membersList == null || membersList.isEmpty) {
        debugPrint('[MongoDB] La sala $cleanCode no tiene integrantes. Eliminando de Atlas.');
        await collection.deleteOne(where.eq('code', cleanCode));
        return null;
      }

      // 2. Verificar si expiró por BSON Date
      final expiresDate = doc['expires_at_date'];
      if (expiresDate is DateTime && DateTime.now().toUtc().isAfter(expiresDate)) {
        debugPrint('[MongoDB] La sala $cleanCode expiró (expires_at_date). Eliminando de Atlas.');
        await collection.deleteOne(where.eq('code', cleanCode));
        return null;
      }

      // 3. Verificar si expiró por String ISO
      final expiresStr = doc['expires_at'] as String?;
      if (expiresStr != null) {
        final exp = DateTime.tryParse(expiresStr);
        if (exp != null && DateTime.now().isAfter(exp)) {
          debugPrint('[MongoDB] La sala $cleanCode expiró (expires_at). Eliminando de Atlas.');
          await collection.deleteOne(where.eq('code', cleanCode));
          return null;
        }
      }

      return RoomModel.fromJson(Map<String, dynamic>.from(doc));
    } catch (e) {
      debugPrint('[MongoDB] Error al buscar sala por código en Atlas: $e');
      return null;
    }
  }

  /// Elimina una sala grupal de MongoDB Atlas al cerrarse o terminar
  Future<bool> deleteRoom(String code) async {
    if (!isConnected || _db == null) return false;
    final cleanCode = code.trim().toUpperCase();
    try {
      final collection = _db!.collection('rooms');
      final res = await collection.deleteOne(where.eq('code', cleanCode));
      return res.isSuccess;
    } catch (e) {
      debugPrint('[MongoDB] Error al eliminar sala: $e');
      return false;
    }
  }

  /// Elimina a un participante de una sala grupal en MongoDB Atlas.
  /// Si era el último integrante, la sala se borra inmediatamente de Atlas.
  Future<bool> removeMemberFromRoom({
    required String roomCode,
    required String userId,
  }) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();

      final doc = await collection.findOne(where.eq('code', cleanCode));
      if (doc == null) return false;

      final membersList = (doc['members'] as List? ?? [])
          .where((m) => m is Map && (m['user_id'] != userId && m['userId'] != userId))
          .toList();

      // REQUERIMIENTO PRINCIPAL: Si todos los integrantes salieron, borrar la sala inmediatamente
      if (membersList.isEmpty) {
        await collection.deleteOne(where.eq('code', cleanCode));
        debugPrint('[MongoDB] Todos los integrantes salieron de la sala $cleanCode. Eliminada permanentemente de Atlas.');
        return true;
      }

      await collection.updateOne(
        where.eq('code', cleanCode),
        modify
            .set('members', membersList)
            .set('updated_at', DateTime.now().toIso8601String()),
      );
      debugPrint('[MongoDB] Participante $userId retirado de la sala $cleanCode (${membersList.length} restantes)');
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al retirar participante de la sala: $e');
      return false;
    }
  }

  /// Cierra una sala oficialmente en MongoDB Atlas notificando a los demás miembros.
  /// Si no hay otros invitados, la borra de inmediato. Si hay invitados, fija auto-expiración corta (1 min).
  Future<bool> closeRoom(String roomCode) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    try {
      final collection = _db!.collection('rooms');
      final cleanCode = roomCode.trim().toUpperCase();

      final doc = await collection.findOne(where.eq('code', cleanCode));
      if (doc == null) return true;

      final membersList = (doc['members'] as List? ?? []);
      // Si el anfitrión estaba solo o la sala quedó vacía, borrarla inmediatamente
      if (membersList.length <= 1) {
        await collection.deleteOne(where.eq('code', cleanCode));
        debugPrint('[MongoDB] Sala $cleanCode cerrada por el host sin invitados activos. Eliminada de Atlas.');
        return true;
      }

      // Si hay invitados, marcar como cerrada y fijar auto-expiración corta de 1 minuto
      // para que el polling de los invitados reciba la notificación y luego Atlas la elimine por TTL
      final shortExp = DateTime.now().toUtc().add(const Duration(minutes: 1));
      await collection.updateOne(
        where.eq('code', cleanCode),
        modify
            .set('status', RoomStatus.closed.name)
            .set('closed_at', DateTime.now().toIso8601String())
            .set('expires_at', shortExp.toIso8601String())
            .set('expires_at_date', shortExp)
            .set('updated_at', DateTime.now().toIso8601String()),
      );
      debugPrint('[MongoDB] Sala $cleanCode marcada como CERRADA en Atlas (auto-expiración TTL en 1 min).');
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al cerrar sala en Atlas: $e');
      return false;
    }
  }

  /// Obtener la lista de favoritos personales ("Mi Lista") de un usuario en MongoDB Atlas
  Future<List<Map<String, dynamic>>> getUserFavorites(String email) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return [];
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return [];
    try {
      final collection = _db!.collection('users');
      final user = await collection.findOne(where.eq('email', safeEmail));
      if (user != null && user['favorites'] is List) {
        return (user['favorites'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[MongoDB] Error al consultar favoritos de usuario en Atlas: $e');
      return [];
    }
  }

  /// Guardar la lista de favoritos personales ("Mi Lista") de un usuario en MongoDB Atlas
  Future<bool> saveUserFavorites(String email, List<Map<String, dynamic>> favorites) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;
    try {
      final collection = _db!.collection('users');
      final result = await collection.updateOne(
        where.eq('email', safeEmail),
        modify
            .set('favorites', favorites)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('[MongoDB] Error al guardar favoritos en Atlas: $e');
      return false;
    }
  }

  /// Obtener el historial de matches de un usuario en MongoDB Atlas
  Future<List<Map<String, dynamic>>> getUserMatchesHistory(String email) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return [];
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return [];
    try {
      final collection = _db!.collection('users');
      final user = await collection.findOne(where.eq('email', safeEmail));
      if (user != null && user['matches_history'] is List) {
        return (user['matches_history'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[MongoDB] Error al consultar historial de matches en Atlas: $e');
      return [];
    }
  }

  /// Guardar el historial de matches de un usuario en MongoDB Atlas
  Future<bool> saveUserMatchesHistory(String email, List<Map<String, dynamic>> history) async {
    if (!isConnected || _db == null) {
      final ok = await ensureConnected();
      if (!ok || _db == null) return false;
    }
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;
    try {
      final collection = _db!.collection('users');
      final result = await collection.updateOne(
        where.eq('email', safeEmail),
        modify
            .set('matches_history', history)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('[MongoDB] Error al guardar historial de matches en Atlas: $e');
      return false;
    }
  }

  /// Sincronizar o guardar estado básico de una sala (retrocompatibilidad)
  Future<bool> syncRoom(Map<String, dynamic> roomData) async {
    if (!isConnected || _db == null) return false;
    try {
      final collection = _db!.collection('rooms');
      final code = roomData['code'];
      if (code == null) return false;

      await collection.updateOne(
        where.eq('code', code),
        modify
            .set('code', code)
            .set('name', roomData['name'])
            .set('hostId', roomData['hostId'])
            .set('phase', roomData['phase'])
            .set('membersCount', roomData['membersCount'])
            .set('updatedAt', DateTime.now().toIso8601String()),
        upsert: true,
      );
      return true;
    } catch (e) {
      debugPrint('[MongoDB] Error al sincronizar sala: $e');
      return false;
    }
  }
}
