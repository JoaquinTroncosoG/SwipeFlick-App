import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/security_helper.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  static const String _userPrefKey = 'swipeflick_current_user';
  UserModel? _currentUser;
  String _currentPassword = '';
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String get currentPassword => _currentPassword;

  /// Verifica si la contraseña coincide usando comparación segura en tiempo constante contra el hash
  bool verifyCurrentPassword(String candidate) {
    if (_currentPassword.isEmpty) return false;
    final salt = _currentUser?.email ?? 'alex@swipeflick.app';
    if (_currentPassword.length == 64) {
      return SecurityHelper.verifyPassword(
        candidatePassword: candidate,
        storedHash: _currentPassword,
        userSalt: salt,
      );
    }
    // Soporte de compatibilidad
    return candidate == _currentPassword ||
        SecurityHelper.hashPassword(candidate, userSalt: salt) == _currentPassword;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userPrefKey);
    final savedPwd = prefs.getString('${_userPrefKey}_pwd');
    if (savedPwd != null && savedPwd.isNotEmpty) {
      // Migrar automáticamente si no era hash de 64 caracteres
      if (savedPwd.length == 64) {
        _currentPassword = savedPwd;
      } else {
        _currentPassword = SecurityHelper.hashPassword(savedPwd, userSalt: 'alex@swipeflick.app');
        await prefs.setString('${_userPrefKey}_pwd', _currentPassword);
      }
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

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600)); // Simula red
    
    final safeEmail = SecurityHelper.sanitizeEmail(email) ?? email.trim().toLowerCase();
    final pwdHash = SecurityHelper.hashPassword(password, userSalt: safeEmail);
    _currentPassword = pwdHash;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_userPrefKey}_pwd', pwdHash);

    final rawName = email.split('@').first;
    final safeUsername = SecurityHelper.sanitizeUsername(rawName.isNotEmpty ? rawName : 'Cinéfilo');
    _currentUser = UserModel(
      id: 'usr_${email.hashCode.abs()}',
      email: safeEmail,
      username: safeUsername,
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
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
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    final safeEmail = SecurityHelper.sanitizeEmail(email) ?? email.trim().toLowerCase();
    final safeUsername = SecurityHelper.sanitizeUsername(username);
    final pwdHash = SecurityHelper.hashPassword(password, userSalt: safeEmail);
    _currentPassword = pwdHash;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_userPrefKey}_pwd', pwdHash);

    _currentUser = UserModel(
      id: 'usr_${email.hashCode.abs()}',
      email: safeEmail,
      username: safeUsername,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      createdAt: DateTime.now(),
    );

    await _saveUser();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> loginAsGuest([String? name]) async {
    _currentUser = UserModel.createDemo(
      name: name ?? 'Cinéfilo_${(DateTime.now().millisecond % 900) + 100}',
    );
    await _saveUser();
    notifyListeners();
  }

  Future<void> updateUsername(String newName) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(username: newName.trim());
    await _saveUser();
    notifyListeners();
  }

  Future<void> updateAvatarUrl(String newAvatarUrl) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(avatarUrl: newAvatarUrl.trim());
    await _saveUser();
    notifyListeners();
  }

  Future<void> updateEmail(String newEmail) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(email: newEmail.trim());
    await _saveUser();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_userPrefKey}_pwd', newHash);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    _currentUser = null;
    _currentPassword = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefKey);
    await prefs.remove('${_userPrefKey}_pwd');
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefKey, jsonEncode(_currentUser!.toJson()));
  }
}
