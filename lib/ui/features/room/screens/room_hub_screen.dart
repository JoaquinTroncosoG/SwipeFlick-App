import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/models/room_model.dart';
import '../../../../data/services/room_service.dart';
import 'create_room_dialog.dart';
import 'join_room_dialog.dart';
import 'room_category_match_screen.dart';
import 'room_lobby_screen.dart';
import 'room_phase1_categories_screen.dart';
import 'room_phase2_movies_screen.dart';

class RoomHubScreen extends StatelessWidget {
  const RoomHubScreen({super.key});

  void _openActiveRoom(BuildContext context, RoomModel room) {
    Widget destination;
    switch (room.phase) {
      case RoomPhase.lobby:
        destination = const RoomLobbyScreen();
        break;
      case RoomPhase.categories:
        destination = const RoomPhase1CategoriesScreen();
        break;
      case RoomPhase.categoryMatch:
        destination = const RoomCategoryMatchScreen();
        break;
      case RoomPhase.movies:
      case RoomPhase.result:
        destination = const RoomPhase2MoviesScreen();
        break;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomService = context.watch<RoomService>();
    final activeRoom = roomService.currentRoom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Modo Salas Grupales', style: AppTextStyles.h2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Si hay una sala en curso, mostrar banner prioritario
              if (activeRoom != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.meeting_room_rounded, size: 14, color: AppColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  'SALA ACTIVA: ${activeRoom.code}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${activeRoom.members.length} miembros',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tienes una sesión grupal en curso en fase: ${activeRoom.phase.name.toUpperCase()}',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CinemaButton(
                              text: 'Reanudar Sala',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () => _openActiveRoom(context, activeRoom),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              roomService.leaveRoom();
                            },
                            child: const Text('Salir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Banner Hero del Modo Sala
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF241B10), Color(0xFF1E1E1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: AppColors.background, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Resuelve el eterno debate de qué ver',
                      style: AppTextStyles.h1.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea una sala, invita a tus amigos o pareja con un código y todos deslizan hasta que haya una coincidencia unánime.',
                      style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Botones de Acción (Crear / Unirse)
              Text('Opciones de Sala', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 14),

              // Card Crear Sala
              _buildActionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'Crear una Sala',
                description: 'Configura participantes y genera un código único de 6 dígitos para compartir.',
                buttonText: 'Crear Sala',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => CreateRoomDialog(
                      onRoomCreated: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Card Unirse a Sala
              _buildActionCard(
                icon: Icons.login_rounded,
                title: 'Unirse con Código',
                description: '¿Tu amigo ya creó una sala? Ingresa su código para unirte al instante.',
                buttonText: 'Ingresar Código',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => JoinRoomDialog(
                      onJoined: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Cómo funciona el proceso (2 Fases)
              Text('¿Cómo funciona el matching grupal?', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 14),

              _buildStepItem(
                stepNumber: '1',
                title: 'Fase 1: Categorías Compartidas',
                description:
                    'Todos deslizan categorías a su propio ritmo. Al encontrar coincidencias en los géneros configurados, se desbloquea el catálogo.',
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                stepNumber: '2',
                title: 'Fase 2: Primera Película Unánime',
                description:
                    'Se presentan películas de los géneros coincidentes. ¡La primera película aprobada por TODOS es la elegida!',
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                stepNumber: '🎲',
                title: 'Fallback: Randomizer Inteligente',
                description:
                    'Si las opiniones están divididas y nadie coincide al agotar la baraja, el randomizer elige una película de las categorías coincidentes.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 24),
              const SizedBox(width: 12),
              Text(title, style: AppTextStyles.h2.copyWith(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: AppTextStyles.bodySecondary),
          const SizedBox(height: 16),
          CinemaButton(
            text: buttonText,
            onPressed: onTap,
            height: 44,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: AppTextStyles.button.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.bodySecondary.copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
