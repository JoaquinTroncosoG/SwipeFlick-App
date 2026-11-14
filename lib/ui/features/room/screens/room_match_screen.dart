import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../core/widgets/streaming_provider_pill.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../data/services/favorites_service.dart';
import '../../../../data/services/room_service.dart';
import '../../../../data/services/tmdb_service.dart';
import '../../movie_detail/screens/movie_detail_screen.dart';

class RoomMatchScreen extends StatefulWidget {
  final MovieModel movie;
  final bool isRandomizerResult;

  const RoomMatchScreen({
    super.key,
    required this.movie,
    this.isRandomizerResult = false,
  });

  @override
  State<RoomMatchScreen> createState() => _RoomMatchScreenState();
}

class _RoomMatchScreenState extends State<RoomMatchScreen> {
  late MovieModel _movie;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _fetchFullDetails();
    // Guardar en historial de matches automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesService>().addMatchToHistory(_movie);
    });
  }

  Future<void> _fetchFullDetails() async {
    if (_movie.streamingProviders.isNotEmpty) return;
    try {
      final tmdb = context.read<TmdbService>();
      final full = await tmdb.getMovieDetails(_movie.id);
      if (mounted) {
        setState(() => _movie = full);
        context.read<FavoritesService>().addMatchToHistory(full);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;
    final isRandom = widget.isRandomizerResult;

    return ConfettiOverlay(
      isPlaying: !isRandom,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop difuminado de fondo
            CinemaImage(
              imageUrl: movie.fullBackdropUrl,
              fit: BoxFit.cover,
              fallbackTitle: movie.title,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.posterGradient,
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header de Match
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isRandom
                                ? AppColors.info.withValues(alpha: 0.2)
                                : AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isRandom ? AppColors.info : AppColors.accent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRandom ? Icons.shuffle_rounded : Icons.celebration_rounded,
                                color: isRandom ? AppColors.info : AppColors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isRandom ? 'DECISIÓN DEL RANDOMIZER' : '¡COINCIDENCIA TOTAL!',
                                style: AppTextStyles.button.copyWith(
                                  color: isRandom ? AppColors.info : AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isRandom
                              ? 'Nadie coincidió unánimemente, así que elegimos esta joya para el grupo:'
                              : '¡Todos en la sala estuvieron de acuerdo en ver:',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    // Card de la película ganadora
                    Container(
                      height: 380,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
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
                              top: 16,
                              right: 16,
                              child: RatingBadge(rating: movie.rating),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 24),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${movie.releaseYear} • ${movie.formattedRuntime} • ${movie.genres.join(", ")}',
                                    style: AppTextStyles.metadata,
                                  ),
                                  const SizedBox(height: 10),
                                  if (movie.streamingProviders.isNotEmpty) ...[
                                    Text(
                                      'Mírenla ahora en:',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      children: movie.streamingProviders.take(3).map((p) {
                                        return StreamingProviderPill(provider: p);
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Botones inferiores
                    Column(
                      children: [
                        CinemaButton(
                          text: 'Ver Ficha Completa',
                          icon: Icons.info_outline_rounded,
                          width: double.infinity,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MovieDetailScreen(movie: movie),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Salir y Finalizar Sala'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          onPressed: () {
                            context.read<RoomService>().leaveRoom();
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppConstants.justWatchAttribution,
                          style: AppTextStyles.caption.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
