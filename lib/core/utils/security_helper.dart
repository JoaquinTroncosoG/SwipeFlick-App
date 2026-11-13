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

  /// Genera un hash criptográfico SHA-256 seguro con sal para la contraseña
  static String hashPassword(String password, {String? userSalt}) {
    final salt = userSalt ?? 'default_salt';
    final rawCombined = '$_appSecretPepper:$salt:$password:$_appSecretPepper';
    final bytes = utf8.encode(rawCombined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifica si una contraseña candidata coincide con el hash guardado
  static bool verifyPassword({
    required String candidatePassword,
    required String storedHash,
    String? userSalt,
  }) {
    final candidateHash = hashPassword(candidatePassword, userSalt: userSalt);
    // Comparación segura para prevenir ataques de temporización
    return _constantTimeCompare(candidateHash, storedHash);
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
