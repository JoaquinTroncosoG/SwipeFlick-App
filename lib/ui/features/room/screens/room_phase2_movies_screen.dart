import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../core/widgets/cinema_image.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../core/widgets/swipe_card.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../data/models/room_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/room_service.dart';
import '../../../../data/services/tmdb_service.dart';
import 'room_match_screen.dart';

class RoomPhase2MoviesScreen extends StatefulWidget {
  const RoomPhase2MoviesScreen({super.key});

  @override
  State<RoomPhase2MoviesScreen> createState() => _RoomPhase2MoviesScreenState();
}

class _RoomPhase2MoviesScreenState extends State<RoomPhase2MoviesScreen> {
  final SwipeCardController _cardController = SwipeCardController();
  List<MovieModel> _movies = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatchedMovies();
  }

  Future<void> _loadMatchedMovies() async {
    final roomService = context.read<RoomService>();
    final room = roomService.currentRoom;
    final tmdb = context.read<TmdbService>();

    // 1. Si la sala ya tiene la baraja compartida sincronizada en Atlas, usarla para que todos vean la misma secuencia
    if (room != null && room.movieDeck.isNotEmpty) {
      setState(() {
        _movies = room.movieDeck;
        _isLoading = false;
      });
      return;
    }

    // 2. Si no, generar la baraja y guardarla en la sala para sincronizar a todos los dispositivos
    final matchedGenreIds = room?.matchedCategories.map((c) => c.id).toList() ?? [];
    final list = await tmdb.discoverMoviesByGenres(matchedGenreIds);

    if (room != null && list.isNotEmpty) {
      await roomService.setRoomMovieDeck(list);
    }

    setState(() {
      _movies = list;
      _isLoading = false;
    });
  }

  void _onSwipe(bool approved) {
    if (_currentIndex >= _movies.length) return;

    final currentMovie = _movies[_currentIndex];
    final roomService = context.read<RoomService>();
    final currentUser = context.read<AuthService>().currentUser;

    if (currentUser != null) {
      roomService.castMovieVote(
        userId: currentUser.id,
        movie: currentMovie,
        approved: approved,
        roomDeck: _movies,
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

    if (room != null && _movies.isEmpty && room.movieDeck.isNotEmpty) {
      _movies = room.movieDeck;
      _isLoading = false;
    }

    // Si ya hay resultado (match o randomizer), navegar
    if (room != null && room.phase == RoomPhase.result && room.matchedMovie != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RoomMatchScreen(
              movie: room.matchedMovie!,
              isRandomizerResult: room.isRandomizerResult,
            ),
          ),
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
            Text('Fase 2: Películas en Sala', style: AppTextStyles.h2.copyWith(fontSize: 16)),
            Text(
              'Géneros: ${room.matchedCategories.map((c) => c.name).join(", ")}',
              style: AppTextStyles.caption.copyWith(color: AppColors.accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, color: AppColors.accent),
            tooltip: 'Activar Randomizer',
            onPressed: () {
              roomService.triggerRandomizerFallback(_movies);
            },
          ),
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
                  // Participantes e indicador de voto
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'El primero que coincidan todos = Ganador',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                        ),
                        Row(
                          children: room.members.map((m) {
                            return Container(
                              margin: const EdgeInsets.only(left: 4),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundImage: NetworkImage(m.avatarUrl),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Stack de Tarjetas de Película
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: _buildMovieCardStack(),
                    ),
                  ),

                  // Controles de Acción (Nope / Like)
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

  Widget _buildMovieCardStack() {
    if (_currentIndex >= _movies.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shuffle_on_rounded, size: 54, color: AppColors.accent),
            const SizedBox(height: 16),
            Text('Se agotaron las opciones del deck', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              '¡El Randomizer elegirá la mejor película para todos!',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CinemaButton(
              text: 'Girar Randomizer',
              icon: Icons.casino_rounded,
              onPressed: () {
                context.read<RoomService>().triggerRandomizerFallback(_movies);
              },
            ),
          ],
        ),
      );
    }

    final topMovie = _movies[_currentIndex];
    final nextMovie = _currentIndex + 1 < _movies.length ? _movies[_currentIndex + 1] : null;

    final roomService = context.read<RoomService>();
    final room = roomService.currentRoom;
    final winningGenreNames = (room?.matchedCategories ?? [])
        .map((c) => c.name.toLowerCase().trim())
        .toSet();

    return Stack(
      children: [
        if (nextMovie != null)
          Positioned.fill(
            child: Transform.scale(
              scale: 0.94,
              child: _buildMovieCardContent(nextMovie, winningGenreNames),
            ),
          ),
        Positioned.fill(
          child: SwipeCard(
            controller: _cardController,
            isTopCard: true,
            onSwipeLeft: () => _onSwipe(false),
            onSwipeRight: () => _onSwipe(true),
            child: _buildMovieCardContent(topMovie, winningGenreNames),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCardContent(MovieModel movie, Set<String> winningGenreNames) {
    // Reordenar géneros: priorizar aquellos que coincidan con las categorías ganadoras de la sala
    final sortedGenres = List<String>.from(movie.genres);
    sortedGenres.sort((a, b) {
      final aMatched = winningGenreNames.any(
        (w) => a.toLowerCase().contains(w) || w.contains(a.toLowerCase()),
      );
      final bMatched = winningGenreNames.any(
        (w) => b.toLowerCase().contains(w) || w.contains(b.toLowerCase()),
      );
      if (aMatched && !bMatched) return -1;
      if (!aMatched && bMatched) return 1;
      return 0;
    });

    final displayGenres = sortedGenres.take(4).toList();

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
            Container(decoration: const BoxDecoration(gradient: AppColors.posterGradient)),
            Positioned(
              top: 20,
              right: 20,
              child: RatingBadge(rating: movie.rating),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: displayGenres.map((g) {
                      final isMatched = winningGenreNames.any(
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
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    style: AppTextStyles.heroDisplay.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${movie.releaseYear} • ${movie.formattedRuntime}',
                    style: AppTextStyles.metadata,
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
