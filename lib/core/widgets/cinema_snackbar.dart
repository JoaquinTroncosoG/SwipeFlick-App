import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Helper para avisos y notificaciones SnackBar en SwipeFlick.
/// Configura de forma consistente:
/// - Letras color amarillo/dorado cinéfilo (AppColors.accent).
/// - Duración de 5 segundos completos para garantizar lectura cómoda.
/// - Superficie flotante con esquinas redondeadas y borde dorado.
class CinemaSnackBar {
  static const Duration defaultDuration = Duration(seconds: 5);

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = defaultDuration,
    Color? textColor,
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      create(
        message,
        icon: icon,
        duration: duration,
        textColor: textColor,
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  static SnackBar create(
    String message, {
    IconData? icon,
    Duration duration = defaultDuration,
    Color? textColor,
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    return SnackBar(
      duration: duration,
      backgroundColor: backgroundColor ?? AppColors.surfaceElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.accent, width: 1.2),
      ),
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor ?? AppColors.accent, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor ?? AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      action: action,
    );
  }
}
