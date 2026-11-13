import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../data/services/favorites_service.dart';
import '../../movie_detail/screens/movie_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final VoidCallback onGoToSwipe;

  const FavoritesScreen({super.key, required this.onGoToSwipe});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _selectedTab = 0; // 0: Mi Lista, 1: Historial de Matches

  @override
  Widget build(BuildContext context) {
    final favService = context.watch<FavoritesService>();
    final movies = _selectedTab == 0 ? favService.favorites : favService.matchesHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Tu Biblioteca', style: AppTextStyles.h2),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs Superiores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(0, 'Mi Lista (${favService.favorites.length})'),
                    ),
                    Expanded(
                      child: _buildTabButton(1, 'Matches (${favService.matchesHistory.length})'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Contenido: Lista o Empty State
            Expanded(
              child: movies.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: movies.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildMovieListItem(movies[index]);
                      },
                    )
                  : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: AppTextStyles.button.copyWith(
            color: isSelected ? AppColors.background : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMovieListItem(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            CinemaImage(
              imageUrl: movie.fullPosterUrl,
              width: 70,
              height: 100,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(10),
              fallbackTitle: movie.title,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.releaseYear} • ${movie.formattedRuntime}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movie.genres.join(", "),
                    style: AppTextStyles.caption.copyWith(color: AppColors.accentHover),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  RatingBadge(rating: movie.rating, fontSize: 11),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFavTab = _selectedTab == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavTab ? Icons.bookmark_border_rounded : Icons.local_fire_department_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isFavTab ? 'Tu lista está vacía' : 'Sin matches recientes',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              isFavTab
                  ? 'Guarda las películas que quieras ver más tarde desde su ficha técnica.'
                  : 'Empieza a deslizar en solitario o con amigos para encontrar tu primera coincidencia.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CinemaButton(
              text: 'Deslizar Películas',
              icon: Icons.swipe_rounded,
              onPressed: widget.onGoToSwipe,
            ),
          ],
        ),
      ),
    );
  }
}
