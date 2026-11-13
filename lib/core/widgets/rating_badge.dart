import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class RatingBadge extends StatelessWidget {
  final double rating;
  final bool showStar;
  final double fontSize;

  const RatingBadge({
    super.key,
    required this.rating,
    this.showStar = true,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStar) ...[
            const Icon(
              Icons.star_rounded,
              color: AppColors.accent,
              size: 16,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            rating.toStringAsFixed(1),
            style: AppTextStyles.metadata.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
