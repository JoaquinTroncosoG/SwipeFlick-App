# 🎬 SwipeFlick — App de Películas (MVP)

> **"¿Qué vemos hoy?"** — Resuelto de forma divertida, adictiva y social mediante una mecánica tipo Tinder para descubrir películas de forma individual y en salas grupales.

---

## 📋 Resumen del Proyecto

SwipeFlick es una aplicación móvil desarrollada en **Flutter + Dart**, siguiendo una arquitectura **Feature-First Clean Architecture** y basada estrictamente en los requerimientos del *Informe del Proyecto*, *Informe de Diseño UI/UX* y *Cronograma de Desarrollo MVP*.

### Modos Principales
1. **Modo Individual (Solo Swipe)**:
   - **Paso 1: Categorías / Géneros**: Desliza a la derecha (Like) o izquierda (Pass) entre categorías de películas (Acción, Terror, Comedia, Ciencia Ficción, etc.).
   - **Paso 2: Películas Filtradas**: Una vez elegidas las categorías, se presentan películas coincidentes.
   - **Paso 3: Ficha de Resultado**: Al aprobar una película, se despliega su ficha completa con póster fullscreen, sinopsis, calificaciones, streaming con atribución oficial a JustWatch y reseñas comunitarias.
   - **Monetización Freemium**: Anuncios nativos no intrusivos entre bloques de películas con cuenta atrás de 5 segundos (nunca mostrados en salas grupales).

2. **Modo Salas Grupales (Tiempo Real)**:
   - **Crear Sala**: Configuración de capacidad máxima (2, 5, 10, 20 personas) y umbral de coincidencia de categorías (1 a 5). Genera código único alfanumérico de 6 dígitos (ej: `SF89K2`).
   - **Unirse a Sala**: Ingreso directo mediante código alfanumérico.
   - **Lobby en Vivo (Presence)**: Visualización en tiempo real de participantes conectados, estado "listo" y anfitrión. Incluye botón para simular participantes y facilitar pruebas instantáneas.
   - **Fase 1 (Categorías)**: Todos deslizan categorías simultáneamente a su propio ritmo. Al alcanzar el umbral de coincidencias unánimes, se avanza a la siguiente fase.
   - **Fase 2 (Películas)**: Se presentan películas de los géneros aprobados por el grupo. La primera película aprobada unánimemente por **todos** los participantes es la **ganadora**.
   - **Fallback Randomizer**: Si la baraja se agota sin coincidencia unánime, un algoritmo aleatorio selecciona la película ideal para el grupo.
   - **Pantalla de Match**: Animación de confeti, ficha completa de la película ganadora y enlaces de streaming.

3. **Biblioteca y Favoritos**:
   - Lista personal de películas guardadas ("Mi Lista").
   - Historial de películas coincidentes de sesiones individuales y grupales.

4. **Perfil y Configuración**:
   - Gestión de cuenta y modo invitado sin fricción.
   - Soporte para TMDB API Key propia (con fallback offline completo y caché local de 24 horas).
   - Estado de sincronización en tiempo real con Supabase.

---

## 🎨 Sistema de Diseño (Cinema Amber)

Basado en la regla **60-30-10** del *Informe de Diseño*:
- **60% Fondo**: Deep Charcoal (`#121212`)
- **30% Superficie**: Dark & Elevated (`#1E1E1E` / `#2C2C2C`)
- **10% Acento**: Cinema Warm Amber (`#E8A849` / `#F0BC6A`)
- **Tipografía**:
  - Títulos y Hero: **Playfair Display** (elegancia cinematográfica)
  - UI y Cuerpo: **Inter** (alta legibilidad)

---

## 🏗️ Arquitectura Técnica

Estructura de directorios Feature-First:

```text
Proyecto/
├── lib/
│   ├── core/
│   │   ├── constants/           # Colores (60-30-10), estilos de texto, constantes
│   │   ├── theme/               # ThemeData oscuro cinemático
│   │   └── widgets/             # CinemaButton, SwipeCard (Tinder physics), ConfettiOverlay, etc.
│   ├── data/
│   │   ├── mock/                # Catálogo offline enriquecido con pósters y streaming
│   │   ├── models/              # Modelos: Movie, Genre, Room, Member, Review, Provider
│   │   └── services/            # TmdbService (cache 24h), RoomService (Matching Engine), AuthService, FavoritesService
│   ├── ui/
│   │   └── features/
│   │       ├── auth/            # Login, Registro, Recuperación
│   │       ├── favorites/       # Biblioteca y Lista de Deseos
│   │       ├── home/            # Home con Hero Banner, Búsqueda en tiempo real y Tendencias
│   │       ├── movie_detail/    # Ficha completa, JustWatch streaming, Reseñas
│   │       ├── profile/         # Perfil, Conexiones TMDB y Supabase
│   │       ├── room/            # Salas: Creación, Lobby, Fase 1 Categorías, Fase 2 Películas, Match
│   │       ├── shell/           # Navigation Bar de 5 pestañas
│   │       └── swipe/           # Modo Individual de 2 pasos + Anuncios
│   └── main.dart                # Punto de entrada MultiProvider
└── test/
    ├── room_matching_test.dart  # Tests unitarios del motor de salas y randomizer
    └── widget_test.dart         # Tests de widgets y navegación
```

---

## 🚀 Cómo Ejecutar la Aplicación

### Requisitos Previos
- **Flutter SDK** (3.24+ o compatible con Dart 3.x)
- Dispositivo Android (emulador o físico), navegador Web, o Windows Desktop.

### Pasos
1. Entrar a la carpeta del proyecto:
   ```bash
   cd Proyecto
   ```
2. Obtener las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecutar los tests para verificar la integridad del código:
   ```bash
   flutter test
   ```
4. Lanzar la aplicación:
   ```bash
   flutter run
   ```
   *(o `flutter run -d edge` para probar rápidamente en el navegador web)*

---

## ⚖️ Atribución Legal
- Este producto utiliza la API de TMDB pero no está certificado ni respaldado por TMDB.
- Los datos y logos de disponibilidad en streaming son suministrados por **JustWatch** vía TMDB, cumpliendo los términos oficiales de servicio.
