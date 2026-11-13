import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/models/room_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/room_service.dart';
import 'room_phase1_categories_screen.dart';

class RoomLobbyScreen extends StatelessWidget {
  const RoomLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roomService = context.watch<RoomService>();
    final room = roomService.currentRoom;
    final currentUser = context.watch<AuthService>().currentUser;

    if (room == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Sala')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.meeting_room_outlined, size: 60, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text('No estás en ninguna sala activa', style: AppTextStyles.h2),
              const SizedBox(height: 16),
              CinemaButton(
                text: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    // Si la sala ya avanzó a categorías, navegar
    if (room.phase == RoomPhase.categories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoomPhase1CategoriesScreen()),
        );
      });
    }

    final isHost = currentUser != null && room.hostId == currentUser.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Lobby de Sala', style: AppTextStyles.h2.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
            tooltip: 'Salir de la sala',
            onPressed: () {
              roomService.leaveRoom();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tarjeta de Código de Sala
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Column(
                  children: [
                    Text(
                      'CÓDIGO PARA COMPARTIR',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          room.code,
                          style: AppTextStyles.heroDisplay.copyWith(
                            fontSize: 36,
                            color: AppColors.accent,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.accent, size: 22),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 1),
                                backgroundColor: AppColors.surfaceElevated,
                                content: Text('¡Código copiado al portapapeles!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pide a tus amigos que ingresen este código en SwipeFlick',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reglas configuradas
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Capacidad', style: AppTextStyles.caption),
                          const SizedBox(height: 2),
                          Text(
                            '${room.members.length} / ${room.maxMembers} miembros',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Match de géneros', style: AppTextStyles.caption),
                          const SizedBox(height: 2),
                          Text(
                            '${room.matchThreshold} categorías',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Lista de Participantes Conectados (Supabase Presence)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Participantes conectados', style: AppTextStyles.sectionTitle),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'En vivo',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: ListView.separated(
                  itemCount: room.members.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = room.members[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(member.avatarUrl),
                            backgroundColor: AppColors.surfaceBorder,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      member.username,
                                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (member.isHost) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'HOST',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  member.isReady ? 'Listo para votar' : 'Esperando...',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Estado de conexión en tiempo real
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        room.members.length < 2
                            ? 'Esperando a que tus amigos ingresen el código en sus teléfonos...'
                            : '¡${room.members.length} participantes conectados en tiempo real!',
                        style: AppTextStyles.caption.copyWith(
                          color: room.members.length < 2 ? AppColors.textSecondary : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // CTA Iniciar Juego
              if (isHost) ...[
                CinemaButton(
                  text: 'Comenzar Fase 1: Categorías',
                  icon: Icons.play_arrow_rounded,
                  width: double.infinity,
                  onPressed: room.members.length >= 2
                      ? () async {
                          await roomService.startPhase1Categories();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const RoomPhase1CategoriesScreen()),
                            );
                          }
                        }
                      : null,
                ),
                if (room.members.length < 2) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Se necesitan al menos 2 participantes para iniciar la sala',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Esperando que el anfitrión inicie la sala...',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
