import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RateLimitService extends ChangeNotifier {
  static const String _prefFailedAttemptsKey = 'rate_limit_failed_attempts';
  static const String _prefLockoutUntilKey = 'rate_limit_lockout_until';
  static const String _prefConsecutiveLockoutsKey = 'rate_limit_consecutive_lockouts';

  static const int maxAttempts = 5;
  static const int baseLockoutMinutes = 5;

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  int _consecutiveLockouts = 0;

  int get failedAttempts => _failedAttempts;
  DateTime? get lockoutUntil => _lockoutUntil;
  int get consecutiveLockouts => _consecutiveLockouts;

  int get remainingAttempts {
    if (isLockedOut) return 0;
    final left = maxAttempts - _failedAttempts;
    return left < 0 ? 0 : left;
  }

  /// Verifica si el usuario se encuentra actualmente bloqueado
  bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    final now = DateTime.now();
    if (now.isBefore(_lockoutUntil!)) {
      return true;
    }
    // El tiempo de bloqueo ya expiró
    return false;
  }

  /// Tiempo restante de bloqueo
  Duration get remainingLockoutDuration {
    if (!isLockedOut || _lockoutUntil == null) return Duration.zero;
    final diff = _lockoutUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Formato legible del tiempo restante (ej. "4m 25s" o "5 minutos")
  String get remainingLockoutFormatted {
    final dur = remainingLockoutDuration;
    if (dur.inSeconds <= 0) return '0 segundos';
    final minutes = dur.inMinutes;
    final seconds = dur.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
    } else {
      return '$seconds segundos';
    }
  }

  /// Inicializa cargando el estado persistido
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt(_prefFailedAttemptsKey) ?? 0;
      _consecutiveLockouts = prefs.getInt(_prefConsecutiveLockoutsKey) ?? 0;

      final lockoutMillis = prefs.getInt(_prefLockoutUntilKey);
      if (lockoutMillis != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);
        if (date.isAfter(DateTime.now())) {
          _lockoutUntil = date;
        } else {
          _lockoutUntil = null;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[RateLimit] Error al inicializar: $e');
    }
  }

  /// Registra un intento fallido de inicio de sesión
  /// Si alcanza 5 intentos, bloquea por 5 minutos, y en cada nuevo bloqueo incrementa 5 minutos más (5, 10, 15...).
  Future<bool> recordFailedAttempt() async {
    _failedAttempts++;

    bool wasLocked = false;
    if (_failedAttempts >= maxAttempts) {
      _consecutiveLockouts++;
      final lockoutMinutes = baseLockoutMinutes * _consecutiveLockouts;
      _lockoutUntil = DateTime.now().add(Duration(minutes: lockoutMinutes));
      wasLocked = true;
      debugPrint('[RateLimit] ¡Bloqueo activado! $_consecutiveLockouts° bloqueo por $lockoutMinutes minutos.');
    }

    await _persistState();
    notifyListeners();
    return wasLocked;
  }

  /// Registra un inicio de sesión exitoso y restablece el contador
  Future<void> recordSuccessfulLogin() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    _consecutiveLockouts = 0;
    await _persistState();
    notifyListeners();
  }

  /// Restablece para pruebas o soporte
  Future<void> reset() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    _consecutiveLockouts = 0;
    await _persistState();
    notifyListeners();
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefFailedAttemptsKey, _failedAttempts);
      await prefs.setInt(_prefConsecutiveLockoutsKey, _consecutiveLockouts);
      if (_lockoutUntil != null) {
        await prefs.setInt(_prefLockoutUntilKey, _lockoutUntil!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_prefLockoutUntilKey);
      }
    } catch (e) {
      debugPrint('[RateLimit] Error al persistir estado: $e');
    }
  }
}
