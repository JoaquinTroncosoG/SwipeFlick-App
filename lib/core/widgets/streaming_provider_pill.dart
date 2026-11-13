import 'package:flutter/material.dart';
import '../../data/models/streaming_provider_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class StreamingProviderPill extends StatelessWidget {
  final StreamingProviderModel provider;

  const StreamingProviderPill({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              provider.fullLogoUrl,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 24,
                height: 24,
                color: AppColors.surfaceBorder,
                child: const Icon(Icons.tv, size: 14, color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider.name,
            style: AppTextStyles.metadata.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
