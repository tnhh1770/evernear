import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../i18n/locale_catalog_registry.dart';
import '../i18n/locale_provider.dart';
import '../../features/auth/auth_provider.dart';

/// Reusable LanguageSelector component for pre-auth and post-auth screens.
/// Features a compact pill-shaped dropdown displaying the current language's
/// flag emoji and 2-letter uppercase ISO code, opening a clean menu of all
/// supported world languages.
class LanguageSelector extends StatelessWidget {
  final Key? dropdownKey;
  final LocaleProvider? localeProvider;
  final AuthProvider? authProvider;
  final ValueChanged<String>? onChanged;
  final AlignmentGeometry alignment;
  final bool isDense;

  const LanguageSelector({
    super.key,
    this.dropdownKey,
    this.localeProvider,
    this.authProvider,
    this.onChanged,
    this.alignment = Alignment.center,
    this.isDense = true,
  });

  @override
  Widget build(BuildContext context) {
    LocaleProvider? provider = localeProvider;
    if (provider == null) {
      try {
        provider = Provider.of<LocaleProvider>(context);
      } catch (_) {}
    }

    AuthProvider? auth = authProvider;
    if (auth == null) {
      try {
        auth = Provider.of<AuthProvider>(context, listen: false);
      } catch (_) {}
    }

    final currentCode = provider?.currentLanguageCode ?? 'vi';

    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: dropdownKey ?? const Key('preauth_language_selector'),
            value: currentCode,
            icon: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.arrow_drop_down,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
            isDense: isDense,
            menuWidth: 200,
            menuMaxHeight: 380,
            borderRadius: BorderRadius.circular(16),
            selectedItemBuilder: (context) {
              return LocaleCatalogRegistry.allLanguages.map((lang) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lang.flagEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      lang.code.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: LocaleCatalogRegistry.allLanguages.map((lang) {
              return DropdownMenuItem<String>(
                value: lang.code,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lang.flagEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        lang.nativeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (newCode) {
              if (newCode != null && provider != null) {
                provider.setLocale(Locale(newCode), authProvider: auth);
              }
              if (newCode != null) {
                onChanged?.call(newCode);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Compatibility alias
typedef LanguageSelectorCapsule = LanguageSelector;
