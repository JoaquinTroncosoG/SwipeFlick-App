import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/brevo_email_service.dart';
import '../../../../data/services/mongodb_service.dart';
import '../../shell/screens/main_navigation_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || email.isEmpty || !email.contains('@') || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena los campos correctamente (mínimo 6 caracteres para contraseña)')),
      );
      return;
    }

    // Generar código OTP de 6 dígitos
    final otpCode = (100000 + Random().nextInt(900000)).toString();

    // Guardar cuenta pendiente en MongoDB Atlas con auto-expiración de 30 minutos
    final mongo = context.read<MongoDbService>();
    final brevo = context.read<BrevoEmailService>();
    final messenger = ScaffoldMessenger.of(context);

    await mongo.saveUser(
      id: 'usr_${email.hashCode.abs()}',
      username: username,
      email: email,
      passwordHash: password,
      isVerified: false,
      otpCode: otpCode,
    );

    // Enviar código por Brevo Email
    final sent = await brevo.sendVerificationCodeEmail(
      recipientEmail: email,
      recipientName: username,
      code: otpCode,
    );

    if (!sent && mounted) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Aviso Brevo: ${brevo.lastError ?? "No se pudo enviar el correo de verificación. Revisa la configuración de Brevo."}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Mostrar modal para ingresar el código de verificación
    if (mounted) {
      _showOtpVerificationDialog(
        username: username,
        email: email,
        password: password,
        initialOtp: otpCode,
      );
    }
  }

  void _showOtpVerificationDialog({
    required String username,
    required String email,
    required String password,
    required String initialOtp,
  }) {
    String currentOtp = initialOtp;
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: AppColors.accent),
                const SizedBox(width: 10),
                Text('Verificar tu Correo', style: AppTextStyles.h2.copyWith(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Hemos enviado un código de 6 dígitos a:',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Input de código PIN de 6 dígitos
                  TextField(
                    controller: otpController,
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

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
                            'Ingresa el código de 6 dígitos que enviamos a tu correo electrónico.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
                    label: Text(
                      'Reenviar Código',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    onPressed: () async {
                      final newOtp = (100000 + Random().nextInt(900000)).toString();
                      setDialogState(() {
                        currentOtp = newOtp;
                        otpController.clear();
                      });
                      final brevo = context.read<BrevoEmailService>();
                      final mongo = context.read<MongoDbService>();
                      await mongo.saveUser(
                        id: 'usr_${email.hashCode.abs()}',
                        username: username,
                        email: email,
                        passwordHash: password,
                        isVerified: false,
                        otpCode: newOtp,
                      );
                      final sent = await brevo.sendVerificationCodeEmail(
                        recipientEmail: email,
                        recipientName: username,
                        code: newOtp,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: sent ? AppColors.surfaceElevated : AppColors.error,
                            content: Text(
                              sent
                                  ? 'Nuevo código de verificación enviado a $email'
                                  : 'Aviso Brevo: ${brevo.lastError ?? "Error al enviar correo"}',
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () async {
                  final entered = otpController.text.trim();
                  if (entered != currentOtp) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('El código ingresado es incorrecto. Inténtalo de nuevo.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Código correcto: Proceder con registro en Auth y MongoDB
                  Navigator.of(ctx).pop();

                  final auth = context.read<AuthService>();
                  final mongo = context.read<MongoDbService>();
                  final brevo = context.read<BrevoEmailService>();
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  // Activar en MongoDB Atlas si está conectado
                  if (mongo.isConnected) {
                    await mongo.verifyAndActivateUser(
                      email: email,
                      enteredOtp: entered,
                    );
                  }

                  final success = await auth.signUp(
                    username: username,
                    email: email,
                    password: password,
                  );

                  if (success) {
                    final user = auth.currentUser;
                    if (user != null) {
                      // Persistir como verificado definitivo en MongoDB Atlas
                      await mongo.saveUser(
                        id: user.id,
                        username: user.username,
                        email: user.email,
                        passwordHash: password,
                        avatarUrl: user.avatarUrl,
                        isVerified: true,
                      );

                      // Correo de bienvenida final
                      brevo.sendWelcomeEmail(
                        recipientEmail: user.email,
                        recipientName: user.username,
                      );
                    }

                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.surfaceElevated,
                        content: Text('¡Cuenta verificada y registrada en MongoDB Atlas con éxito! 🍿'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
                      (route) => false,
                    );
                  }
                },
                child: const Text('Verificar y Activar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Únete a SwipeFlick', style: AppTextStyles.heroDisplay.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                'Guarda tus favoritas y sincroniza salas con tus amigos.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 28),

              Text('Nombre de Usuario', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Tu apodo o nombre',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 18),

              Text('Correo Electrónico', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'tu@email.com',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 18),

              Text('Contraseña', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),

              CinemaButton(
                text: 'Registrarme',
                icon: Icons.check_circle_rounded,
                width: double.infinity,
                isLoading: auth.isLoading,
                onPressed: _submitRegister,
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Ya tienes una cuenta?', style: AppTextStyles.bodySecondary),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text('Inicia sesión', style: AppTextStyles.button.copyWith(color: AppColors.accent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
