import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/security_helper.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/brevo_email_service.dart';
import '../../../../data/services/mongodb_service.dart';
import '../../../../data/services/rate_limit_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // 1: Email, 2: OTP, 3: Nueva contraseña

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _generatedOtp = '';
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // PASO 1: Enviar código OTP por correo
  void _sendRecoveryCode() async {
    final rawEmail = _emailController.text.trim();
    final safeEmail = SecurityHelper.sanitizeEmail(rawEmail);

    if (safeEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Por favor ingresa un correo electrónico válido (sin caracteres no permitidos)'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Generar OTP de 6 dígitos
    _generatedOtp = (100000 + Random().nextInt(900000)).toString();

    final brevo = context.read<BrevoEmailService>();
    await brevo.sendPasswordResetCodeEmail(
      recipientEmail: safeEmail,
      recipientName: safeEmail.split('@').first,
      code: _generatedOtp,
    );

    setState(() {
      _isLoading = false;
      _currentStep = 2;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text('Código de seguridad enviado a $safeEmail ✉️'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // PASO 2: Verificar el código OTP
  void _verifyRecoveryCode() {
    final entered = _otpController.text.trim();
    if (entered.isEmpty || entered != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Código incorrecto. Revisa el correo enviado o el código de pruebas.'),
        ),
      );
      return;
    }

    setState(() {
      _currentStep = 3;
    });
  }

  // PASO 3: Guardar nueva contraseña con hash criptográfico
  void _resetPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final email = SecurityHelper.sanitizeEmail(_emailController.text) ?? _emailController.text.trim().toLowerCase();

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('La nueva contraseña debe tener al menos 6 caracteres'),
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Las contraseñas no coinciden. Escríbelas igual para confirmar.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final mongo = context.read<MongoDbService>();
    final auth = context.read<AuthService>();
    final rateLimit = context.read<RateLimitService>();
    final brevo = context.read<BrevoEmailService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // 1. Actualizar en MongoDB Atlas con hash SHA-256 + salt
    if (mongo.isConnected || await mongo.ensureConnected()) {
      await mongo.updateUserPassword(
        email: email,
        newPasswordHash: newPass, // MongoDbService lo hashea automáticamente con salt
      );
    }

    // 2. Si es el usuario activo local en AuthService, actualizar también
    if (auth.currentUser != null && auth.currentUser!.email.toLowerCase() == email.toLowerCase()) {
      await auth.signIn(email: email, password: newPass);
    }

    // 3. Notificación de seguridad por Brevo
    brevo.sendPasswordChangedEmail(
      recipientEmail: email,
      recipientName: email.split('@').first,
    );

    // 4. Reiniciar rate limiter de intentos fallidos
    await rateLimit.recordSuccessfulLogin();

    setState(() => _isLoading = false);

    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text('¡Contraseña restablecida y protegida con éxito! 🔑 Inicia sesión con tu nueva clave.'),
        duration: Duration(seconds: 4),
      ),
    );

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de pasos
              _buildStepIndicator(),
              const SizedBox(height: 28),

              if (_currentStep == 1) _buildStepOneEmail(),
              if (_currentStep == 2) _buildStepTwoOtp(),
              if (_currentStep == 3) _buildStepThreeNewPassword(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(1, 'Correo', _currentStep >= 1),
        Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppColors.accent : AppColors.surfaceBorder)),
        _buildStepDot(2, 'Código', _currentStep >= 2),
        Expanded(child: Container(height: 2, color: _currentStep >= 3 ? AppColors.accent : AppColors.surfaceBorder)),
        _buildStepDot(3, 'Nueva Clave', _currentStep >= 3),
      ],
    );
  }

  Widget _buildStepDot(int step, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accent : AppColors.surfaceElevated,
            border: Border.all(color: active ? AppColors.accent : AppColors.surfaceBorder),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: active ? AppColors.background : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: active ? AppColors.accent : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // VISTA PASO 1
  Widget _buildStepOneEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Olvidaste tu contraseña?', style: AppTextStyles.heroDisplay.copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu correo registrado y te enviaremos un código de seguridad de 6 dígitos vía Brevo para verificar tu identidad.',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 24),

        Text('Correo Electrónico', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: AppTextStyles.bodyMedium,
          decoration: const InputDecoration(
            hintText: 'tu@correo.com',
            prefixIcon: Icon(Icons.email_outlined, color: AppColors.accent),
          ),
        ),
        const SizedBox(height: 28),

        CinemaButton(
          text: 'Enviar Código de Seguridad',
          icon: Icons.send_rounded,
          width: double.infinity,
          isLoading: _isLoading,
          onPressed: _sendRecoveryCode,
        ),
      ],
    );
  }

  // VISTA PASO 2
  Widget _buildStepTwoOtp() {
    final email = _emailController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingresa tu Código', style: AppTextStyles.heroDisplay.copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          'Revisa tu bandeja de entrada en $email e ingresa o pega el código de 6 dígitos:',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppTextStyles.heroDisplay.copyWith(
            fontSize: 28,
            letterSpacing: 8,
            color: AppColors.accent,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Indicación informativa sin autocompletado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Copia o escribe el código de 6 dígitos recibido en tu correo electrónico.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        CinemaButton(
          text: 'Verificar Código',
          icon: Icons.check_circle_rounded,
          width: double.infinity,
          onPressed: _verifyRecoveryCode,
        ),
        const SizedBox(height: 14),

        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
            label: Text('Reenviar otro código', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            onPressed: _sendRecoveryCode,
          ),
        ),
      ],
    );
  }

  // VISTA PASO 3
  Widget _buildStepThreeNewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nueva Contraseña', style: AppTextStyles.heroDisplay.copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu nueva clave de acceso. Será protegida automáticamente con hasheo criptográfico SHA-256:',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 24),

        Text('Nueva Contraseña (mínimo 6 caracteres)', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Confirmar Nueva Contraseña', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.accent),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 28),

        CinemaButton(
          text: 'Restablecer y Guardar Clave',
          icon: Icons.shield_rounded,
          width: double.infinity,
          isLoading: _isLoading,
          onPressed: _resetPassword,
        ),
      ],
    );
  }
}
