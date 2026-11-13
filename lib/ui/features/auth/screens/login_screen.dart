import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/security_helper.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/favorites_service.dart';
import '../../../../data/services/mongodb_service.dart';
import '../../../../data/services/rate_limit_service.dart';
import '../../shell/screens/main_navigation_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    final rateLimit = context.read<RateLimitService>();
    final messenger = ScaffoldMessenger.of(context);

    // 1. Verificar si la cuenta está bloqueada por rate limit
    if (rateLimit.isLockedOut) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            '⚠️ Demasiados intentos fallidos (${RateLimitService.maxAttempts}/${RateLimitService.maxAttempts}). Inténtalo en ${rateLimit.remainingLockoutFormatted}.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final rawEmail = _emailController.text.trim();
    final password = _passwordController.text;

    // 2. Sanitización estricta contra NoSQL Injection
    final safeEmail = SecurityHelper.sanitizeEmail(rawEmail);
    if (safeEmail == null) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Por favor ingresa un correo electrónico válido (sin caracteres prohibidos)'),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Por favor ingresa tu contraseña'),
        ),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final mongo = context.read<MongoDbService>();

    // 3. Validación de credenciales: comprobar contra MongoDB Atlas o AuthService
    bool credentialsValid = false;

    if (mongo.isConnected || await mongo.ensureConnected()) {
      final verified = await mongo.verifyUserCredentials(safeEmail, password);
      if (verified) {
        credentialsValid = true;
      }
    }

    // Fallback con usuario autenticado en la sesión si no hay conexión a internet
    if (!credentialsValid) {
      if (auth.verifyCurrentPassword(password) &&
          auth.currentUser?.email.toLowerCase() == safeEmail.toLowerCase()) {
        credentialsValid = true;
      }
    }

    // 4. Procesar resultado
    if (credentialsValid) {
      await rateLimit.recordSuccessfulLogin();
      final userDoc = await mongo.findUserByEmail(safeEmail);
      final remoteUsername = userDoc?['username'] as String?;
      final remoteAvatar = userDoc?['avatarUrl'] as String?;

      await auth.signIn(
        email: safeEmail,
        password: password,
        remoteUsername: remoteUsername,
        remoteAvatarUrl: remoteAvatar,
      );

      if (mounted) {
        await context.read<FavoritesService>().attachUser(safeEmail, mongo);
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Text('¡Bienvenido de nuevo! 🎬'),
            duration: Duration(seconds: 2),
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          );
        }
      }
    } else {
      // Intento fallido -> Incrementar Rate Limiter
      final justLocked = await rateLimit.recordFailedAttempt();
      if (justLocked) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              '🚨 Has alcanzado 5 intentos fallidos. Acceso bloqueado. Inténtalo en ${rateLimit.remainingLockoutFormatted}.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        final remaining = rateLimit.remainingAttempts;
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              'Credenciales incorrectas. Te quedan $remaining ${remaining == 1 ? "intento" : "intentos"} antes del bloqueo de 5 minutos.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final rateLimit = context.watch<RateLimitService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Iniciar Sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.movie_filter_rounded, size: 48, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Bienvenido a SwipeFlick', style: AppTextStyles.heroDisplay.copyWith(fontSize: 26)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Descubre películas deslizando a tu ritmo',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Banner de seguridad: Bloqueo activo o intentos fallidos
              if (rateLimit.isLockedOut) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acceso temporalmente bloqueado',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Inténtalo de nuevo en: ${rateLimit.remainingLockoutFormatted}',
                              style: AppTextStyles.bodySecondary.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (rateLimit.failedAttempts > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Seguridad: ${rateLimit.failedAttempts}/5 intentos fallidos (te quedan ${rateLimit.remainingAttempts} antes del bloqueo)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Text('Correo Electrónico', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'ejemplo@correo.com',
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
                  hintText: '••••••••',
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
              const SizedBox(height: 10),

              // Línea de recuperación de contraseña debajo de la casilla
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _navigateToForgotPassword,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              CinemaButton(
                text: rateLimit.isLockedOut ? 'Bloqueado (${rateLimit.remainingLockoutFormatted})' : 'Ingresar',
                icon: rateLimit.isLockedOut ? Icons.lock_clock_rounded : Icons.login_rounded,
                width: double.infinity,
                isLoading: auth.isLoading,
                onPressed: _submitLogin,
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿No tienes una cuenta?', style: AppTextStyles.bodySecondary),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: Text('Regístrate aquí', style: AppTextStyles.button.copyWith(color: AppColors.accent)),
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
