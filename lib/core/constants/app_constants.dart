class AppConstants {
  static const String appName = 'SwipeFlick';
  static const String appTagline = 'Descubre qué ver hoy, solo o con amigos';
  static const String appVersion = '1.12.0';
  static const int changeCounter = 13;
  static const String appVersionDisplay = 'v1.12.0 • Cambio #13';

  /// Registro histórico de iteraciones y cambios desarrollados
  static const List<Map<String, String>> changeLog = [
    {
      'version': '1.0.0 (Base)',
      'title': 'Lanzamiento Inicial MVP',
      'description': 'Arquitectura por capas, autenticación, swipe individual, creación de salas y detalle cinematográfico.',
    },
    {
      'version': '1.0.1 (Cambio #1)',
      'title': 'Salas Grupales & Filtros de Género',
      'description': 'Pantalla de ganadores de categorías en sala, confeti, corrección de afiches TMDB (Alien vs John Wick) y filtrado estricto con baraja dinámica.',
    },
    {
      'version': '1.1.0 (Cambio #2)',
      'title': 'Diccionario de Búsqueda y Normalización de Géneros',
      'description': 'Buscador inteligente tolerante a tildes y faltas (ej. "accion", "ficcion", "animacion"), diccionario de sinónimos ("miedo", "disparos", "scifi", "dibujos", "triller") y contador de versiones visible en UI.',
    },
    {
      'version': '1.2.0 (Cambio #3)',
      'title': 'Perfil de Usuario, Seguridad y Configuración Avanzada',
      'description': 'Personalización de avatar/nombre, nueva sección de Seguridad (cambio de correo y contraseña), y compresión de opciones técnicas/backend en acordeón plegable de Configuración Avanzada.',
    },
    {
      'version': '1.3.0 (Cambio #4)',
      'title': 'Seguridad Estricta, Galería Nativa & Preparación MongoDB/Brevo',
      'description': 'Contraseña actual obligatoria con doble confirmación de clave nueva, acceso a galería de fotos Android/iOS vía ImagePicker, servicio transaccional Brevo Email y panel de conexión MongoDB.',
    },
    {
      'version': '1.4.0 (Cambio #5)',
      'title': 'Cierre de Sesión Directo & Conexión MongoDB Atlas',
      'description': 'Redirección obligatoria al Login al cerrar sesión con reseteo de historial de navegación, integración nativa de MongoDbService (mongo_dart) para usuarios y salas, y panel de conexión en tiempo real.',
    },
    {
      'version': '1.5.0 (Cambio #6)',
      'title': 'MongoDB Atlas en Vivo & Verificación de Cuenta por Correo (OTP)',
      'description': 'Conexión activa con el cluster MongoDB Atlas (swiperflick.xerxhzz.mongodb.net), sistema de códigos OTP de 6 dígitos para validación de cuentas nuevas con Brevo Email y persistencia en la nube.',
    },
    {
      'version': '1.6.0 (Cambio #7)',
      'title': 'Criptografía SHA-256, Protección NoSQL & Rate Limiting Exponencial',
      'description': 'Hasheo criptográfico con sal para contraseñas de usuarios, sanitización estricta contra inyecciones NoSQL (\$gt, \$ne, regex), integración de API Key de Brevo en producción, y Rate Limiter con bloqueo de 5 intentos e incrementos progresivos (+5 min).',
    },
    {
      'version': '1.7.0 (Cambio #8)',
      'title': 'Recuperación de Contraseña con OTP & Auto-Purga MongoDB (30 min)',
      'description': 'Flujo completo de "¿Olvidaste tu contraseña?" con verificación de código Brevo y actualización hasheada de clave; límite de 30 minutos para cuentas no verificadas con auto-expiración y purga automática en MongoDB.',
    },
    {
      'version': '1.8.0 (Cambio #9)',
      'title': 'Despliegue en la Nube con Render (Docker, Blueprint & Variables de Entorno)',
      'description': 'Configuración de producción para Render Cloud (Dockerfile multi-etapa, NGINX / Cloud Server, render.yaml), verificación de variables de entorno (MONGODB_URI, BREVO_API_KEY) y logs de diagnóstico en consola.',
    },
    {
      'version': '1.9.0 (Cambio #10)',
      'title': 'Compatibilidad Multi-SDK y Despliegue Render con Flutter Stable',
      'description': 'Resolución de incompatibilidad de SDK en compilación Docker (flexibilización sdk: >=3.5.0 <4.0.0), actualización a imagen base ghcr.io/cirruslabs/flutter:stable y desacoplamiento de pubspec.lock para resolución limpia de dependencias en Render.',
    },
    {
      'version': '1.10.0 (Cambio #11)',
      'title': 'Pipeline de Compilación APK Android & CI/CD Automatizado',
      'description': 'Configuración de permisos Android (Internet, almacenamiento, galería), optimización de manifiesto con nombre SwipeFlick y pipeline CI/CD en GitHub Actions para generación automática de APK release instalable en teléfonos móviles.',
    },
    {
      'version': '1.11.0 (Cambio #12)',
      'title': 'Health Check UptimeRobot, Flujo Estricto de Autenticación & Conexión Nativa Atlas/Brevo',
      'description': 'Endpoint /health para monitor UptimeRobot 24/7 en Render; inicio estricto en Login sin cuentas demo/invitadas precargadas; remoción de autocompletado en código de verificación OTP; inyección de credenciales Atlas/Brevo en APK e informe de autorizaciones IP.',
    },
    {
      'version': '1.12.0 (Cambio #13)',
      'title': 'Corrección Remitente Verificado Brevo & Desbloqueo de Destinatarios',
      'description': 'Configuración de remitente predeterminado con cuenta verificada en Brevo (joaquin1troncoso@gmail.com) reemplazando noreply no autenticado; desbloqueo de contactos suprimidos y entrega garantizada de correos OTP en bandejas de entrada Gmail.',
    },
  ];

  // TMDB URLs
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String tmdbBackdropBaseUrl = 'https://image.tmdb.org/t/p/w780';
  static const String tmdbOriginalImageUrl = 'https://image.tmdb.org/t/p/original';

  // JustWatch Attribution (Obligatorio por términos de TMDB)
  static const String justWatchAttribution = 'Datos de streaming suministrados por JustWatch vía TMDB';
  static const String justWatchUrl = 'https://www.justwatch.com';

  // Configuración de Salas
  static const List<int> allowedRoomCapacities = [2, 5, 10, 20];
  static const List<int> allowedMatchThresholds = [1, 2, 3, 4, 5];
  static const int defaultMaxMembers = 5;
  static const int defaultMatchThreshold = 2;
  static const Duration roomCodeExpiration = Duration(minutes: 30);
  static const Duration roomAutoDestroyDuration = Duration(minutes: 5);

  // Anuncios (Monetización Freemium - Solo en modo Individual)
  static const int adIntervalMovieSwipes = 12; // Cada 12 swipes
  static const int adCountdownSeconds = 5;      // 5 segundos para cerrar
}
