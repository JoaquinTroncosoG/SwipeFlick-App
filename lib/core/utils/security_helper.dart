import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityHelper {
  // Sal secreta interna para reforzar la entropía criptográfica
  static const String _appSecretPepper = 'SwipeFlick_Secure_Pepper_9a8b7c6d5e4f3a2b1c';

  // Expresión regular estricta para correos válidos
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  // Patrones peligrosos comunes en inyecciones NoSQL (MongoDB operators, regex, scripts)
  static final List<String> _noSqlForbiddenPatterns = [
    r'$gt',
    r'$gte',
    r'$lt',
    r'$lte',
    r'$ne',
    r'$in',
    r'$nin',
    r'$or',
    r'$and',
    r'$not',
    r'$nor',
    r'$exists',
    r'$type',
    r'$mod',
    r'$regex',
    r'$where',
    r'$expr',
    r'$jsonSchema',
    r'{"$',
    r'{"',
    r'{$',
  ];

  /// Genera una clave derivada mediante PBKDF2-HMAC-SHA256 (NIST SP 800-63B)
  /// Incorpora factor de trabajo (10.000 iteraciones), sal por usuario y pepper secreto.
  static String hashPassword(String password, {String? userSalt, int iterations = 10000}) {
    final salt = userSalt ?? 'default_salt';
    final hmacKey = utf8.encode('$_appSecretPepper:$password');
    final saltBytes = utf8.encode('$salt:$_appSecretPepper');

    final hmac = Hmac(sha256, hmacKey);
    // U_1 = HMAC(salt || INT_32_BE(1))
    final initialData = <int>[...saltBytes, 0, 0, 0, 1];
    var u = hmac.convert(initialData).bytes;
    final result = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    final hexDigest = result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '\$pbkdf2\$i=$iterations\$$hexDigest';
  }

  /// Verifica si una cadena tiene el formato de hash PBKDF2
  static bool isPbkdf2Hash(String hash) => hash.startsWith(r'$pbkdf2$');

  /// Verifica si una contraseña candidata coincide con el hash guardado
  /// Soporta tanto PBKDF2 moderno como hashes legacy SHA-256 de 64 caracteres.
  static bool verifyPassword({
    required String candidatePassword,
    required String storedHash,
    String? userSalt,
  }) {
    if (storedHash.isEmpty) return false;

    // 1. Soporte para formato moderno PBKDF2: $pbkdf2$i=10000$<hex>
    if (storedHash.startsWith(r'$pbkdf2$')) {
      final parts = storedHash.split(r'$');
      if (parts.length >= 4) {
        int iters = 10000;
        if (parts[2].startsWith('i=')) {
          iters = int.tryParse(parts[2].substring(2)) ?? 10000;
        }
        final candidate = hashPassword(candidatePassword, userSalt: userSalt, iterations: iters);
        return _constantTimeCompare(candidate, storedHash);
      }
    }

    // 2. Soporte retrocompatible para hashes legacy SHA-256 (64 caracteres)
    if (storedHash.length == 64) {
      final salt = userSalt ?? 'default_salt';
      final rawCombined = '$_appSecretPepper:$salt:$candidatePassword:$_appSecretPepper';
      final legacyDigest = sha256.convert(utf8.encode(rawCombined)).toString();
      if (_constantTimeCompare(legacyDigest, storedHash)) {
        return true;
      }
    }

    return false;
  }

  /// Genera un hash criptográfico para códigos OTP de 6 dígitos con sal
  static String hashOtp(String otp, {required String salt}) {
    final raw = '$_appSecretPepper:OTP:$salt:${otp.trim()}:$_appSecretPepper';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Verifica si un código OTP coincide con el hash guardado (o con texto plano legacy)
  static bool verifyOtp({
    required String enteredOtp,
    required String storedOtp,
    required String salt,
  }) {
    final cleanEntered = enteredOtp.trim();
    // Si el valor guardado es un hash SHA-256 de 64 caracteres
    if (storedOtp.length == 64) {
      final candidateHash = hashOtp(cleanEntered, salt: salt);
      return _constantTimeCompare(candidateHash, storedOtp);
    }
    // Soporte retrocompatible si era texto plano
    return _constantTimeCompare(cleanEntered, storedOtp.trim());
  }

  /// Valida y sanitiza una cadena contra inyección NoSQL
  /// Si detecta operadores de MongoDB ($gt, $ne, etc.) o sintaxis de objeto JSON, lanza o retorna null/falso
  static bool isSafeNoSqlInput(String? input) {
    if (input == null || input.isEmpty) return false;

    final lower = input.toLowerCase().trim();

    // No debe comenzar con el símbolo $ reservado de operadores de MongoDB
    if (lower.startsWith(r'$')) {
      return false;
    }

    // Comprobar presencia de operadores o inyecciones de objetos
    for (final pattern in _noSqlForbiddenPatterns) {
      if (lower.contains(pattern)) {
        return false;
      }
    }

    // No debe contener delimitadores de objetos JSON o caracteres sospechosos de código
    if (lower.contains('{') || lower.contains('}') || lower.contains(';') || lower.contains('db.')) {
      return false;
    }

    return true;
  }

  /// Sanitiza un correo electrónico garantizando que sea una cadena limpia y segura
  static String? sanitizeEmail(String? email) {
    if (email == null) return null;
    final trimmed = email.trim().toLowerCase();

    if (!isSafeNoSqlInput(trimmed)) {
      return null;
    }

    if (!_emailRegExp.hasMatch(trimmed)) {
      return null;
    }

    // Longitud máxima de seguridad para correos (RFC 5321)
    if (trimmed.length > 254) {
      return null;
    }

    return trimmed;
  }

  /// Sanitiza un nombre de usuario evitando caracteres de control o inyecciones
  static String sanitizeUsername(String username) {
    var cleaned = username.trim();
    // Eliminar caracteres peligrosos
    cleaned = cleaned.replaceAll(RegExp(r'[\${}\\\/<>"]'), '');
    if (cleaned.length > 30) {
      cleaned = cleaned.substring(0, 30);
    }
    return cleaned;
  }

  /// Comparación en tiempo constante para evitar timing attacks
  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
