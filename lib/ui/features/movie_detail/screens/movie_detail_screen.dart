import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../core/widgets/streaming_provider_pill.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../data/models/review_model.dart';
import '../../../../data/services/favorites_service.dart';

class MovieDetailScreen extends StatefulWidget {
  final MovieModel movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isOverviewExpanded = false;
  int _selectedReviewFilter = 0; // 0: Todas, 1: Positivas, 2: Críticas

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final favService = context.watch<FavoritesService>();
    final isFav = favService.isFavorite(movie.id);

    final filteredReviews = movie.reviews.where((r) {
      if (_selectedReviewFilter == 1) return r.isPositive;
      if (_selectedReviewFilter == 2) return !r.isPositive;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar cinematográfico con imagen backdrop y gradiente
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isFav ? AppColors.accent : AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  favService.toggleFavorite(movie);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppColors.surfaceElevated,
                      content: Text(
                        isFav ? 'Eliminado de tu lista' : '¡Guardado en tu lista!',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CinemaImage(
                    imageUrl: movie.fullBackdropUrl,
                    fit: BoxFit.cover,
                    fallbackTitle: movie.title,
                  ),
                  // Gradiente cinemático oscuro
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.posterGradient,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido principal de la ficha
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título cinematográfico (Playfair Display)
                  Text(
                    movie.title,
                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 28),
                  ),
                  if (movie.tagline != null && movie.tagline!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${movie.tagline}"',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.accentHover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Metadatos en fila (Año, Duración, Rating TMDB)
                  Row(
                    children: [
                      RatingBadge(rating: movie.rating),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          movie.releaseYear,
                          style: AppTextStyles.metadata.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              movie.formattedRuntime,
                              style: AppTextStyles.metadata.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Categorías / Géneros Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: movie.genres.map((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accentSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          genre,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Botones CTA principales
                  Row(
                    children: [
                      Expanded(
                        child: CinemaButton(
                          text: isFav ? 'En tu biblioteca' : 'Añadir a mi lista',
                          icon: isFav ? Icons.check_rounded : Icons.bookmark_add_rounded,
                          variant: isFav ? CinemaButtonVariant.secondary : CinemaButtonVariant.primary,
                          onPressed: () {
                            favService.toggleFavorite(movie);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      CinemaButton(
                        text: 'Compartir',
                        icon: Icons.share_rounded,
                        variant: CinemaButtonVariant.secondary,
                        width: 130,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              duration: Duration(seconds: 1),
                              backgroundColor: AppColors.surfaceElevated,
                              content: Text('Enlace copiado para compartir con amigos'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Sección: Sinopsis
                  Text('Sinopsis', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 8),
                  Text(
                    movie.overview,
                    maxLines: _isOverviewExpanded ? null : 4,
                    overflow: _isOverviewExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.85)),
                  ),
                  if (movie.overview.length > 180) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isOverviewExpanded = !_isOverviewExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _isOverviewExpanded ? 'Leer menos' : 'Leer más',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.accent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Sección: Dónde verla (Streaming) con Atribución JustWatch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dónde verla', style: AppTextStyles.sectionTitle),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'JustWatch',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (movie.streamingProviders.isNotEmpty) ...[
                    Wrap(
                      children: movie.streamingProviders.map((p) {
                        return StreamingProviderPill(provider: p);
                      }).toList(),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Consulta en tu plataforma local o cines para funciones disponibles.',
                              style: AppTextStyles.bodySecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    AppConstants.justWatchAttribution,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sección: Reseñas de la comunidad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reseñas de la comunidad', style: AppTextStyles.sectionTitle),
                      Text(
                        '${movie.reviews.length} opiniones',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filtros de reseñas (Todas, Positivas, Críticas)
                  Row(
                    children: [
                      _buildReviewFilterChip(0, 'Todas'),
                      const SizedBox(width: 8),
                      _buildReviewFilterChip(1, '👍 Positivas'),
                      const SizedBox(width: 8),
                      _buildReviewFilterChip(2, '👎 Críticas'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (filteredReviews.isNotEmpty) ...[
                    ...filteredReviews.map((review) => _buildReviewCard(review)),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No hay reseñas en este filtro.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewFilterChip(int index, String label) {
    final isSelected = _selectedReviewFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReviewFilter = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? AppColors.background : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: review.isPositive
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.error.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(review.avatarUrl),
                backgroundColor: AppColors.surfaceBorder,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      review.isPositive ? 'Reseña positiva recomendada' : 'Crítica constructiva',
                      style: AppTextStyles.caption.copyWith(
                        color: review.isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              RatingBadge(rating: review.rating, fontSize: 12),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.content,
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.thumb_up_alt_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${review.likesCount} cinéfilos encontraron útil esto',
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
