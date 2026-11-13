import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/brevo_email_service.dart';
import 'data/services/favorites_service.dart';
import 'data/services/mongodb_service.dart';
import 'data/services/rate_limit_service.dart';
import 'data/services/room_service.dart';
import 'data/services/tmdb_service.dart';
import 'ui/features/auth/screens/login_screen.dart';
import 'ui/features/shell/screens/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar servicios
  final tmdbService = TmdbService();
  await tmdbService.init();

  final authService = AuthService();
  await authService.init();

  final favoritesService = FavoritesService();
  await favoritesService.init();

  final brevoEmailService = BrevoEmailService();
  await brevoEmailService.init();

  final mongoDbService = MongoDbService();
  await mongoDbService.init();

  final rateLimitService = RateLimitService();
  await rateLimitService.init();

  final roomService = RoomService();
  roomService.attachMongoDb(mongoDbService);
  authService.attachMongoDb(mongoDbService);
  await favoritesService.attachUser(authService.currentUser?.email, mongoDbService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<FavoritesService>.value(value: favoritesService),
        ChangeNotifierProvider<BrevoEmailService>.value(value: brevoEmailService),
        ChangeNotifierProvider<MongoDbService>.value(value: mongoDbService),
        ChangeNotifierProvider<RateLimitService>.value(value: rateLimitService),
        ChangeNotifierProvider<RoomService>.value(value: roomService),
        Provider<TmdbService>.value(value: tmdbService),
      ],
      child: const SwipeFlickApp(),
    ),
  );
}

class SwipeFlickApp extends StatelessWidget {
  const SwipeFlickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: authService.isAuthenticated
              ? const MainNavigationShell()
              : const LoginScreen(),
        );
      },
    );
  }
}
