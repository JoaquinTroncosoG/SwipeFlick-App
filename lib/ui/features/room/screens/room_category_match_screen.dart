import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../data/models/genre_model.dart';
import '../../../../data/models/room_model.dart';
import '../../../../data/services/room_service.dart';
import 'room_phase2_movies_screen.dart';

class RoomCategoryMatchScreen extends StatelessWidget {
  const RoomCategoryMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roomService = context.watch<RoomService>();
    final room = roomService.currentRoom;

    if (room == null || room.matchedCategories.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CinemaButton(
            text: 'Volver',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    // Si ya avanzó a películas por otro usuario, navegar
    if (room.phase == RoomPhase.movies) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoomPhase2MoviesScreen()),
        );
      });
    }

    final categories = room.matchedCategories;

    return ConfettiOverlay(
      isPlaying: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header Celebratorio
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.accent, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration_rounded, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '¡GÉNEROS COINCIDENTES!',
                            style: AppTextStyles.button.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¡Todos en la sala coincidieron en ver:',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${categories.length} ${categories.length == 1 ? "categoría ganadora" : "categorías ganadoras"}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),

                // Centro de la pantalla: Tarjetas de las Categorías Ganadoras
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: categories.length == 1
                          ? _buildSingleWinnerCard(categories.first)
                          : _buildMultipleWinnersCarousel(categories),
                    ),
                  ),
                ),

                // Botón inferior para comenzar la Fase 2: Películas
                Column(
                  children: [
                    Text(
                      'Ahora el grupo votará películas dentro de estas categorías',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    CinemaButton(
                      text: 'Comenzar a Escoger Película',
                      icon: Icons.movie_filter_rounded,
                      width: double.infinity,
                      onPressed: () {
                        roomService.advanceToMoviesPhase();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const RoomPhase2MoviesScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                      label: const Text('Salir de la Sala'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      onPressed: () {
                        roomService.leaveRoom();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleWinnerCard(GenreModel genre) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (genre.samplePosterUrl != null)
              CinemaImage(
                imageUrl: genre.samplePosterUrl!,
                fit: BoxFit.cover,
                fallbackTitle: genre.name,
              )
            else
              Container(color: AppColors.surfaceCard),

            Container(decoration: const BoxDecoration(gradient: AppColors.posterGradient)),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(genre.emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    genre.name,
                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    genre.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Text(
                      '✓ 100% Coincidencia Grupal',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildMultipleWinnersCarousel(List<GenreModel> categories) {
    return SizedBox(
      height: 380,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final genre = categories[index];
          return Container(
            width: 260,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.accent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (genre.samplePosterUrl != null)
                    CinemaImage(
                      imageUrl: genre.samplePosterUrl!,
                      fit: BoxFit.cover,
                      fallbackTitle: genre.name,
                    )
                  else
                    Container(color: AppColors.surfaceCard),

                  Container(decoration: const BoxDecoration(gradient: AppColors.posterGradient)),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(genre.emoji, style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          genre.name,
                          style: AppTextStyles.heroDisplay.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          genre.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Text(
                            '✓ Coincidencia Grupal',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
