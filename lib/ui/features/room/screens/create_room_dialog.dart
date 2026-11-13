import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/room_service.dart';

class CreateRoomDialog extends StatefulWidget {
  final VoidCallback onRoomCreated;

  const CreateRoomDialog({super.key, required this.onRoomCreated});

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  int _selectedMaxMembers = AppConstants.defaultMaxMembers;
  int _selectedMatchThreshold = AppConstants.defaultMatchThreshold;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUser = auth.currentUser;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_add_rounded, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crear Sala Grupal', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                      Text('Elige películas con tus amigos', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Máximo de participantes (2, 5, 10, 20)
            Text('Capacidad máxima de participantes', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: AppConstants.allowedRoomCapacities.map((cap) {
                final isSelected = _selectedMaxMembers == cap;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMaxMembers = cap),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$cap',
                        style: AppTextStyles.button.copyWith(
                          color: isSelected ? AppColors.background : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Cantidad de categorías para coincidir (1 a 5)
            Text(
              'Categorías necesarias para coincidir',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'La Fase 1 avanzará cuando el grupo coincida en esta cantidad de géneros.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 10),
            Row(
              children: AppConstants.allowedMatchThresholds.map((thresh) {
                final isSelected = _selectedMatchThreshold == thresh;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMatchThreshold = thresh),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$thresh',
                        style: AppTextStyles.button.copyWith(
                          color: isSelected ? AppColors.background : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Botón Crear
            CinemaButton(
              text: 'Crear Sala y Abrir Lobby',
              icon: Icons.meeting_room_rounded,
              isLoading: _isCreating,
              width: double.infinity,
              onPressed: () async {
                if (currentUser == null) return;
                setState(() => _isCreating = true);
                final roomService = context.read<RoomService>();
                final nav = Navigator.of(context);
                await roomService.createRoom(
                  host: currentUser,
                  maxMembers: _selectedMaxMembers,
                  matchThreshold: _selectedMatchThreshold,
                );
                if (mounted) {
                  setState(() => _isCreating = false);
                  nav.pop();
                  widget.onRoomCreated();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
