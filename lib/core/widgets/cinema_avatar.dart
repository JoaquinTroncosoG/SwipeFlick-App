import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Componente universal de Avatar cinéfilo para SwipeFlick.
/// Soporta de forma transparente:
/// 1. Data URIs en Base64 ('data:image/...;base64,...')
/// 2. Strings Base64 puros
/// 3. URLs web HTTP / HTTPS
/// 4. Archivos locales en disco (File)
/// 5. Fallback con iniciales o icono cinematográfico si falla la carga.
class CinemaAvatar extends StatelessWidget {
  static const String defaultAvatarUrl =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';

  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Border? border;
  final String? fallbackText;
  final VoidCallback? onTap;

  const CinemaAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
    this.border,
    this.fallbackText,
    this.onTap,
  });

  /// Resuelve un ImageProvider compatible según el formato del string
  static ImageProvider getAvatarImageProvider(String? url) {
    if (url == null || url.trim().isEmpty) {
      return const NetworkImage(defaultAvatarUrl);
    }

    final clean = url.trim();

    // 1. Data URI Base64: "data:image/jpeg;base64,..."
    if (clean.startsWith('data:image/') || clean.startsWith('data:application/')) {
      final commaIndex = clean.indexOf(',');
      final base64Payload = commaIndex != -1 ? clean.substring(commaIndex + 1) : clean;
      try {
        final bytes = base64Decode(base64Payload);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('[CinemaAvatar] Error al decodificar Data URI: $e');
      }
    }

    // 2. Base64 crudo
    if (!clean.startsWith('http://') &&
        !clean.startsWith('https://') &&
        !clean.startsWith('/') &&
        !clean.contains(':\\') &&
        clean.length > 80) {
      try {
        final bytes = base64Decode(clean);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    // 3. URLs HTTP / HTTPS
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return NetworkImage(clean);
    }

    // 4. Archivo local en dispositivo (móvil o escritorio)
    if (!kIsWeb) {
      try {
        final file = File(clean);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {}
    }

    // Fallback por defecto
    return const NetworkImage(defaultAvatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final hasValidString = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final imageProvider = getAvatarImageProvider(avatarUrl);

    Widget avatarWidget = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppColors.surfaceBorder,
        backgroundImage: imageProvider,
        onBackgroundImageError: (_, __) {
          debugPrint('[CinemaAvatar] Error al renderizar avatar: $avatarUrl');
        },
        child: (!hasValidString && fallbackText != null && fallbackText!.trim().isNotEmpty)
            ? Text(
                fallbackText!.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: radius * 0.85,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
