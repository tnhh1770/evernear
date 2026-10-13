import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../i18n/app_localizations.dart';

class CalmEmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? description;
  final Widget? action;

  const CalmEmptyState({
    super.key,
    this.icon = Icons.verified_user_outlined,
    this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? context.tr('incident_empty_title', fallback: AppStrings.calmEmptyIncidentsTitle);
    final displayDesc = description ?? context.tr('incident_empty_desc', fallback: AppStrings.calmEmptyIncidentsDesc);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
