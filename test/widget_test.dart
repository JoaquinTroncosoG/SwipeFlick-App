import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swipeflick/core/constants/app_constants.dart';
import 'package:swipeflick/data/services/auth_service.dart';
import 'package:swipeflick/data/services/brevo_email_service.dart';
import 'package:swipeflick/data/services/favorites_service.dart';
import 'package:swipeflick/data/services/mongodb_service.dart';
import 'package:swipeflick/data/services/rate_limit_service.dart';
import 'package:swipeflick/data/services/room_service.dart';
import 'package:swipeflick/data/services/tmdb_service.dart';
import 'package:swipeflick/main.dart';

void main() {
  testWidgets('SwipeFlick app smoke test and title check', (WidgetTester tester) async {
    final tmdbService = TmdbService();
    final authService = AuthService();
    final favoritesService = FavoritesService();
    final roomService = RoomService();
    final brevoEmailService = BrevoEmailService();
    final mongoDbService = MongoDbService();
    final rateLimitService = RateLimitService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<FavoritesService>.value(value: favoritesService),
          ChangeNotifierProvider<RoomService>.value(value: roomService),
          ChangeNotifierProvider<BrevoEmailService>.value(value: brevoEmailService),
          ChangeNotifierProvider<MongoDbService>.value(value: mongoDbService),
          ChangeNotifierProvider<RateLimitService>.value(value: rateLimitService),
          Provider<TmdbService>.value(value: tmdbService),
        ],
        child: const SwipeFlickApp(),
      ),
    );

    await tester.pump();

    // Sin usuario activo: Debe iniciar directamente en la pantalla de Login
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('¿No tienes una cuenta?'), findsOneWidget);
  });
}
