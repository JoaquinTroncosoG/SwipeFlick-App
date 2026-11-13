import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipeflick/data/services/mongodb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Probar inicializacion y operaciones con MongoDB Atlas o modo desacoplado', () async {
    SharedPreferences.setMockInitialValues({'mongodb_uri': ''});
    final mongo = MongoDbService();
    await mongo.init();

    if (!mongo.isConfigured) {
      // Modo seguro: cuando no se configuran variables de entorno en el entorno de pruebas
      expect(mongo.isConnected, isFalse);
      expect(mongo.status, MongoDbStatus.unconfigured);
      return;
    }

    final connected = await mongo.connect(uri: mongo.uri!, dbName: 'swipeflick');
    expect(connected, isTrue);
    expect(mongo.isConnected, isTrue);

    // Guardar usuario de prueba
    final saved = await mongo.saveUser(
      id: 'usr_test_123',
      username: 'Tester Cinefilo',
      email: 'test_cine@swipeflick.app',
      passwordHash: 'hashed_pass_123',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    );
    expect(saved, isTrue);

    // Buscar usuario guardado
    final user = await mongo.findUserByEmail('test_cine@swipeflick.app');
    expect(user, isNotNull);
    expect(user!['username'], 'Tester Cinefilo');
    expect(user['email'], 'test_cine@swipeflick.app');

    // Guardar usuario pendiente no verificado con expiración de 30 min (REQUERIMIENTO 2)
    final savedPending = await mongo.saveUser(
      id: 'usr_pending_789',
      username: 'Pending User',
      email: 'pending_30min@swipeflick.app',
      passwordHash: 'pending_pwd_123',
      isVerified: false,
      otpCode: '456789',
    );
    expect(savedPending, isTrue);

    final pendingDoc = await mongo.findUserByEmail('pending_30min@swipeflick.app');
    expect(pendingDoc, isNotNull);
    expect(pendingDoc!['isVerified'], isFalse);
    expect(pendingDoc['verificationExpiresAt'], isNotNull);

    // Verificar y activar usuario dentro del plazo de 30 minutos
    final activated = await mongo.verifyAndActivateUser(
      email: 'pending_30min@swipeflick.app',
      enteredOtp: '456789',
    );
    expect(activated, isTrue);

    final activatedDoc = await mongo.findUserByEmail('pending_30min@swipeflick.app');
    expect(activatedDoc!['isVerified'], isTrue);
    expect(activatedDoc['otpCode'], isNull);
    expect(activatedDoc['verificationExpiresAt'], isNull);

    await mongo.disconnect();
    expect(mongo.isConnected, isFalse);
  }, timeout: const Timeout(Duration(seconds: 25)));
}
