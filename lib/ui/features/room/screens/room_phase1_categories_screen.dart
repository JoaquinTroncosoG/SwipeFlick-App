import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/swipe_card.dart';
import '../../../../data/models/genre_model.dart';
import '../../../../data/models/room_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/room_service.dart';
import '../../../../data/services/tmdb_service.dart';
import 'room_category_match_screen.dart';
import 'room_phase2_movies_screen.dart';

class RoomPhase1CategoriesScreen extends StatefulWidget {
  const RoomPhase1CategoriesScreen({super.key});

  @override
  State<RoomPhase1CategoriesScreen> createState() => _RoomPhase1CategoriesScreenState();
}

class _RoomPhase1CategoriesScreenState extends State<RoomPhase1CategoriesScreen> {
  final SwipeCardController _cardController = SwipeCardController();
  List<GenreModel> _genres = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final tmdb = context.read<TmdbService>();
    final list = await tmdb.getGenres();
    setState(() {
      _genres = list;
      _isLoading = false;
    });
  }

  void _onSwipe(bool approved) {
    if (_currentIndex >= _genres.length) return;

    final currentGenre = _genres[_currentIndex];
    final roomService = context.read<RoomService>();
    final currentUser = context.read<AuthService>().currentUser;

    if (currentUser != null) {
      roomService.castCategoryVote(
        userId: currentUser.id,
        genreId: currentGenre.id,
        approved: approved,
        allAvailableGenres: _genres,
      );
    }

    setState(() {
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomService = context.watch<RoomService>();
    final room = roomService.currentRoom;

    // Si ya avanzó a la celebración de categorías ganadoras, navegar
    if (room != null && room.phase == RoomPhase.categoryMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoomCategoryMatchScreen()),
        );
      });
    } else if (room != null && room.phase == RoomPhase.movies) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoomPhase2MoviesScreen()),
        );
      });
    }

    if (room == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CinemaButton(
            text: 'Volver al Inicio',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text('Fase 1: Categorías en Sala', style: AppTextStyles.h2.copyWith(fontSize: 16)),
            Text('Sala: ${room.code}', style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
            onPressed: () {
              roomService.leaveRoom();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SafeArea(
              child: Column(
                children: [
                  // Banner de Coincidencias en tiempo real
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub_rounded, color: AppColors.accent, size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Coincidencias del grupo', style: AppTextStyles.caption),
                                Text(
                                  '${room.matchedCategories.length} de ${room.matchThreshold} necesarias',
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Participantes en vivo
                        Row(
                          children: room.members.map((m) {
                            final hasVotedCurrent = _currentIndex < _genres.length
                                ? m.categoryVotes.containsKey(_genres[_currentIndex].id)
                                : true;
                            return Container(
                              margin: const EdgeInsets.only(left: 4),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: NetworkImage(m.avatarUrl),
                                  ),
                                  if (hasVotedCurrent)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Stack de Tarjetas
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: _buildCardStack(room),
                    ),
                  ),

                  // Controles de Acción
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCircleBtn(
                          icon: Icons.close_rounded,
                          color: AppColors.error,
                          onPressed: () => _cardController.swipeLeft(),
                        ),
                        _buildCircleBtn(
                          icon: Icons.favorite_rounded,
                          color: AppColors.success,
                          onPressed: () => _cardController.swipeRight(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }

  Widget _buildCardStack(RoomModel room) {
    if (_currentIndex >= _genres.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 54, color: AppColors.accent),
            const SizedBox(height: 16),
            Text('¡Has revisado todas las categorías!', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Coincidencias encontradas: ${room.matchedCategories.length}',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 20),
            CinemaButton(
              text: 'Avanzar a Películas',
              icon: Icons.movie_rounded,
              onPressed: () {
                context.read<RoomService>().forceAdvanceToMoviesPhase(_genres);
              },
            ),
          ],
        ),
      );
    }

    final topGenre = _genres[_currentIndex];
    final nextGenre = _currentIndex + 1 < _genres.length ? _genres[_currentIndex + 1] : null;

    return Stack(
      children: [
        if (nextGenre != null)
          Positioned.fill(
            child: Transform.scale(
              scale: 0.94,
              child: _buildGenreContent(nextGenre),
            ),
          ),
        Positioned.fill(
          child: SwipeCard(
            controller: _cardController,
            isTopCard: true,
            onSwipeLeft: () => _onSwipe(false),
            onSwipeRight: () => _onSwipe(true),
            child: _buildGenreContent(topGenre),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreContent(GenreModel genre) {
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
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(genre.emoji, style: const TextStyle(fontSize: 48)),
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

  Widget _buildCircleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 58,
      height: 58,
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
        icon: Icon(icon, color: color, size: 30),
        onPressed: onPressed,
      ),
    );
  }
}
