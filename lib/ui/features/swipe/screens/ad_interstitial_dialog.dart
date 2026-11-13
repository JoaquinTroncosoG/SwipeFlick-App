import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class AdInterstitialDialog extends StatefulWidget {
  final VoidCallback onAdClosed;

  const AdInterstitialDialog({super.key, required this.onAdClosed});

  @override
  State<AdInterstitialDialog> createState() => _AdInterstitialDialogState();
}

class _AdInterstitialDialogState extends State<AdInterstitialDialog> {
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'PUBLICIDAD',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (_secondsRemaining > 0)
                  Text(
                    'Cerrar en $_secondsRemaining s',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                    onPressed: widget.onAdClosed,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=600',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: Icon(Icons.local_movies_rounded, size: 48, color: AppColors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Disfruta del mejor cine con SwipeFlick Pro',
              style: AppTextStyles.h2.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Salas ilimitadas con amigos, sin anuncios y filtros avanzados de streaming.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: _secondsRemaining == 0 ? widget.onAdClosed : null,
              child: Text(
                _secondsRemaining > 0 ? 'Continuar en $_secondsRemaining...' : 'Continuar deslizando',
                style: AppTextStyles.button.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
