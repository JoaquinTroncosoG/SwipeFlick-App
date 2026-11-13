import 'package:flutter/material.dart';

/// Paleta de colores oficial de SwipeFlick basada en la regla 60-30-10
/// Cinema Amber (Informe de Diseño UI/UX)
class AppColors {
  // 60% Fondo principal (Deep Charcoal)
  static const Color background = Color(0xFF121212);
  
  // 30% Superficies (Dark / Elevated)
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceElevated = Color(0xFF2C2C2C);
  static const Color surfaceCard = Color(0xFF1A1A1A);
  static const Color surfaceBorder = Color(0xFF333333);

  // 10% Acento Principal (Warm Amber / Dorado Cine)
  static const Color accent = Color(0xFFE8A849);
  static const Color accentHover = Color(0xFFF0BC6A);
  static const Color accentPressed = Color(0xFFD49335);
  static const Color accentSubtle = Color(0x1FE8A849); // 12% opacidad

  // Textos y Contrastes
  static const Color textPrimary = Color(0xFFE8E6E3); // Off-white cálido
  static const Color textSecondary = Color(0xFF8A8A8A); // Gris neutro medio
  static const Color textMuted = Color(0xFF666666);

  // Semánticos
  static const Color success = Color(0xFF4CAF50); // Aprobación / Like
  static const Color error = Color(0xFFEF5350);   // Rechazo / Nope
  static const Color warning = Color(0xFFFFB74D); // Advertencias / Confirmación de salida
  static const Color info = Color(0xFF42A5F5);    // Datos / Enlaces
  static const Color superLike = Color(0xFF29B6F6);

  // Gradientes Cinematográficos
  static const LinearGradient posterGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x80121212),
      Color(0xE6121212),
      Color(0xFF121212),
    ],
    stops: [0.0, 0.45, 0.8, 1.0],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33121212),
      Color(0x99121212),
      Color(0xFF121212),
    ],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient amberGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF0BC6A),
      Color(0xFFE8A849),
      Color(0xFFD49335),
    ],
  );
}
