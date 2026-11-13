import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Cadena de conexión predeterminada configurada para SwipeFlick (inyectable por entorno o vacía)
  static const String defaultUri = String.fromEnvironment(
    'MONGODB_URI',
    defaultValue: '',
  );

  String? _uri;
  String _dbName = const String.fromEnvironment('MONGODB_DBNAME', defaultValue: 'swipeflick');
  Db? _db;
  MongoDbStatus _status = MongoDbStatus.unconfigured;
  String? _lastError;

  String? get uri => _uri;
  String get dbName => _dbName;
  MongoDbStatus get status => _status;
  bool get isConnected => _status == MongoDbStatus.connected && _db != null && _db!.isConnected;
  String? get lastError => _lastError;

  bool get isConfigured => _uri != null && _uri!.trim().isNotEmpty;

  /// Inicializa el servicio leyendo credenciales persistidas o usando la URI de Atlas por entorno
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUri = prefs.getString(_prefUriKey);
      if (savedUri != null && savedUri.trim().isNotEmpty) {
        _uri = savedUri.trim();
      } else if (defaultUri.isNotEmpty) {
        _uri = defaultUri;
      } else {
        _uri = null;
      }

      _dbName = prefs.getString(_prefDbNameKey) ??
          const String.fromEnvironment('MONGODB_DBNAME', defaultValue: 'swipeflick');

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
    return await saveCredentials(uri: defaultUri, dbName: 'swipeflick');
  }

  /// Guarda credenciales y conecta
  Future<bool> saveCredentials({required String uri, required String dbName}) async {
    _uri = uri.trim();
    _dbName = dbName.trim().isEmpty ? 'swipeflick' : dbName.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUriKey, _uri!);
    await prefs.setString(_prefDbNameKey, _dbName);

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
    final targetUri = uri ?? _uri;
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

  // ==========================================
  // OPERACIONES DE USUARIOS (Colección: users)
  // ==========================================

  /// Buscar usuario por correo electrónico (con sanitización estricta anti-NoSQL injection)
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    if (!isConnected || _db == null) return null;
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

  /// Guardar o registrar nuevo usuario con contraseña hasheada, sanitización y expiración de 30 minutos si no está verificado
  Future<bool> saveUser({
    required String id,
    required String username,
    required String email,
    required String passwordHash,
    String? avatarUrl,
    bool isVerified = true,
    String? otpCode,
  }) async {
    if (!isConnected || _db == null) return false;
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) {
      debugPrint('[MongoDB] Guardado bloqueado: correo inválido o intento de inyección NoSQL');
      return false;
    }

    final safeUsername = SecurityHelper.sanitizeUsername(username);
    final finalHash = passwordHash.length == 64
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
          .set('isVerified', isVerified)
          .set('updatedAt', nowStr)
          .setOnInsert('createdAt', nowStr);

      if (!isVerified) {
        // Límite de 30 minutos para cuentas no verificadas (REQUERIMIENTO 2)
        modifier.set('otpCode', otpCode ?? '');
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
  Future<bool> verifyAndActivateUser({
    required String email,
    required String enteredOtp,
  }) async {
    if (!isConnected || _db == null) return false;
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

      // Validar código OTP
      final storedOtp = user['otpCode'] as String?;
      if (storedOtp != null && storedOtp == enteredOtp.trim()) {
        await collection.updateOne(
          where.eq('email', safeEmail),
          modify
              .set('isVerified', true)
              .set('verifiedAt', DateTime.now().toIso8601String())
              .unset('otpCode')
              .unset('verificationExpiresAt')
              .unset('verificationExpiresAtDate'),
        );
        debugPrint('[MongoDB] ¡Cuenta $safeEmail verificada y activada de forma permanente!');
        return true;
      }
      return false;
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

  /// Actualizar contraseña de usuario (con hash SHA-256 + salt)
  Future<bool> updateUserPassword({required String email, required String newPasswordHash}) async {
    if (!isConnected || _db == null) return false;
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    if (safeEmail == null) return false;

    final finalHash = newPasswordHash.length == 64
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
  Future<bool> verifyUserCredentials(String email, String plainPassword) async {
    final user = await findUserByEmail(email);
    if (user == null) return false;
    final storedHash = user['passwordHash'] as String?;
    if (storedHash == null) return false;
    final safeEmail = SecurityHelper.sanitizeEmail(email);
    return SecurityHelper.verifyPassword(
      candidatePassword: plainPassword,
      storedHash: storedHash,
      userSalt: safeEmail,
    );
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

  // ==========================================
  // OPERACIONES DE SALAS (Colección: rooms)
  // ==========================================

  /// Sincronizar o guardar estado de una sala
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
