class AppConstants {
  static const String appName = 'SwipeFlick';
  static const String appTagline = 'Descubre qué ver hoy, solo o con amigos';
  static const String appVersion = '1.20.0';
  static const int changeCounter = 21;
  static const String appVersionDisplay = 'v1.20.0 • Cambio #21';

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
    {
      'version': '1.13.0 (Cambio #14)',
      'title': 'Salas Grupales Reales en MongoDB Atlas & Sincronización Multidispositivo',
      'description': 'Creación y persistencia de salas reales en la colección "rooms" de MongoDB Atlas; sincronización en tiempo real por polling cada 2s para lobbies y votaciones simultáneas entre celulares; eliminación de usuarios mock/simulados y mensajes específicos de validación de código.',
    },
    {
      'version': '1.14.0 (Cambio #15)',
      'title': 'Votación Atómica Multijugador, Baraja Compartida & Consenso Inmediato',
      'description': 'Registro atómico de votos (addToSet) en MongoDB Atlas para evitar sobreescritura entre celulares; baraja compartida única de películas (movieDeck) para todos los miembros; evaluación continua de consenso unánime y transición instantánea a coincidencias.',
    },
    {
      'version': '1.15.0 (Cambio #16)',
      'title': 'Salida Dinámica de Salas, Avatares Fotográficos en Vivo & Biblioteca en la Nube',
      'description': 'Sincronización de abandono y cierre de salas en MongoDB Atlas (el anfitrión ve salir a participantes y los invitados son devueltos con aviso si la sala cierra); soporte universal de avatares fotográficos de galería (Base64) visibles en todas las pantallas de sala; y persistencia de Mi Lista en MongoDB Atlas sin películas mock para cuentas nuevas.',
    },
    {
      'version': '1.16.0 (Cambio #17)',
      'title': 'Catálogo Completo TMDB en Vivo & Avisos Emergentes Amarillos de 5 Segundos',
      'description': 'Conexión activa con el catálogo completo de TMDB (+800.000 títulos dinámicos en español con barajas de hasta 60 películas por combinación de géneros, tendencias y búsqueda en vivo); rediseño de avisos emergentes (CinemaSnackBar) con texto en color amarillo cinemático (#E8A849) y duración ampliada a 5 segundos completos para lectura cómoda.',
    },
    {
      'version': '1.17.0 (Cambio #18)',
      'title': 'Salas Personalizables, Filtro de Matches Vistas & Restauración de Afiches de Categorías',
      'description': 'Capacidad máxima de sala personalizable de 2 a 50 participantes con selector interactivo y chips rápidos; nueva opción para el host "¿Considerar películas matches?" que analiza la biblioteca y matches de todos los miembros en la nube para omitir títulos ya vistos; resolución del bug de tarjetas de categorías enriqueciendo los 19 géneros de TMDB con sus afiches oficiales verificados; y simplificación de Perfil retirando el botón de iniciar sesión para dejar solo el cierre de sesión.',
    },
    {
      'version': '1.18.0 (Cambio #19)',
      'title': 'Géneros Visibles en Todos los Matches, Borrado Total & Deslizar para Eliminar (Spotify)',
      'description': 'Corrección de géneros cinematográficos en todas las películas de TMDB (auto-resolución desde genreIds en español); botón de "Borrar Historial" en AppBar con diálogo de confirmación; animación Dismissible estilo Spotify para deslizar a la izquierda con recuadro rojo y basurero al eliminar un título específico; y texto explicativo al pie de la lista de matches.',
    },
    {
      'version': '1.19.0 (Cambio #20)',
      'title': 'Candado Atómico First-Match-Wins en Atlas, Baraja Compartida Estricta y Ganador Canónico',
      'description': 'Resolución de discrepancia en resultados grupales eliminando condiciones de carrera: candado atómico en MongoDB Atlas donde la primera película en alcanzar consenso unánime queda blindada permanentemente impidiendo sobreescrituras; sincronización estricta de la baraja generada por el anfitrión para todos los invitados; priorización cronológica del voto decisivo; y seguro de navegación única anti-rebote.',
    },
    {
      'version': '1.20.0 (Cambio #21)',
      'title': 'Actualización Diaria de Catálogo (24h) y Filtro "Solo en Streaming" (Descartar Cine)',
      'description': 'Actualización automática del catálogo cada 24 horas sincronizada con el trending diario de TMDB (/trending/movie/day a las 00:00 UTC), expiración diaria de caché y rotación de páginas según el día del año; nuevo filtro "Solo en Streaming" en modo individual y salas grupales para omitir películas que solo están en cines y sugerir únicamente títulos disponibles en plataformas (Netflix, Disney+, Max, Prime Video, etc.); integración multi-región de JustWatch (CL, MX, ES, AR, CO, US); y pull-to-refresh en la pantalla de inicio.',
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
