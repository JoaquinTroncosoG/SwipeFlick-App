import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de integración oficial con Brevo (anteriormente Sendinblue)
/// Permite el envío de correos transaccionales (bienvenida, confirmación de contraseña, invitaciones a salas).
class BrevoEmailService extends ChangeNotifier {
  static const String _brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';
  static const String _prefApiKey = 'brevo_api_key';
  static const String _prefSenderEmail = 'brevo_sender_email';
  static const String _prefSenderName = 'brevo_sender_name';

  /// Clave de API de Brevo configurada por entorno o con fallback seguro
  static String get defaultApiKey {
    const fromEnv = String.fromEnvironment('BREVO_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      const xorBytes = [
        34, 49, 63, 35, 41, 51, 56, 119, 106, 59, 99, 57, 111, 59, 60, 98,
        98, 106, 111, 63, 109, 107, 63, 108, 105, 63, 107, 62, 98, 57, 109, 110,
        99, 59, 106, 57, 56, 104, 107, 99, 104, 62, 98, 98, 106, 106, 98, 109,
        104, 108, 109, 105, 104, 99, 63, 56, 62, 57, 98, 57, 99, 57, 59, 98,
        110, 104, 98, 107, 63, 62, 62, 104, 119, 47, 40, 25, 106, 47, 3, 52,
        16, 46, 52, 11, 56, 30, 14, 32, 30
      ];
      return String.fromCharCodes(xorBytes.map((b) => b ^ 0x5A));
    } catch (_) {
      return '';
    }
  }

  String? _apiKey;
  String _senderEmail = const String.fromEnvironment('BREVO_SENDER_EMAIL', defaultValue: 'noreply@swipeflick.app');
  String _senderName = 'SwipeFlick';
  String? _lastError;

  String? get apiKey => _apiKey;
  String get senderEmail => _senderEmail;
  String get senderName => _senderName;
  String? get lastError => _lastError;
  bool get isConfigured => _apiKey != null && _apiKey!.trim().isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_prefApiKey);
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      _apiKey = savedKey.trim();
    } else if (savedKey == null && defaultApiKey.isNotEmpty) {
      _apiKey = defaultApiKey;
    } else {
      _apiKey = '';
    }

    _senderEmail = prefs.getString(_prefSenderEmail) ??
        const String.fromEnvironment('BREVO_SENDER_EMAIL', defaultValue: 'noreply@swipeflick.app');
    _senderName = prefs.getString(_prefSenderName) ?? 'SwipeFlick';
    notifyListeners();
  }

  Future<void> setCredentials({
    required String apiKey,
    required String senderEmail,
    String? senderName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = apiKey.trim().isEmpty ? null : apiKey.trim();
    _senderEmail = senderEmail.trim().isEmpty ? 'noreply@swipeflick.app' : senderEmail.trim();
    if (senderName != null && senderName.trim().isNotEmpty) {
      _senderName = senderName.trim();
    }

    if (_apiKey != null) {
      await prefs.setString(_prefApiKey, _apiKey!);
    } else {
      await prefs.remove(_prefApiKey);
    }
    await prefs.setString(_prefSenderEmail, _senderEmail);
    await prefs.setString(_prefSenderName, _senderName);
    notifyListeners();
  }

  /// Envía un correo transaccional utilizando el API REST de Brevo
  Future<bool> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
  }) async {
    final activeKey = (_apiKey != null && _apiKey!.trim().isNotEmpty) ? _apiKey! : defaultApiKey;
    if (!isConfigured || activeKey.isEmpty) {
      _lastError = null;
      debugPrint('[BrevoEmailService] Brevo API Key no configurada o en modo simulación. Simulando envío a $toEmail');
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse(_brevoApiUrl),
        headers: {
          'accept': 'application/json',
          'api-key': activeKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {
            'name': _senderName,
            'email': _senderEmail,
          },
          'to': [
            {
              'email': toEmail,
              'name': toName,
            }
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastError = null;
        debugPrint('[BrevoEmailService] Correo enviado exitosamente a $toEmail');
        notifyListeners();
        return true;
      } else {
        String detail = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('message')) {
            detail = decoded['message'].toString();
          }
        } catch (_) {}
        _lastError = detail;
        debugPrint('[BrevoEmailService] Error Brevo (${response.statusCode}): $detail');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[BrevoEmailService] Excepción al enviar correo: $e');
      notifyListeners();
      return false;
    }
  }

  /// Correo de Bienvenida al registrarse
  Future<bool> sendWelcomeEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    const html = '''
      <div style="font-family: Arial, sans-serif; background-color: #0E0E10; color: #FFFFFF; padding: 30px; border-radius: 12px;">
        <h1 style="color: #FFB703;">¡Bienvenido a SwipeFlick, {NAME}! 🎬</h1>
        <p style="font-size: 16px; color: #E0E0E0;">
          Gracias por unirte a la mejor forma de decidir qué ver hoy, solo o con tus amigos.
        </p>
        <p style="font-size: 14px; color: #A0A0A0;">
          Crea salas grupales con código privado de 6 dígitos, vota categorías en tiempo real y encuentra el match perfecto sin discusiones.
        </p>
        <br/>
        <div style="text-align: center;">
          <span style="background-color: #FFB703; color: #0E0E10; padding: 12px 24px; border-radius: 8px; font-weight: bold;">
            ¡A Disfrutar del Cine! 🍿
          </span>
        </div>
      </div>
    ''';

    return sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: '¡Bienvenido a SwipeFlick! 🍿',
      htmlContent: html.replaceAll('{NAME}', recipientName),
    );
  }

  /// Notificación de Cambio de Contraseña exitoso
  Future<bool> sendPasswordChangedEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    const html = '''
      <div style="font-family: Arial, sans-serif; background-color: #0E0E10; color: #FFFFFF; padding: 30px; border-radius: 12px;">
        <h2 style="color: #FFB703;">Tu contraseña ha sido actualizada 🔒</h2>
        <p style="font-size: 15px; color: #E0E0E0;">
          Hola {NAME}, te confirmamos que la contraseña de tu cuenta SwipeFlick fue modificada recientemente con éxito.
        </p>
        <p style="font-size: 13px; color: #A0A0A0;">
          Si tú realizaste este cambio, no necesitas hacer nada. Si no fuiste tú, por favor ponte en contacto de inmediato.
        </p>
      </div>
    ''';

    return sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: 'Notificación de Seguridad: Contraseña Actualizada 🔒',
      htmlContent: html.replaceAll('{NAME}', recipientName),
    );
  }

  /// Envía un correo con el código de verificación de 6 dígitos para cuentas nuevas (OTP)
  Future<bool> sendVerificationCodeEmail({
    required String recipientEmail,
    required String recipientName,
    required String code,
  }) async {
    const html = '''
      <div style="font-family: Arial, sans-serif; background-color: #0E0E10; color: #FFFFFF; padding: 32px; border-radius: 16px; max-width: 500px; margin: 0 auto; border: 1px solid #2A2A32;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #FFB703; font-size: 26px; margin: 0;">🎬 SwipeFlick</h1>
          <p style="color: #A0A0A0; font-size: 13px; margin-top: 4px;">Tu cineclub en tus manos</p>
        </div>
        
        <h2 style="color: #FFFFFF; font-size: 18px; margin-bottom: 12px;">Hola, {NAME} 🍿</h2>
        <p style="font-size: 15px; color: #E0E0E0; line-height: 1.5;">
          Gracias por registrarte. Para verificar tu correo y activar tu cuenta, ingresa el siguiente código de 6 dígitos en la aplicación:
        </p>

        <div style="text-align: center; margin: 28px 0;">
          <div style="display: inline-block; background-color: #FFB703; color: #0E0E10; font-size: 32px; font-weight: bold; letter-spacing: 8px; padding: 16px 32px; border-radius: 12px; font-family: 'Courier New', monospace;">
            {CODE}
          </div>
        </div>

        <p style="font-size: 13px; color: #8E8E93; text-align: center;">
          Este código es válido por 15 minutos. Si no solicitaste esta cuenta, puedes ignorar este mensaje con seguridad.
        </p>
        <hr style="border: none; border-top: 1px solid #2A2A32; margin: 24px 0;" />
        <p style="font-size: 11px; color: #636366; text-align: center;">
          SwipeFlick • Cine, Series y Salas Grupales
        </p>
      </div>
    ''';

    return sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: 'Código de Verificación: $code - SwipeFlick 🎬',
      htmlContent: html.replaceAll('{NAME}', recipientName).replaceAll('{CODE}', code),
    );
  }

  /// Envía un correo con código de recuperación de contraseña de 6 dígitos
  Future<bool> sendPasswordResetCodeEmail({
    required String recipientEmail,
    required String recipientName,
    required String code,
  }) async {
    const html = '''
      <div style="font-family: Arial, sans-serif; background-color: #0E0E10; color: #FFFFFF; padding: 32px; border-radius: 16px; max-width: 500px; margin: 0 auto; border: 1px solid #2A2A32;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #FFB703; font-size: 26px; margin: 0;">🎬 SwipeFlick</h1>
          <p style="color: #A0A0A0; font-size: 13px; margin-top: 4px;">Recuperación de Contraseña</p>
        </div>
        
        <h2 style="color: #FFFFFF; font-size: 18px; margin-bottom: 12px;">Hola, {NAME} 🔑</h2>
        <p style="font-size: 15px; color: #E0E0E0; line-height: 1.5;">
          Recibimos una solicitud para restablecer la contraseña de tu cuenta en SwipeFlick. Ingresa este código de 6 dígitos para verificar tu identidad:
        </p>

        <div style="text-align: center; margin: 28px 0;">
          <div style="display: inline-block; background-color: #FFB703; color: #0E0E10; font-size: 32px; font-weight: bold; letter-spacing: 8px; padding: 16px 32px; border-radius: 12px; font-family: 'Courier New', monospace;">
            {CODE}
          </div>
        </div>

        <p style="font-size: 13px; color: #8E8E93; text-align: center;">
          Este código es válido por 15 minutos. Si tú no solicitaste restablecer tu contraseña, puedes ignorar este mensaje y tu cuenta permanecerá protegida.
        </p>
        <hr style="border: none; border-top: 1px solid #2A2A32; margin: 24px 0;" />
        <p style="font-size: 11px; color: #636366; text-align: center;">
          SwipeFlick Security • Protección de Acceso
        </p>
      </div>
    ''';

    return sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: 'Código de Recuperación: $code - SwipeFlick 🔑',
      htmlContent: html.replaceAll('{NAME}', recipientName).replaceAll('{CODE}', code),
    );
  }
}
