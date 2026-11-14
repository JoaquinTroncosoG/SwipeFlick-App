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
  bool _excludeMatches = false;
  bool _streamingOnly = false;
  bool _isCreating = false;

  static const List<int> _quickPresets = [2, 3, 4, 5, 6, 8, 10, 15, 20];

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
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
              const SizedBox(height: 20),

              // Capacidad máxima de participantes (personalizable)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capacidad de participantes',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Mín. 2 - Máx. 50',
                    style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Stepper interactivo para ajuste personalizado libre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.accent, size: 26),
                      onPressed: _selectedMaxMembers > 2
                          ? () => setState(() => _selectedMaxMembers--)
                          : null,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '$_selectedMaxMembers',
                          style: AppTextStyles.heroDisplay.copyWith(fontSize: 24, color: AppColors.accent),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedMaxMembers == 1 ? 'persona' : 'personas',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent, size: 26),
                      onPressed: _selectedMaxMembers < 50
                          ? () => setState(() => _selectedMaxMembers++)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Chips de acceso rápido
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, index) {
                    final cap = _quickPresets[index];
                    final isSelected = _selectedMaxMembers == cap;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedMaxMembers = cap),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$cap',
                          style: AppTextStyles.caption.copyWith(
                            color: isSelected ? AppColors.background : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Cantidad de categorías para coincidir (1 a 5)
              Text(
                'Categorías necesarias para coincidir',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
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
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 9),
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
              const SizedBox(height: 20),

              // Opción: ¿Considerar películas matches?
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _excludeMatches ? AppColors.accent : AppColors.surfaceBorder,
                    width: _excludeMatches ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _excludeMatches ? AppColors.accentSubtle : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: _excludeMatches ? AppColors.accent : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Considerar películas matches?',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _excludeMatches ? AppColors.accent : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Excluye de la baraja las películas que los participantes ya tengan en su lista o matches anteriores para ver solo cosas nuevas.',
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _excludeMatches,
                      activeColor: AppColors.accent,
                      onChanged: (val) => setState(() => _excludeMatches = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Opción: ¿Solo en Streaming?
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _streamingOnly ? AppColors.accent : AppColors.surfaceBorder,
                    width: _streamingOnly ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _streamingOnly ? AppColors.accentSubtle : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.live_tv_rounded,
                        color: _streamingOnly ? AppColors.accent : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Solo en Streaming?',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _streamingOnly ? AppColors.accent : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Descarta películas que solo están en cines y sugiere únicamente títulos disponibles en plataformas (Netflix, Disney+, Max, etc.).',
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _streamingOnly,
                      activeColor: AppColors.accent,
                      onChanged: (val) => setState(() => _streamingOnly = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                    excludeMatches: _excludeMatches,
                    streamingOnly: _streamingOnly,
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
      ),
    );
  }
}
