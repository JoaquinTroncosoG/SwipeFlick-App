import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/search_dictionary_helper.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../data/mock/mock_movies_data.dart';
import '../../../../data/models/genre_model.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../data/services/favorites_service.dart';
import '../../../../data/services/tmdb_service.dart';
import '../../movie_detail/screens/movie_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartSoloSwipe;
  final VoidCallback onOpenRoomsTab;

  const HomeScreen({
    super.key,
    required this.onStartSoloSwipe,
    required this.onOpenRoomsTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MovieModel> _trendingMovies = [];
  bool _isLoading = true;
  MovieModel? _heroMovie;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    final tmdb = context.read<TmdbService>();
    final movies = await tmdb.getTrendingMovies();
    setState(() {
      _trendingMovies = movies;
      if (movies.isNotEmpty) {
        _heroMovie = movies.first;
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final favService = context.watch<FavoritesService>();
    final matchesHistory = favService.matchesHistory;

    // Búsqueda inteligente: detección de género por sinónimos + normalización diacrítica
    final detectedGenre = _searchQuery.isEmpty ? null : SearchDictionaryHelper.detectGenre(_searchQuery);
    final combinedCatalog = [
      ..._trendingMovies,
      ...MockMoviesData.sampleMovies.where((m) => !_trendingMovies.any((tm) => tm.id == m.id)),
    ];
    final displayedMovies = _searchQuery.isEmpty
        ? _trendingMovies
        : SearchDictionaryHelper.searchMovies(
            catalog: combinedCatalog,
            query: _searchQuery,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : CustomScrollView(
              slivers: [
                // AppBar con logo, título y badge de versión / contador de cambio
                SliverAppBar(
                  floating: true,
                  backgroundColor: AppColors.background.withValues(alpha: 0.9),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.movie_filter_rounded, size: 20, color: AppColors.background),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SwipeFlick',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          AppConstants.appVersionDisplay,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Barra de Búsqueda inteligente con diccionario
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyMedium,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar películas, géneros (ej: "accion", "miedo")...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accent),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Carrusel horizontal de pastillas de género rápido cuando no hay búsqueda
                if (_searchQuery.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: GenreModel.defaultGenres.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final g = GenreModel.defaultGenres[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                _searchController.text = g.name.toLowerCase();
                                setState(() {
                                  _searchQuery = g.name.toLowerCase();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(g.emoji, style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Text(
                                      g.name,
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Feedback visual de categoría detectada por el diccionario de sinónimos
                if (_searchQuery.isNotEmpty && detectedGenre != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Diccionario inteligente: "$_searchQuery" → ${detectedGenre.emoji} ${detectedGenre.name}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Si no hay búsqueda activa, mostrar el Hero Banner y Modos
                if (_searchQuery.isEmpty) ...[
                  // Hero Banner Cinematográfico
                  if (_heroMovie != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildHeroBanner(_heroMovie!),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Accesos Directos a Modos de Juego
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('¿Cómo quieres elegir hoy?', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModeQuickCard(
                                  title: 'Modo Solo',
                                  subtitle: 'Desliza a tu ritmo',
                                  emoji: '🍿',
                                  gradientColors: const [Color(0xFF2C1E12), Color(0xFF1E1E1E)],
                                  borderColor: AppColors.accent.withValues(alpha: 0.5),
                                  onTap: widget.onStartSoloSwipe,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModeQuickCard(
                                  title: 'En Grupo',
                                  subtitle: 'Crea o entra a sala',
                                  emoji: '👥',
                                  gradientColors: const [Color(0xFF162529), Color(0xFF1E1E1E)],
                                  borderColor: AppColors.info.withValues(alpha: 0.5),
                                  onTap: widget.onOpenRoomsTab,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // Fila 1: Historial de Matches / Seguir Viendo (Retención UI)
                  if (matchesHistory.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tus Películas Coincidentes', style: AppTextStyles.sectionTitle),
                                Text('${matchesHistory.length}', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              scrollDirection: Axis.horizontal,
                              itemCount: matchesHistory.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                return _buildMoviePosterCard(matchesHistory[index]);
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ],
                ],

                // Fila Tendencias / Resultados de Búsqueda
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Tendencias de la Semana'
                                    : (detectedGenre != null
                                        ? '${detectedGenre.emoji} Categoría: ${detectedGenre.name}'
                                        : 'Resultados de Búsqueda'),
                                style: AppTextStyles.sectionTitle,
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${displayedMovies.length} películas encontradas para "$_searchQuery"',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.textSecondary),
                            label: const Text('Limpiar', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Grid o Carrusel de Películas
                if (displayedMovies.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildGridMovieCard(displayedMovies[index]);
                        },
                        childCount: displayedMovies.length,
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text('No se encontraron películas para "$_searchQuery"', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildHeroBanner(MovieModel movie) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CinemaImage(
              imageUrl: movie.fullBackdropUrl,
              fit: BoxFit.cover,
              fallbackTitle: movie.title,
            ),
            Container(decoration: const BoxDecoration(gradient: AppColors.heroGradient)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingBadge(rating: movie.rating),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 24),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.releaseYear} • ${movie.genres.take(2).join(", ")}',
                    style: AppTextStyles.metadata.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CinemaButton(
                        text: 'Ver Ficha',
                        icon: Icons.info_outline_rounded,
                        height: 40,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      CinemaButton(
                        text: 'Deslizar',
                        icon: Icons.swipe_rounded,
                        variant: CinemaButtonVariant.secondary,
                        height: 40,
                        onPressed: widget.onStartSoloSwipe,
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

  Widget _buildModeQuickCard({
    required String title,
    required String subtitle,
    required String emoji,
    required List<Color> gradientColors,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviePosterCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
        );
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinemaImage(
                imageUrl: movie.fullPosterUrl,
                fit: BoxFit.cover,
                fallbackTitle: movie.title,
              ),
              Container(decoration: const BoxDecoration(gradient: AppColors.posterGradient)),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(movie.releaseYear, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridMovieCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
          color: AppColors.surfaceElevated,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinemaImage(
                imageUrl: movie.fullPosterUrl,
                fit: BoxFit.cover,
                fallbackTitle: movie.title,
              ),
              Container(decoration: const BoxDecoration(gradient: AppColors.posterGradient)),
              Positioned(
                top: 10,
                right: 10,
                child: RatingBadge(rating: movie.rating, fontSize: 11),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${movie.releaseYear} • ${movie.genres.take(1).join()}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
