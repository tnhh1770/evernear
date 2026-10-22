import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
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
    final displayTitle = title ?? context.tr('incident_empty_title');
    final displayDesc = description ?? context.tr('incident_empty_desc');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: AppColors.cardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E2022).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
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
      ),
    );
  }
}
