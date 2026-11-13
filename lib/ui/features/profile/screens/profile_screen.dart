import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cinema_avatar.dart';
import '../../../../core/widgets/cinema_button.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/brevo_email_service.dart';
import '../../../../data/services/favorites_service.dart';
import '../../../../data/services/mongodb_service.dart';
import '../../../../data/services/tmdb_service.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAdvancedExpanded = false;

  static const List<Map<String, String>> _presetAvatars = [
    {
      'name': 'Alex',
      'url': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    },
    {
      'name': 'Sofía',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    },
    {
      'name': 'Mateo',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    },
    {
      'name': 'Valeria',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    },
    {
      'name': 'Lucas',
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
    },
    {
      'name': 'Camila',
      'url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
    },
    {
      'name': 'Diego',
      'url': 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
    },
    {
      'name': 'Florencia',
      'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
    },
  ];

  ImageProvider _getAvatarImageProvider(String? url) {
    return CinemaAvatar.getAvatarImageProvider(url);
  }

  void _showAvatarPicker(BuildContext context) {
    final auth = context.read<AuthService>();
    final currentAvatar = auth.currentUser?.avatarUrl ?? '';
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.face_retouching_natural_rounded, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text('Foto de Perfil', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // BOTÓN DE ACCESO A GALERÍA LOCAL DEL DISPOSITIVO (REQUERIMIENTO 4)
                  CinemaButton(
                    text: 'Elegir desde tu Galería de Fotos',
                    icon: Icons.photo_library_rounded,
                    width: double.infinity,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        final picker = ImagePicker();
                        final pickedImage = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 320,
                          maxHeight: 320,
                          imageQuality: 70,
                        );
                        if (pickedImage != null) {
                          final bytes = await pickedImage.readAsBytes();
                          final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                          await auth.updateAvatarUrl(base64Image);
                          if (context.mounted) {
                            final mongoService = context.read<MongoDbService>();
                            if (auth.currentUser != null && (mongoService.isConnected || await mongoService.ensureConnected())) {
                              await mongoService.updateUserProfile(
                                email: auth.currentUser!.email,
                                avatarUrl: base64Image,
                              );
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.surfaceElevated,
                                content: Text('¡Foto de perfil actualizada y visible en tus salas! 📸'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text('No se pudo acceder a la galería: $e'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'O selecciona uno de nuestros avatares cinéfilos:',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presetAvatars.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _presetAvatars[index];
                        final isSelected = item['url'] == currentAvatar;
                        return GestureDetector(
                          onTap: () async {
                            final selectedUrl = item['url']!;
                            await auth.updateAvatarUrl(selectedUrl);
                            if (context.mounted) {
                              final mongoService = context.read<MongoDbService>();
                              if (auth.currentUser != null && (mongoService.isConnected || await mongoService.ensureConnected())) {
                                await mongoService.updateUserProfile(
                                  email: auth.currentUser!.email,
                                  avatarUrl: selectedUrl,
                                );
                              }
                            }
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.surfaceElevated,
                                content: Text('Foto de perfil actualizada a ${item['name']}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColors.accent : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage: NetworkImage(item['url']!),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['name']!,
                                style: AppTextStyles.caption.copyWith(
                                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: urlController,
                          style: AppTextStyles.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'O pega la URL de tu imagen...',
                            prefixIcon: Icon(Icons.link_rounded, color: AppColors.accent, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: () async {
                          final val = urlController.text.trim();
                          if (val.isNotEmpty && (val.startsWith('http') || val.startsWith('data:image/'))) {
                            await auth.updateAvatarUrl(val);
                            if (context.mounted) {
                              final mongoService = context.read<MongoDbService>();
                              if (auth.currentUser != null && (mongoService.isConnected || await mongoService.ensureConnected())) {
                                await mongoService.updateUserProfile(
                                  email: auth.currentUser!.email,
                                  avatarUrl: val,
                                );
                              }
                            }
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.surfaceElevated,
                                content: Text('Foto de perfil actualizada y sincronizada'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final auth = context.read<AuthService>();
    final controller = TextEditingController(text: auth.currentUser?.username ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Cambiar Nombre', style: AppTextStyles.h2.copyWith(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este nombre se mostrará en las salas grupales y en tus listas:',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'Tu nombre de cinéfilo',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                auth.updateUsername(newName);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surfaceElevated,
                    content: Text('Nombre actualizado a "$newName"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context) {
    final auth = context.read<AuthService>();
    final controller = TextEditingController(text: auth.currentUser?.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.email_outlined, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Cambiar Correo', style: AppTextStyles.h2.copyWith(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa tu nuevo correo para inicio de sesión y notificaciones:',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'ejemplo@correo.com',
                prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final newEmail = controller.text.trim();
              if (newEmail.contains('@') && newEmail.contains('.')) {
                auth.updateEmail(newEmail);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surfaceElevated,
                    content: Text('Correo actualizado a "$newEmail"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('Por favor ingresa un correo electrónico válido'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  /// DIÁLOGO DE CAMBIO DE CONTRASEÑA CON VALIDACIÓN ESTRICTA Y OBLIGATORIA (REQUERIMIENTO 1)
  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Cambiar Contraseña', style: AppTextStyles.h2.copyWith(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Para mayor seguridad, debes ingresar tu contraseña actual y confirmar la nueva dos veces:',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 16),

                  // 1. Contraseña actual (OBLIGATORIA)
                  Text('Contraseña Actual *', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: currentPassController,
                    obscureText: obscureCurrent,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Ingresa tu contraseña actual',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureCurrent = !obscureCurrent;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Nueva contraseña
                  Text('Nueva Contraseña * (mínimo 6 caracteres)', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.key_rounded, color: AppColors.accent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureNew = !obscureNew;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Confirmar nueva contraseña (debe coincidir exactamente)
                  Text('Confirmar Nueva Contraseña *', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPassController,
                    obscureText: obscureConfirm,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Escribe de nuevo tu nueva contraseña',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () async {
                  final currentPass = currentPassController.text;
                  final newPass = newPassController.text;
                  final confirmPass = confirmPassController.text;

                  // Validación 1: Contraseña actual obligatoria
                  if (currentPass.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('La contraseña actual es obligatoria.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Validación 2: Verificación de contraseña actual
                  final auth = context.read<AuthService>();
                  if (!auth.verifyCurrentPassword(currentPass)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('La contraseña actual ingresada es incorrecta.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Validación 3: Longitud mínima
                  if (newPass.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('La nueva contraseña debe tener al menos 6 caracteres.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Validación 4: No puede ser igual a la anterior
                  if (newPass == currentPass) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('La nueva contraseña no puede ser idéntica a la actual.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Validación 5: Confirmación obligatoria y coincidencia exacta
                  if (confirmPass.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Debes confirmar la nueva contraseña escribiéndola una segunda vez.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  if (newPass != confirmPass) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Las contraseñas no coinciden. Escríbelas igual para confirmar.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  final brevo = context.read<BrevoEmailService>();
                  final success = await auth.updatePassword(
                    currentPassword: currentPass,
                    newPassword: newPass,
                  );

                  if (success) {
                    final user = auth.currentUser;
                    if (user != null) {
                      brevo.sendPasswordChangedEmail(
                        recipientEmail: user.email,
                        recipientName: user.username,
                      );
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text('¡Contraseña actualizada exitosamente! 🔒'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Guardar Clave'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    final tmdb = context.read<TmdbService>();
    final controller = TextEditingController(text: tmdb.apiKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.key_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('API Key de TMDB', style: AppTextStyles.h2.copyWith(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SwipeFlick funciona con un catálogo offline enriquecido por defecto. Si deseas conectar datos en vivo de TMDB en tiempo real, ingresa tu API Key gratuita:',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'Ingresa tu TMDB API Key (v3 auth)',
                prefixIcon: Icon(Icons.vpn_key_rounded, color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await tmdb.setApiKey('');
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Restablecer a Mock'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              await tmdb.setApiKey(controller.text);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para configurar credenciales de Brevo (REQUERIMIENTO 3)
  void _showBrevoConfigDialog(BuildContext context) {
    final brevo = context.read<BrevoEmailService>();
    final keyController = TextEditingController(text: brevo.apiKey ?? '');
    final senderEmailController = TextEditingController(text: brevo.senderEmail);
    final senderNameController = TextEditingController(text: brevo.senderName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Credenciales Brevo (Email)', style: AppTextStyles.h2.copyWith(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa tu API Key de Brevo (Sendinblue) para activar el envío de correos de bienvenida y seguridad:',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyController,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Brevo API Key (Clave v3)',
                  prefixIcon: Icon(Icons.vpn_key_rounded, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: senderEmailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Correo Remitente Verificado',
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: senderNameController,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Remitente (ej: SwipeFlick)',
                  prefixIcon: Icon(Icons.badge_rounded, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              await brevo.setCredentials(
                apiKey: keyController.text,
                senderEmail: senderEmailController.text,
                senderName: senderNameController.text,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.surfaceElevated,
                    content: Text('Credenciales de Brevo guardadas con éxito.'),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para configurar conexión de MongoDB (REQUERIMIENTO 2)
  void _showMongoDbDialog(BuildContext context) {
    final mongoService = context.read<MongoDbService>();
    final uriController = TextEditingController(text: mongoService.uri ?? '');
    final dbNameController = TextEditingController(text: mongoService.dbName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.storage_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Conexión MongoDB Atlas', style: AppTextStyles.h2.copyWith(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa tu cadena de conexión MongoDB Atlas para sincronizar cuentas y salas en la nube:',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: uriController,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'MongoDB URI (mongodb+srv://...)',
                  hintText: 'mongodb+srv://user:pass@cluster.mongodb.net/...',
                  prefixIcon: Icon(Icons.link_rounded, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dbNameController,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Base de Datos',
                  hintText: 'swipeflick',
                  prefixIcon: Icon(Icons.folder_outlined, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recuerda permitir acceso a todas las IPs (0.0.0.0/0) en Network Access de MongoDB Atlas.',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              final uri = uriController.text.trim();
              final dbName = dbNameController.text.trim();

              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.surfaceElevated,
                    content: Text('Conectando a MongoDB Atlas... ⏳'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }

              final ok = await mongoService.saveCredentials(uri: uri, dbName: dbName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ok ? AppColors.surfaceElevated : AppColors.error,
                    content: Text(
                      ok
                          ? '¡Conexión establecida con éxito a MongoDB Atlas! 🍃'
                          : 'No se pudo conectar a MongoDB: ${mongoService.lastError ?? "Verifica credenciales y acceso de red 0.0.0.0/0"}',
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text('Guardar y Conectar'),
          ),
        ],
      ),
    );
  }

  void _showChangelogBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final reversedLog = AppConstants.changeLog.reversed.toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.commit_rounded, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text('Historial de Cambios', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reversedLog.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.surfaceBorder, height: 20),
                    itemBuilder: (context, index) {
                      final item = reversedLog[index];
                      final isCurrent = index == 0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: isCurrent ? AppColors.accent : AppColors.surfaceBorder),
                            ),
                            child: Icon(
                              isCurrent ? Icons.check_circle_rounded : Icons.history_rounded,
                              size: 14,
                              color: isCurrent ? AppColors.accent : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item['version'] ?? '',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isCurrent ? AppColors.accent : AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item['title'] ?? '',
                                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['description'] ?? '',
                                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tmdb = context.watch<TmdbService>();
    final brevo = context.watch<BrevoEmailService>();
    final mongo = context.watch<MongoDbService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Perfil y Ajustes', style: AppTextStyles.h2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. TARJETA PRINCIPAL DEL USUARIO
              // ==========================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundImage: _getAvatarImageProvider(user?.avatarUrl),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showAvatarPicker(context),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.username ?? 'Cinéfilo Invitado',
                                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _showEditNameDialog(context),
                                child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.accent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? 'invitado@swipeflick.app',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showAvatarPicker(context),
                            child: Text(
                              'Cambiar foto de perfil',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ==========================================
              // 2. SECCIÓN: PERSONALIZAR PERFIL
              // ==========================================
              Text('Personalizar Perfil', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Nombre de Usuario',
                subtitle: user?.username ?? 'Cinéfilo',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                onTap: () => _showEditNameDialog(context),
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.face_rounded,
                title: 'Foto de Perfil',
                subtitle: 'Galería del dispositivo o avatar cinematográfico',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                onTap: () => _showAvatarPicker(context),
              ),
              const SizedBox(height: 26),

              // ==========================================
              // 3. SECCIÓN: SEGURIDAD Y CUENTA
              // ==========================================
              Text('Seguridad y Cuenta', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.alternate_email_rounded,
                title: 'Correo Electrónico',
                subtitle: user?.email ?? 'invitado@swipeflick.app',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                onTap: () => _showChangeEmailDialog(context),
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Contraseña de la Cuenta',
                subtitle: '•••••••• (Cambiar clave de acceso con validación)',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                onTap: () => _showChangePasswordDialog(context),
              ),
              const SizedBox(height: 26),

              // ==========================================
              // 4. CONFIGURACIÓN AVANZADA (PLEGABLE / TÉCNICO)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAdvancedExpanded ? AppColors.accent.withValues(alpha: 0.5) : AppColors.surfaceBorder,
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _isAdvancedExpanded = !_isAdvancedExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accentSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.tune_rounded, color: AppColors.accent, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Configuración Avanzada',
                                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'TÉCNICO',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 9,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isAdvancedExpanded
                                        ? 'Opciones técnicas de desarrollador y backend'
                                        : 'MongoDB, Brevo Email, TMDB API y Supabase',
                                    style: AppTextStyles.caption.copyWith(height: 1.2),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _isAdvancedExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_isAdvancedExpanded) ...[
                      const Divider(color: AppColors.surfaceBorder, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Parámetros técnicos de infraestructura. La app funciona al 100% con el catálogo offline y modo simulado.',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 1. TMDB API
                            _buildSettingsTile(
                              icon: Icons.movie_filter_rounded,
                              title: 'Conexión TMDB API',
                              subtitle: tmdb.hasApiKey ? 'En vivo (API Key activa)' : 'Catálogo Offline + Cache 24h',
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                              onTap: () => _showApiKeyDialog(context),
                            ),
                            const SizedBox(height: 8),

                            // 2. Brevo Email
                            _buildSettingsTile(
                              icon: Icons.mark_email_read_rounded,
                              title: 'Servicio de Correo (Brevo)',
                              subtitle: brevo.isConfigured
                                  ? 'Activo (${brevo.senderEmail})'
                                  : 'Modo Simulado (Configurar API Key)',
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                              onTap: () => _showBrevoConfigDialog(context),
                            ),
                            const SizedBox(height: 8),

                            // 3. MongoDB
                            _buildSettingsTile(
                              icon: Icons.storage_rounded,
                              title: 'Base de Datos (MongoDB Atlas)',
                              subtitle: mongo.isConnected
                                  ? 'Conectado a "${mongo.dbName}"'
                                  : (mongo.status == MongoDbStatus.connecting
                                      ? 'Conectando a base de datos...'
                                      : (mongo.status == MongoDbStatus.error
                                          ? 'Error de conexión (Toca para revisar)'
                                          : 'Configuración de URI y base de datos')),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: mongo.isConnected
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : (mongo.status == MongoDbStatus.connecting
                                          ? AppColors.accent.withValues(alpha: 0.15)
                                          : (mongo.status == MongoDbStatus.error
                                              ? AppColors.error.withValues(alpha: 0.15)
                                              : AppColors.surface)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  mongo.isConnected
                                      ? 'CONECTADO'
                                      : (mongo.status == MongoDbStatus.connecting
                                          ? 'CONECTANDO'
                                          : (mongo.status == MongoDbStatus.error ? 'ERROR' : 'CONFIGURAR')),
                                  style: AppTextStyles.caption.copyWith(
                                    color: mongo.isConnected
                                        ? AppColors.success
                                        : (mongo.status == MongoDbStatus.connecting
                                            ? AppColors.accent
                                            : (mongo.status == MongoDbStatus.error
                                                ? AppColors.error
                                                : AppColors.textSecondary)),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              onTap: () => _showMongoDbDialog(context),
                            ),
                            const SizedBox(height: 8),

                            // 4. Supabase Realtime
                            _buildSettingsTile(
                              icon: Icons.cloud_done_rounded,
                              title: 'Salas en Tiempo Real (Supabase)',
                              subtitle: 'PostgreSQL + Realtime Presence activo',
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CONECTADO',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 5. JustWatch Atribución
                            _buildSettingsTile(
                              icon: Icons.verified_user_outlined,
                              title: 'Atribución JustWatch & TMDB',
                              subtitle: AppConstants.justWatchAttribution,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ==========================================
              // 5. ACERCA DE SWIPNFLICK & VERSIÓN
              // ==========================================
              Text('Acerca de SwipeFlick', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.history_rounded,
                title: 'Historial de Cambios y Versión',
                subtitle: '${AppConstants.appName} ${AppConstants.appVersionDisplay}',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.accent),
                onTap: () => _showChangelogBottomSheet(context),
              ),
              const SizedBox(height: 28),

              // Botones de Sesión
              CinemaButton(
                text: 'Iniciar Sesión / Cambiar Cuenta',
                icon: Icons.login_rounded,
                variant: CinemaButtonVariant.secondary,
                width: double.infinity,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Cerrar Sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () async {
                  if (context.mounted) {
                    context.read<FavoritesService>().clearOnSignOut();
                  }
                  await auth.signOut();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        backgroundColor: AppColors.surfaceElevated,
                        content: Text('Sesión cerrada con éxito. ¡Hasta pronto! 👋'),
                      ),
                    );
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(height: 1.3)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}
