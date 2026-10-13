import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../i18n/app_localizations.dart';

class CalmErrorCard extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final String? retryText;

  const CalmErrorCard({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Soft warm amber
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFFDE68A), // Gentle amber border
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? context.tr('calm_error_default_title', fallback: 'Could not connect'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF78350F),
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE68A),
                  foregroundColor: const Color(0xFF78350F),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  retryText ?? context.tr('common_retry', fallback: AppStrings.retryButton),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
