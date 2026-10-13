import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_catalog_registry.dart';
import '../../core/i18n/locale_provider.dart';
import '../auth/auth_provider.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(
    LanguageMetadata lang,
    LocaleProvider provider,
    AuthProvider? auth,
  ) async {
    await provider.setLocale(Locale(lang.code), authProvider: auth);
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
                  fallback: 'Switched to ${lang.nativeName} (${lang.englishName})',
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
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
        backgroundColor: AppColors.primaryDark,
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

    final currentCode = localeProvider?.currentLanguageCode ?? 'vi';
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
        title: Text(context.tr('settings_language_screen_title', fallback: 'Language Settings')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search input bar with instant filtering
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: context.tr('settings_language_search_hint', fallback: 'Search language or country...'),
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Categorized or filtered language list
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
                  fallback: 'Language "$_searchQuery" not found',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'settings_language_search_tip',
                  fallback: 'Try searching by English name, native name, or language code (e.g. vi, en, fr).',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Device Language (Auto)
                _buildSectionHeader(context.tr('settings_language_section_system', fallback: 'System Default')),
                Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings_suggest, color: AppColors.primary, size: 22),
                    ),
                    title: Text(
                      context.tr('settings_language_auto_title', fallback: 'Automatic (System Default)'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      context.tr('settings_language_auto_desc', fallback: 'Use default language configured on your operating system'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: isDeviceDefault
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                        : null,
                    onTap: localeProvider != null
                        ? () => _onDeviceDefaultSelected(localeProvider, authProvider)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Section 2: Popular Tier-1 Languages Header
                _buildSectionHeader(context.tr(
                  'settings_language_section_popular',
                  args: {'count': '${tier1Languages.length}'},
                  fallback: 'Popular (${tier1Languages.length})',
                )),
              ],
            ),
          ),
        ),

        // Section 2: Popular Tier-1 Languages SliverList
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

        // Section 3: All Languages Catalog Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0),
            child: _buildSectionHeader(context.tr(
              'settings_language_section_all',
              args: {'count': '${allLanguages.length}'},
              fallback: 'All Languages (${allLanguages.length})',
            )),
          ),
        ),

        // Section 3: All Languages Catalog SliverList
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
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

  Widget _buildLanguageListTile({
    required BuildContext context,
    required LanguageMetadata lang,
    required bool isSelected,
    required LocaleProvider? localeProvider,
    required AuthProvider? authProvider,
  }) {
    return ListTile(
      leading: Text(lang.flagEmoji, style: const TextStyle(fontSize: 24)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              lang.nativeName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lang.isRtl) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('RTL', style: TextStyle(fontSize: 10, color: AppColors.primaryDark)),
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
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
          : null,
      onTap: localeProvider != null
          ? () => _onLanguageSelected(lang, localeProvider, authProvider)
          : null,
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.divider,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: _buildLanguageListTile(
        context: context,
        lang: lang,
        isSelected: isSelected,
        localeProvider: localeProvider,
        authProvider: authProvider,
      ),
    );
  }
}
