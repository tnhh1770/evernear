import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../i18n/app_localizations.dart';

class CalmLoadingWidget extends StatelessWidget {
  final String? message;
  final double size;

  const CalmLoadingWidget({
    super.key,
    this.message,
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final displayMessage = message ?? context.tr('common_loading');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(
                strokeWidth: 3.0,
                color: AppColors.primary,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
