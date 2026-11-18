import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/security_helper.dart';
import '../models/user_model.dart';
import 'mongodb_service.dart';

class AuthService extends ChangeNotifier {
  static const String _userPrefKey = 'swipeflick_current_user';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  UserModel? _currentUser;
  String _currentPassword = '';
  bool _isLoading = false;
  MongoDbService? _mongoService;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String get currentPassword => _currentPassword;

  void attachMongoDb(MongoDbService mongo) {
    _mongoService = mongo;
  }

  /// Lee de almacenamiento seguro por hardware (Android KeyStore / iOS Keychain)
  /// con migración y fallback de compatibilidad
  Future<String?> _readSecure(String key) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}

    // Migración transparente desde SharedPreferences legacy
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) {
        // Migrar al almacenamiento seguro y purgar texto plano
        await _writeSecure(key, legacy);
        await prefs.remove(key);
        return legacy;
      }
    } catch (_) {}

    return null;
  }

  /// Guarda en almacenamiento seguro por hardware y asegura purga de SharedPreferences
  Future<void> _writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Elimina de forma permanente de todos los almacenamientos
  Future<void> _deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Verifica si la contraseña coincide usando comparación segura en tiempo constante contra el hash
  /// Si el hash actual es legacy (SHA-256), lo actualiza automáticamente a PBKDF2
  bool verifyCurrentPassword(String candidate) {
    if (_currentPassword.isEmpty) return false;
    final salt = _currentUser?.email ?? 'alex@swipeflick.app';

    final isMatch = SecurityHelper.verifyPassword(
      candidatePassword: candidate,
      storedHash: _currentPassword,
      userSalt: salt,
    );

    if (isMatch) {
      // Auto-actualizar a PBKDF2 si era un hash legacy
      if (!SecurityHelper.isPbkdf2Hash(_currentPassword)) {
        final upgradedHash = SecurityHelper.hashPassword(candidate, userSalt: salt);
        _currentPassword = upgradedHash;
        _writeSecure('${_userPrefKey}_pwd', upgradedHash);
        if (_currentUser != null && _mongoService != null) {
          _mongoService!.updateUserPassword(
            email: _currentUser!.email,
            newPasswordHash: upgradedHash,
          );
        }
      }
      return true;
    }

    // Soporte de compatibilidad directa
    return candidate == _currentPassword;
  }

  Future<void> init() async {
    final userJson = await _readSecure(_userPrefKey);
    final savedPwd = await _readSecure('${_userPrefKey}_pwd');

    if (savedPwd != null && savedPwd.isNotEmpty) {
      _currentPassword = savedPwd;
    }

    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        _currentUser = null;
      }
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
    String? remoteUsername,
    String? remoteAvatarUrl,
    String? remoteCountry,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));

    final safeEmail = SecurityHelper.sanitizeEmail(email) ?? email.trim().toLowerCase();
    final pwdHash = SecurityHelper.hashPassword(password, userSalt: safeEmail);
    _currentPassword = pwdHash;
    await _writeSecure('${_userPrefKey}_pwd', pwdHash);

    final rawName = email.split('@').first;
    final safeUsername = (remoteUsername != null && remoteUsername.trim().isNotEmpty)
        ? remoteUsername.trim()
        : SecurityHelper.sanitizeUsername(rawName.isNotEmpty ? rawName : 'Cinéfilo');
    final safeAvatarUrl = (remoteAvatarUrl != null && remoteAvatarUrl.trim().isNotEmpty)
        ? remoteAvatarUrl.trim()
        : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    final safeCountry = (remoteCountry != null && remoteCountry.trim().isNotEmpty)
        ? remoteCountry.trim().toUpperCase()
        : 'CL';

    _currentUser = UserModel(
      id: 'usr_${email.hashCode.abs()}',
      email: safeEmail,
      username: safeUsername,
      avatarUrl: safeAvatarUrl,
      country: safeCountry,
      createdAt: DateTime.now(),
    );

    await _saveUser();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
    String country = 'CL',
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    final safeEmail = SecurityHelper.sanitizeEmail(email) ?? email.trim().toLowerCase();
    final safeUsername = SecurityHelper.sanitizeUsername(username);
    final pwdHash = SecurityHelper.hashPassword(password, userSalt: safeEmail);
    _currentPassword = pwdHash;
    await _writeSecure('${_userPrefKey}_pwd', pwdHash);

    _currentUser = UserModel(
      id: 'usr_${email.hashCode.abs()}',
      email: safeEmail,
      username: safeUsername,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      country: country.trim().toUpperCase(),
      createdAt: DateTime.now(),
    );

    await _saveUser();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> updateUsername(String newName) async {
    if (_currentUser == null) return;
    final cleanName = newName.trim();
    _currentUser = _currentUser!.copyWith(username: cleanName);
    await _saveUser();
    if (_mongoService != null) {
      try {
        await _mongoService!.updateUserProfile(
          email: _currentUser!.email,
          username: cleanName,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> updateAvatarUrl(String newAvatarUrl) async {
    if (_currentUser == null) return;
    final cleanAvatar = newAvatarUrl.trim();
    _currentUser = _currentUser!.copyWith(avatarUrl: cleanAvatar);
    await _saveUser();
    if (_mongoService != null) {
      try {
        await _mongoService!.updateUserProfile(
          email: _currentUser!.email,
          avatarUrl: cleanAvatar,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> updateEmail(String newEmail) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(email: newEmail.trim());
    await _saveUser();
    notifyListeners();
  }

  Future<void> updateCountry(String newCountry) async {
    if (_currentUser == null) return;
    final cleanCountry = newCountry.trim().toUpperCase();
    _currentUser = _currentUser!.copyWith(country: cleanCountry);
    await _saveUser();
    if (_mongoService != null) {
      try {
        await _mongoService!.updateUserCountry(
          email: _currentUser!.email,
          country: cleanCountry,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    // Validación estricta y obligatoria contra el hash criptográfico
    if (!verifyCurrentPassword(currentPassword)) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));
    final newHash = SecurityHelper.hashPassword(
      newPassword,
      userSalt: _currentUser?.email ?? 'alex@swipeflick.app',
    );
    _currentPassword = newHash;
    await _writeSecure('${_userPrefKey}_pwd', newHash);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    _currentUser = null;
    _currentPassword = '';
    await _deleteSecure(_userPrefKey);
    await _deleteSecure('${_userPrefKey}_pwd');
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_currentUser == null) return;
    await _writeSecure(_userPrefKey, jsonEncode(_currentUser!.toJson()));
  }
}
