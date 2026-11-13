import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/room_service.dart';

class JoinRoomDialog extends StatefulWidget {
  final VoidCallback onJoined;

  const JoinRoomDialog({super.key, required this.onJoined});

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitJoin() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() {
        _errorMessage = 'Ingresa un código válido de sala (mínimo 4 caracteres)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final roomService = context.read<RoomService>();

    if (auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Debes iniciar sesión para unirte a una sala.';
      });
      return;
    }

    final success = await roomService.joinRoom(
      code: code,
      user: auth.currentUser!,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onJoined();
    } else if (mounted) {
      setState(() {
        _errorMessage = roomService.lastError ??
            'No se pudo encontrar la sala con código "$code". Verifica que el anfitrión haya creado la sala.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(Icons.login_rounded, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unirse a una Sala', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                      Text('Ingresa el código compartido por tu amigo', style: AppTextStyles.caption),
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

            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: AppTextStyles.h1.copyWith(
                letterSpacing: 6,
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'CÓDIGO',
                hintStyle: AppTextStyles.h1.copyWith(
                  letterSpacing: 4,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
                counterText: '',
                prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.accent),
              ),
              onSubmitted: (_) => _submitJoin(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),

            CinemaButton(
              text: 'Entrar a la Sala',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isLoading,
              width: double.infinity,
              onPressed: _submitJoin,
            ),
          ],
        ),
      ),
    );
  }
}
