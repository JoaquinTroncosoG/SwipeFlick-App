import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/cinema_snackbar.dart';
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

  Future<void> _confirmClearAll(BuildContext context) async {
    final favService = context.read<FavoritesService>();
    final isMatchesTab = _selectedTab == 1;
    final title = isMatchesTab ? '¿Borrar todo el historial?' : '¿Vaciar tu lista?';
    final content = isMatchesTab
        ? 'Se eliminarán todos los matches guardados. Podrás empezar de cero en cualquier momento.'
        : 'Se eliminarán todas las películas guardadas en tu lista personal.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTextStyles.h2.copyWith(fontSize: 18))),
          ],
        ),
        content: Text(content, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isMatchesTab ? 'Borrar Historial' : 'Vaciar Lista'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (isMatchesTab) {
        await favService.clearMatchesHistory();
      } else {
        await favService.clearFavorites();
      }
      if (mounted) {
        CinemaSnackBar.show(
          context,
          isMatchesTab ? 'Historial de matches borrado con éxito.' : 'Tu lista ha sido vaciada.',
          icon: Icons.delete_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favService = context.watch<FavoritesService>();
    final movies = _selectedTab == 0 ? favService.favorites : favService.matchesHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Tu Biblioteca', style: AppTextStyles.h2),
        actions: [
          if (movies.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              label: Text(
                _selectedTab == 0 ? 'Borrar Lista' : 'Borrar Historial',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _confirmClearAll(context),
            ),
        ],
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
                        final movie = movies[index];
                        return Dismissible(
                          key: ValueKey('movie_${movie.id}_$_selectedTab'),
                          direction: DismissDirection.endToStart, // Deslizar hacia la izquierda
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 22),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                              ],
                            ),
                          ),
                          onDismissed: (direction) async {
                            final movieTitle = movie.title;
                            if (_selectedTab == 0) {
                              await favService.removeFavorite(movie.id);
                            } else {
                              await favService.removeMatch(movie.id);
                            }
                            if (context.mounted) {
                              CinemaSnackBar.show(
                                context,
                                '"$movieTitle" eliminado de tus ${_selectedTab == 0 ? "favoritos" : "matches"}.',
                                icon: Icons.delete_outline_rounded,
                              );
                            }
                          },
                          child: _buildMovieListItem(movie),
                        );
                      },
                    )
                  : _buildEmptyState(),
            ),

            // Comentario informativo abajo específicamente de la ventana Matches
            if (_selectedTab == 1 && movies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe_left_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Desliza un match a la izquierda para eliminarlo',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
                  if (movie.displayGenres.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      movie.displayGenres.join(", "),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentHover,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
