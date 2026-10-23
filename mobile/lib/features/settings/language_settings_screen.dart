import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_catalog_registry.dart';
import '../../core/i18n/locale_provider.dart';
import '../auth/auth_provider.dart';

/// Screen 5.3 — Ngôn ngữ
/// Matches the 4 primary languages (`Tiếng Việt`, `English`, `日本語`, `中文`) + `Áp dụng` button
/// from the design sheet, while preserving full search and multi-language catalog support.
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<({String code, String label})> _featuredLanguages = [
    (code: 'en', label: 'English (US)'),
    (code: 'vi', label: 'Tiếng Việt (VN)'),
    (code: 'ja', label: '日本語 (JP)'),
    (code: 'zh', label: '中文 (CN)'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(
    LanguageMetadata lang,
    LocaleProvider? provider,
    AuthProvider? auth,
  ) async {
    if (provider != null) {
      await provider.setLocale(Locale(lang.code), authProvider: auth);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(lang.flagEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(
                  'settings_language_switched',
                  args: {'language': '${lang.nativeName} (${lang.englishName})'},
                  fallback: 'Switched to ${lang.nativeName}',
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onDeviceDefaultSelected(
    LocaleProvider provider,
    AuthProvider? auth,
  ) async {
    await provider.setDeviceLocale(authProvider: auth);
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.settings_suggest, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(
                  'settings_language_auto_switched',
                  fallback: 'Language set to system default',
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LocaleProvider? localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context);
    } catch (_) {
      localeProvider = null;
    }

    AuthProvider? authProvider;
    try {
      authProvider = Provider.of<AuthProvider>(context, listen: false);
    } catch (_) {
      authProvider = null;
    }

    final currentCode = localeProvider?.currentLanguageCode ?? 'en';
    final isDeviceDefault = localeProvider?.isDeviceDefault ?? false;

    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchResults = isSearching
        ? LocaleCatalogRegistry.search(_searchQuery.trim())
        : <LanguageMetadata>[];

    final tier1Languages = LocaleCatalogRegistry.tier1Languages;
    final allLanguages = LocaleCatalogRegistry.allLanguages;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr(
            'settings_language_screen_title',
            fallback: 'Cài đặt Ngôn ngữ / Language',
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: context.tr(
                  'settings_language_search_hint',
                  fallback: 'Tìm ngôn ngữ hoặc quốc gia...',
                ),
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          Expanded(
            child: isSearching
                ? _buildSearchResults(
                    context,
                    searchResults,
                    currentCode,
                    isDeviceDefault,
                    localeProvider,
                    authProvider,
                  )
                : _buildCategorizedList(
                    context,
                    currentCode,
                    isDeviceDefault,
                    tier1Languages,
                    allLanguages,
                    localeProvider,
                    authProvider,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    List<LanguageMetadata> results,
    String currentCode,
    bool isDeviceDefault,
    LocaleProvider? localeProvider,
    AuthProvider? authProvider,
  ) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'settings_language_not_found',
                  args: {'query': _searchQuery},
                  fallback: 'Không tìm thấy ngôn ngữ "$_searchQuery"',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 52.0),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final lang = results[index];
        final isSelected = !isDeviceDefault && lang.code == currentCode;
        return _buildLanguageCard(
          context: context,
          lang: lang,
          isSelected: isSelected,
          localeProvider: localeProvider,
          authProvider: authProvider,
        );
      },
    );
  }

  Widget _buildCategorizedList(
    BuildContext context,
    String currentCode,
    bool isDeviceDefault,
    List<LanguageMetadata> tier1Languages,
    List<LanguageMetadata> allLanguages,
    LocaleProvider? localeProvider,
    AuthProvider? authProvider,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // System Default option
                _buildSectionHeader(
                  context.tr('settings_language_section_system', fallback: 'Mặc định hệ thống'),
                ),
                Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDeviceDefault ? AppColors.primary : AppColors.cardBorder,
                      width: isDeviceDefault ? 1.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      context.tr(
                        'settings_language_auto_title',
                        fallback: 'Tự động theo thiết bị',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      context.tr(
                        'settings_language_auto_desc',
                        fallback: 'Sử dụng ngôn ngữ mặc định trên hệ điều hành',
                      ),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: isDeviceDefault
                        ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
                        : null,
                    onTap: localeProvider != null
                        ? () => _onDeviceDefaultSelected(localeProvider, authProvider)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Screen 22 (5.3) Primary 4 Languages in unified white card + "Áp dụng" button
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _featuredLanguages.length; i++)
                        _buildFeaturedDesignLanguageCard(
                          code: _featuredLanguages[i].code,
                          label: _featuredLanguages[i].label,
                          isSelected:
                              !isDeviceDefault &&
                              currentCode == _featuredLanguages[i].code,
                          showDivider: i < _featuredLanguages.length - 1,
                          onTap: () {
                            final meta = LocaleCatalogRegistry.getByCode(
                              _featuredLanguages[i].code,
                            );
                            if (meta != null) {
                              _onLanguageSelected(
                                meta,
                                localeProvider,
                                authProvider,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      context.tr('common_apply', fallback: 'Áp dụng'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSectionHeader(
                  context.tr(
                    'settings_language_section_popular',
                    args: {'count': '${tier1Languages.length}'},
                    fallback: 'Phổ biến (${tier1Languages.length})',
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          sliver: SliverList.builder(
            itemCount: tier1Languages.length,
            itemBuilder: (context, index) {
              final lang = tier1Languages[index];
              final isSelected = !isDeviceDefault && lang.code == currentCode;
              return RepaintBoundary(
                child: _buildLanguageCard(
                  context: context,
                  lang: lang,
                  isSelected: isSelected,
                  localeProvider: localeProvider,
                  authProvider: authProvider,
                ),
              );
            },
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0),
            child: _buildSectionHeader(
              context.tr(
                'settings_language_section_all',
                args: {'count': '${allLanguages.length}'},
                fallback: 'Tất cả ngôn ngữ (${allLanguages.length})',
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 52.0),
          sliver: SliverList.builder(
            itemCount: allLanguages.length,
            itemBuilder: (context, index) {
              final lang = allLanguages[index];
              final isSelected = !isDeviceDefault && lang.code == currentCode;
              return RepaintBoundary(
                child: _buildLanguageCard(
                  context: context,
                  lang: lang,
                  isSelected: isSelected,
                  localeProvider: localeProvider,
                  authProvider: authProvider,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedDesignLanguageCard({
    required String code,
    required String label,
    required bool isSelected,
    bool showDivider = true,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    code == 'en'
                        ? Icons.star_outline_rounded
                        : Icons.language_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 60, endIndent: 18, color: Color(0xFFEEF1EE)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required LanguageMetadata lang,
    required bool isSelected,
    required LocaleProvider? localeProvider,
    required AuthProvider? authProvider,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.inputFill,
            shape: BoxShape.circle,
          ),
          child: Text(lang.flagEmoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                lang.nativeName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lang.isRtl) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RTL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          lang.englishName,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18)
            : null,
        onTap: localeProvider != null
            ? () => _onLanguageSelected(lang, localeProvider, authProvider)
            : null,
      ),
    );
  }
}
