import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../core/widgets/swipe_card.dart';
import '../../../../data/models/genre_model.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../data/services/favorites_service.dart';
import '../../../../data/services/tmdb_service.dart';
import '../../movie_detail/screens/movie_detail_screen.dart';
import 'ad_interstitial_dialog.dart';

enum SoloSwipeStep {
  categories, // Paso 1: Swipe de Categorías
  movies,     // Paso 2: Swipe de Películas filtradas
}

class SoloSwipeScreen extends StatefulWidget {
  const SoloSwipeScreen({super.key});

  @override
  State<SoloSwipeScreen> createState() => _SoloSwipeScreenState();
}

class _SoloSwipeScreenState extends State<SoloSwipeScreen> {
  SoloSwipeStep _currentStep = SoloSwipeStep.categories;
  final SwipeCardController _cardController = SwipeCardController();

  List<GenreModel> _categoryDeck = [];
  final List<GenreModel> _approvedGenres = [];
  int _categoryDeckIndex = 0;
  bool _streamingOnly = false;

  List<MovieModel> _movieDeck = [];
  int _movieDeckIndex = 0;
  int _swipesCountSinceLastAd = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final tmdb = context.read<TmdbService>();
    final genres = await tmdb.getGenres();
    setState(() {
      _categoryDeck = List.from(genres);
      _categoryDeckIndex = 0;
      _approvedGenres.clear();
      _isLoading = false;
    });
  }

  void _onCategorySwipe(bool approved) {
    if (_categoryDeckIndex >= _categoryDeck.length) return;

    final currentGenre = _categoryDeck[_categoryDeckIndex];
    if (approved) {
      _approvedGenres.add(currentGenre);
    }

    setState(() {
      _categoryDeckIndex++;
    });

    // Si ya aprobó al menos 2 categorías o agotó las categorías, pasamos a películas
    if (_approvedGenres.length >= 2 || _categoryDeckIndex >= _categoryDeck.length) {
      _transitionToMoviesStep();
    }
  }

  Future<void> _transitionToMoviesStep() async {
    setState(() => _isLoading = true);
    final tmdb = context.read<TmdbService>();
    final genreIds = _approvedGenres.map((g) => g.id).toList();
    final movies = await tmdb.discoverMoviesByGenres(
      genreIds,
      streamingOnly: _streamingOnly,
    );

    setState(() {
      _movieDeck = List.from(movies);
      _movieDeckIndex = 0;
      _currentStep = SoloSwipeStep.movies;
      _isLoading = false;
    });
  }

  void _onMovieSwipe(bool approved) {
    if (_movieDeckIndex >= _movieDeck.length) return;

    final swipedMovie = _movieDeck[_movieDeckIndex];
    _swipesCountSinceLastAd++;

    if (approved) {
      // ¡Aprobó una película! Guardar en historial de matches y abrir resultado
      context.read<FavoritesService>().addMatchToHistory(swipedMovie);
      _openMovieResult(swipedMovie);
      return;
    }

    setState(() {
      _movieDeckIndex++;
    });

    // Comprobar monetización: mostrar anuncio cada 12 swipes
    if (_swipesCountSinceLastAd >= AppConstants.adIntervalMovieSwipes) {
      _swipesCountSinceLastAd = 0;
      _showInterstitialAd();
    }
  }

  void _showInterstitialAd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdInterstitialDialog(
        onAdClosed: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _openMovieResult(MovieModel movie) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(movie: movie),
      ),
    );
  }

  void _resetFlow() {
    setState(() {
      _currentStep = SoloSwipeStep.categories;
      _categoryDeckIndex = 0;
      _approvedGenres.clear();
      _movieDeckIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _currentStep == SoloSwipeStep.categories
                  ? 'Paso 1: ¿Qué te apetece hoy?'
                  : 'Paso 2: Encuentra tu película',
              style: AppTextStyles.h2.copyWith(fontSize: 16),
            ),
            Text(
              _currentStep == SoloSwipeStep.categories
                  ? '${_approvedGenres.length} categorías elegidas'
                  : '${_movieDeck.length - _movieDeckIndex} películas restantes',
              style: AppTextStyles.caption.copyWith(color: AppColors.accent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Reiniciar selección',
            onPressed: _resetFlow,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Barra de progreso sutil
                  _buildProgressBar(),

                  // Selector rápido de filtro Streaming (Paso 1)
                  if (_currentStep == SoloSwipeStep.categories)
                    _buildStreamingFilterBadge(),

                  // Contenedor principal de tarjetas tipo Tinder
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _currentStep == SoloSwipeStep.categories
                          ? _buildCategoryCardStack()
                          : _buildMovieCardStack(),
                    ),
                  ),

                  // Botones de acción inferiores (Nope / Me Gusta)
                  _buildActionControls(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressBar() {
    double progress = 0.0;
    if (_currentStep == SoloSwipeStep.categories && _categoryDeck.isNotEmpty) {
      progress = (_categoryDeckIndex / _categoryDeck.length).clamp(0.0, 1.0);
    } else if (_currentStep == SoloSwipeStep.movies && _movieDeck.isNotEmpty) {
      progress = (_movieDeckIndex / _movieDeck.length).clamp(0.0, 1.0);
    }

    return Container(
      height: 3,
      width: double.infinity,
      color: AppColors.surfaceBorder,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: AppColors.accent),
      ),
    );
  }

  Widget _buildStreamingFilterBadge() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _streamingOnly = !_streamingOnly;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(top: 8, bottom: 2, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _streamingOnly ? AppColors.accentSubtle : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _streamingOnly ? AppColors.accent : AppColors.surfaceBorder,
            width: _streamingOnly ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _streamingOnly ? Icons.live_tv_rounded : Icons.tv_off_rounded,
              size: 16,
              color: _streamingOnly ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _streamingOnly
                  ? 'Filtro: Solo en Streaming (Excluir cine)'
                  : 'Filtro: Todo el catálogo (Cine + Streaming)',
              style: AppTextStyles.caption.copyWith(
                color: _streamingOnly ? AppColors.accent : AppColors.textSecondary,
                fontWeight: _streamingOnly ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              _streamingOnly ? Icons.check_circle_rounded : Icons.tune_rounded,
              size: 14,
              color: _streamingOnly ? AppColors.accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCardStack() {
    if (_categoryDeckIndex >= _categoryDeck.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            Text('¡Categorías listas!', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Has elegido ${_approvedGenres.length} géneros.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
            CinemaButton(
              text: 'Ver Películas',
              icon: Icons.movie_filter_rounded,
              onPressed: _transitionToMoviesStep,
            ),
          ],
        ),
      );
    }

    final topCategory = _categoryDeck[_categoryDeckIndex];
    final nextCategory = _categoryDeckIndex + 1 < _categoryDeck.length
        ? _categoryDeck[_categoryDeckIndex + 1]
        : null;

    return Stack(
      children: [
        // Siguiente tarjeta de fondo
        if (nextCategory != null)
          Positioned.fill(
            child: Transform.scale(
              scale: 0.94,
              child: _buildCategoryCardContent(nextCategory),
            ),
          ),

        // Tarjeta superior interactiva con SwipeCard
        Positioned.fill(
          child: SwipeCard(
            controller: _cardController,
            isTopCard: true,
            onSwipeLeft: () => _onCategorySwipe(false),
            onSwipeRight: () => _onCategorySwipe(true),
            child: _buildCategoryCardContent(topCategory),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCardContent(GenreModel genre) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (genre.samplePosterUrl != null && genre.samplePosterUrl!.isNotEmpty)
              CinemaImage(
                imageUrl: genre.samplePosterUrl!,
                fit: BoxFit.cover,
                fallbackTitle: genre.name,
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2B211D), Color(0xFF131118)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Text(genre.emoji, style: const TextStyle(fontSize: 72)),
                ),
              ),

            // Gradiente oscuro envolvente
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.posterGradient,
              ),
            ),

            // Contenido informativo de la categoría
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    genre.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    genre.name,
                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    genre.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.swipe_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Desliza derecha para elegir, izquierda para pasar',
                        style: AppTextStyles.caption.copyWith(color: AppColors.accentHover),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCardStack() {
    if (_movieDeckIndex >= _movieDeck.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_outlined, size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            Text('No hay más películas por ahora', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              '¿Quieres reiniciar o cambiar de géneros?',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
            CinemaButton(
              text: 'Reiniciar Selección',
              icon: Icons.refresh_rounded,
              onPressed: _resetFlow,
            ),
          ],
        ),
      );
    }

    final topMovie = _movieDeck[_movieDeckIndex];
    final nextMovie = _movieDeckIndex + 1 < _movieDeck.length
        ? _movieDeck[_movieDeckIndex + 1]
        : null;

    return Stack(
      children: [
        if (nextMovie != null)
          Positioned.fill(
            child: Transform.scale(
              scale: 0.94,
              child: _buildMovieCardContent(nextMovie),
            ),
          ),
        Positioned.fill(
          child: SwipeCard(
            controller: _cardController,
            isTopCard: true,
            onSwipeLeft: () => _onMovieSwipe(false),
            onSwipeRight: () => _onMovieSwipe(true),
            child: _buildMovieCardContent(topMovie),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCardContent(MovieModel movie) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CinemaImage(
              imageUrl: movie.fullPosterUrl,
              fit: BoxFit.cover,
              fallbackTitle: movie.title,
            ),
            // Gradiente cinematográfico hacia abajo
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.posterGradient,
              ),
            ),
            // Badge flotante de Rating TMDB en esquina superior derecha
            Positioned(
              top: 20,
              right: 20,
              child: RatingBadge(rating: movie.rating),
            ),
            // Información inferior de la película
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Tags de géneros (priorizando los aprobados en la fase previa)
                  Builder(
                    builder: (context) {
                      final approvedGenreNames = _approvedGenres
                          .map((g) => g.name.toLowerCase().trim())
                          .toSet();

                      final sortedGenres = List<String>.from(movie.genres);
                      sortedGenres.sort((a, b) {
                        final aMatched = approvedGenreNames.any(
                          (w) => a.toLowerCase().contains(w) || w.contains(a.toLowerCase()),
                        );
                        final bMatched = approvedGenreNames.any(
                          (w) => b.toLowerCase().contains(w) || w.contains(b.toLowerCase()),
                        );
                        if (aMatched && !bMatched) return -1;
                        if (!aMatched && bMatched) return 1;
                        return 0;
                      });

                      final displayGenres = sortedGenres.take(4).toList();

                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: displayGenres.map((g) {
                          final isMatched = approvedGenreNames.any(
                            (w) => g.toLowerCase().contains(w) || w.contains(g.toLowerCase()),
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMatched
                                  ? AppColors.accent.withValues(alpha: 0.25)
                                  : AppColors.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isMatched ? AppColors.accent : AppColors.accent.withValues(alpha: 0.3),
                                width: isMatched ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isMatched) ...[
                                  const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  g,
                                  style: AppTextStyles.caption.copyWith(
                                    color: isMatched ? AppColors.accent : AppColors.textPrimary.withValues(alpha: 0.85),
                                    fontWeight: isMatched ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        movie.releaseYear,
                        style: AppTextStyles.metadata.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Text(
                        movie.formattedRuntime,
                        style: AppTextStyles.metadata,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dónde ver
                  if (movie.streamingProviders.isNotEmpty)
                    Row(
                      children: [
                        Text(
                          'En streaming: ',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        ...movie.streamingProviders.take(3).map((p) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  p.fullLogoUrl,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                ),
                              ),
                            )),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botón NOPE (Rojo / Pasar)
          _buildCircleActionButton(
            icon: Icons.close_rounded,
            color: AppColors.error,
            size: 58,
            onPressed: () {
              _cardController.swipeLeft();
            },
          ),
          // Botón Info / Detalle si estamos en películas
          if (_currentStep == SoloSwipeStep.movies && _movieDeckIndex < _movieDeck.length)
            _buildCircleActionButton(
              icon: Icons.info_outline_rounded,
              color: AppColors.info,
              size: 46,
              onPressed: () {
                _openMovieResult(_movieDeck[_movieDeckIndex]);
              },
            ),
          // Botón ME GUSTA (Verde / Like)
          _buildCircleActionButton(
            icon: Icons.favorite_rounded,
            color: AppColors.success,
            size: 58,
            onPressed: () {
              _cardController.swipeRight();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: size * 0.52),
        onPressed: onPressed,
      ),
    );
  }
}
