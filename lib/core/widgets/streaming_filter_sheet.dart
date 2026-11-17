import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_text_styles.dart';
import 'cinema_button.dart';

/// Modal interactivo para selección y filtrado por servicios de streaming específicos
/// (Netflix, Disney+, Max, Prime Video, Apple TV+, Paramount+, etc.)
class StreamingFilterSheet extends StatefulWidget {
  final List<int> initialSelected;
  final String countryCode;
  final ValueChanged<List<int>> onApply;

  const StreamingFilterSheet({
    super.key,
    required this.initialSelected,
    required this.countryCode,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required List<int> initialSelected,
    required String countryCode,
    required ValueChanged<List<int>> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StreamingFilterSheet(
        initialSelected: initialSelected,
        countryCode: countryCode,
        onApply: onApply,
      ),
    );
  }

  @override
  State<StreamingFilterSheet> createState() => _StreamingFilterSheetState();
}

class _StreamingFilterSheetState extends State<StreamingFilterSheet> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<int>.from(widget.initialSelected);
  }

  void _toggleProvider(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = AppConstants.majorStreamingProviders.map((p) => p.id).toSet();
    });
  }

  void _clearAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final country = AppConstants.getCountry(widget.countryCode);
    final isAnySelected = _selectedIds.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asa superior
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título e indicador de país
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.live_tv_rounded, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Servicios de Streaming',
                        style: AppTextStyles.h2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(country.flag, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            'Catálogo disponible en ${country.name}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Selecciona las plataformas que tienes contratadas. Los títulos recomendados solo provendrán de estos servicios.',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Acciones rápidas (Seleccionar todas / Limpiar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAnySelected ? '${_selectedIds.length} seleccionadas' : 'Todas las plataformas activas',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAnySelected ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _selectAll,
                      child: Text(
                        'Marcar todas',
                        style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: isAnySelected ? _clearAll : null,
                      child: Text(
                        'Limpiar',
                        style: AppTextStyles.caption.copyWith(
                          color: isAnySelected ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Parrilla de plataformas interactivas
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppConstants.majorStreamingProviders.map((provider) {
                    final isSelected = _selectedIds.contains(provider.id);
                    return InkWell(
                      onTap: () => _toggleProvider(provider.id),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: (MediaQuery.of(context).size.width - 50) / 2,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentSubtle : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Logo de la plataforma
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                provider.fullLogoUrl,
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 34,
                                  height: 34,
                                  color: AppColors.surface,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.tv_rounded, size: 18, color: AppColors.accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Nombre
                            Expanded(
                              child: Text(
                                provider.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            // Indicador de selección iluminado
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isSelected ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botón de Aplicar
            CinemaButton(
              text: isAnySelected
                  ? 'Aplicar Filtro (${_selectedIds.length} plataformas)'
                  : 'Usar todo el streaming (Cualquier plataforma)',
              icon: Icons.check_rounded,
              width: double.infinity,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onApply(_selectedIds.toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}
