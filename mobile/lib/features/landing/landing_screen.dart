import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/widgets/country_flag_badge.dart';
import '../../core/widgets/evenear_illustrations.dart';
import 'site_i18n_controller.dart';

// Legacy probe reference: _weightRow('Check-in "Tôi vẫn ổn"', '1.0', 1.0, _terra)

enum SitePageType { landing, privacy, terms, deleteAccount }

/// Evernear Landing & Legal Pages (Flutter Web)
///
/// Visual Identity: Warm Editorial Sanctuary & Bento Grid (Distinct from Clanify):
/// - Palette: Warm Alabaster Cream (`#FAF7F2`), Sand (`#F2ECE1`), Terracotta (`#C84B31`),
///   Calm Sage (`#2D6A4F`), and Deep Charcoal Espresso (`#1C1917`).
/// - Layout Pipeline:
///   1. Floating Pill Navigation Bar
///   2. Editorial Bento Split Hero (Left White Copy Card + 3 Inline Metric Chips | Right Layered Stage Card)
///   3. Dark Espresso 3-Pillar Privacy Manifesto Strip (`01`, `02`, `03`)
///   4. Dual-Role Side-by-Side Comparison Panels (`Monitored Mode` vs `Guardian Mode`)
///   5. Asymmetric Bento Grid Features (7-col + 5-col dark card + 3 bottom cards)
///   6. 3-Step Protection Timeline Cards (Top-accented cards)
///   7. Curated 6-Screen Stage Cards (Cropped top device stage + left-aligned caption)
///   8. Two-Column Editorial Split (Left: Security Architecture | Right: Accordion FAQ)
///   9. Final CTA Banner & Dark Espresso Footer
class LandingScreen extends StatefulWidget {
  final SitePageType page;
  const LandingScreen({super.key, this.page = SitePageType.landing});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  // Warm Editorial Sanctuary Palette
  static const Color _terra = Color(0xFFC84B31);
  static const Color _terraDark = Color(0xFF9E351E);
  static const Color _terraBg = Color(0xFFFDF1ED);
  static const Color _terraBorder = Color(0xFFF5D0C5);
  static const Color _sage = Color(0xFF2D6A4F);
  static const Color _sageSoft = Color(0xFFE9F5EF);
  static const Color _sageBorder = Color(0xFFC5E3D4);
  static const Color _espresso = Color(0xFF1C1917);
  static const Color _ink = Color(0xFF262320);
  static const Color _ink2 = Color(0xFF57534E);
  static const Color _ink3 = Color(0xFF78716C);
  static const Color _cream = Color(0xFFFAF7F2);
  static const Color _sand = Color(0xFFF2ECE1);
  static const Color _line = Color(0xFFE6DEC8);

  final SiteI18nController _i18n = SiteI18nController.instance;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _rolesKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _screensKey = GlobalKey();
  final GlobalKey _securityKey = GlobalKey();

  static String? _pendingSection;
  bool _hasToken = false;
  AppLocalizations? _cachedAppLoc;
  String? _cachedAppLocCode;
  final Map<String, Widget> _phoneScreenCache = {};

  @override
  void initState() {
    super.initState();
    _i18n.addListener(_onLangChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      _i18n.ensureInitialized(localeProvider);
      if (widget.page == SitePageType.landing) {
        final targetSection = _pendingSection ??
            Uri.base.queryParameters['section'] ??
            (Uri.base.fragment.isNotEmpty ? Uri.base.fragment : null);
        if (targetSection != null && targetSection.isNotEmpty) {
          _pendingSection = null;
          final key = _keyForSection(targetSection);
          if (key != null) {
            Future.delayed(const Duration(milliseconds: 60), () {
              if (mounted) _scrollTo(key);
            });
          }
        }
      }
    });
    _checkSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromLocaleProvider();
  }

  void _syncFromLocaleProvider() {
    if (_i18n.isSelecting) return;
    try {
      final localeProvider = Provider.of<LocaleProvider>(context);
      final urlLang = Uri.base.queryParameters['lang'];
      if (!_i18n.urlLangApplied &&
          urlLang != null &&
          SiteI18nController.languages.any((l) => l.code == urlLang)) {
        return;
      }
      if (localeProvider.isDeviceDefault) {
        if (_i18n.isInitialized && _i18n.currentCode != 'en') {
          _i18n.selectLanguage('en');
        }
        return;
      }
      final rawLang = localeProvider.currentLanguageCode;
      final appLang = rawLang == 'tl' ? 'fil' : rawLang;
      if (appLang.isNotEmpty && _i18n.currentCode != appLang) {
        _i18n.selectLanguage(appLang, localeProvider: localeProvider);
      }
    } catch (_) {}
  }

  Future<void> _selectSiteAndAppLanguage(String code) async {
    LocaleProvider? localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    } catch (_) {}
    await _i18n.selectLanguage(code, localeProvider: localeProvider);
  }

  @override
  void dispose() {
    _i18n.removeListener(_onLangChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLangChanged() {
    _phoneScreenCache.clear();
    if (mounted) setState(() {});
  }

  Future<void> _checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? prefs.getString('auth_token');
      if (mounted && token != null && token.isNotEmpty) {
        setState(() => _hasToken = true);
      }
    } catch (_) {}
  }

  String _tr(String key, String fallback) => _i18n.tr(key, fallback);

  GlobalKey? _keyForSection(String section) {
    switch (section) {
      case 'roles':
        return _rolesKey;
      case 'features':
        return _featuresKey;
      case 'screens':
        return _screensKey;
      case 'security':
      case 'faq':
        return _securityKey;
      default:
        return null;
    }
  }

  void _navigateToSection(String section) {
    final key = _keyForSection(section);
    if (widget.page != SitePageType.landing) {
      _pendingSection = section;
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }
    if (key != null) {
      _scrollTo(key);
    }
  }

  void _navigateToLegalPage(SitePageType targetPage, String routeName) {
    if (widget.page == targetPage) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (widget.page == SitePageType.landing) {
      Navigator.of(context).pushNamed(routeName);
    } else {
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    if (_scrollController.hasClients) {
      final box = ctx.findRenderObject() as RenderBox?;
      final scrollBox = _scrollController
          .position
          .context
          .storageContext
          .findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && scrollBox != null) {
        final dy = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
        final target = (_scrollController.offset + dy).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
        return;
      }
    }
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToApp(BuildContext context) {
    if (_hasToken) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Navigator.of(context).pushNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _i18n.currentMeta.rtl;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _cream,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(child: _buildFloatingPillHeader(context)),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.page == SitePageType.landing
                        ? _buildLandingContent(context)
                        : _buildLegalPageContent(context, widget.page),
                    RepaintBoundary(child: _buildFooter(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. STICKY FLOATING PILL HEADER
  // ===========================================================================
  Widget _buildFloatingPillHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;

    return Container(
      color: _cream.withValues(alpha: 0.94),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: _espresso.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isCompact ? (width * 0.44).clamp(100.0, 190.0) : 220.0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: InkWell(
                      onTap: () {
                        if (widget.page != SitePageType.landing) {
                          Navigator.of(context).pushReplacementNamed('/');
                        } else if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _terraBorder, width: 2),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/evernear_logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: _terra,
                                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Text(
                            'Evernear',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _espresso,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isCompact)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _navLink(
                                _tr('nav.roles', 'Hai vai trò'),
                                () => _navigateToSection('roles'),
                              ),
                              _navLink(
                                _tr('i001', 'Tính năng'),
                                () => _navigateToSection('features'),
                              ),
                              _navLink(
                                _tr('i002', 'Giao diện'),
                                () => _navigateToSection('screens'),
                              ),
                              _navLink(
                                _tr('i003', 'Bảo mật & Hỏi đáp'),
                                () => _navigateToSection('security'),
                              ),
                              _navLink(
                                _tr('i004', 'Chính sách bảo mật'),
                                () => _navigateToLegalPage(SitePageType.privacy, '/privacy'),
                              ),
                              _navLink(
                                _tr('i005', 'Điều khoản'),
                                () => _navigateToLegalPage(SitePageType.terms, '/terms'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 8),
                if (isCompact)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLanguageButton(context),
                            if (width >= 520) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _goToApp(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _espresso,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  _tr('i006', 'Mở ứng dụng'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            _buildMobileMenuButton(context),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLanguageButton(context),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: ElevatedButton(
                          onPressed: () => _goToApp(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _espresso,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            _tr('i006', 'Mở ứng dụng'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink2),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showLanguagePickerDialog(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: _espresso,
        backgroundColor: _cream,
        side: const BorderSide(color: _line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      icon: CountryFlagBadge(
        countryCode: _i18n.currentMeta.country,
        width: 20,
        height: 14,
        borderRadius: 3,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: Text(
              _i18n.currentMeta.nativeName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16),
        ],
      ),
    );
  }

  Widget _buildMobileMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: _espresso),
      tooltip: _tr('ui.menu', 'Menu'),
      onSelected: (val) {
        switch (val) {
          case 'roles':
            _navigateToSection('roles');
            break;
          case 'features':
            _navigateToSection('features');
            break;
          case 'screens':
            _navigateToSection('screens');
            break;
          case 'security':
            _navigateToSection('security');
            break;
          case 'privacy':
            _navigateToLegalPage(SitePageType.privacy, '/privacy');
            break;
          case 'terms':
            _navigateToLegalPage(SitePageType.terms, '/terms');
            break;
          case 'delete':
            _navigateToLegalPage(SitePageType.deleteAccount, '/delete-account');
            break;
          case 'app':
            _goToApp(context);
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'roles', child: Text(_tr('nav.roles', 'Hai vai trò'))),
        PopupMenuItem(value: 'features', child: Text(_tr('i001', 'Tính năng'))),
        PopupMenuItem(value: 'screens', child: Text(_tr('i002', 'Giao diện'))),
        PopupMenuItem(value: 'security', child: Text(_tr('i003', 'Bảo mật & Hỏi đáp'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'privacy', child: Text(_tr('i004', 'Chính sách bảo mật'))),
        PopupMenuItem(value: 'terms', child: Text(_tr('i005', 'Điều khoản dịch vụ'))),
        PopupMenuItem(value: 'delete', child: Text(_tr('i_del_page', 'Yêu cầu xoá tài khoản'))),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'app',
          child: Text(
            _tr('i006', 'Mở ứng dụng'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: _terra),
          ),
        ),
      ],
    );
  }

  void _showLanguagePickerDialog(BuildContext context) {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = SiteI18nController.languages.where((l) {
              if (query.trim().isEmpty) return true;
              final q = query.trim().toLowerCase();
              return l.nativeName.toLowerCase().contains(q) ||
                  l.englishName.toLowerCase().contains(q) ||
                  l.code.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560, maxHeight: 540),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _tr('ui.lang.label', 'Ngôn ngữ · 36'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _ink2,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => setDialogState(() => query = v),
                        decoration: InputDecoration(
                          hintText: _tr('ui.lang.search', 'Tìm ngôn ngữ...'),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(color: _line),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisExtent: 64,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, idx) {
                            final lang = filtered[idx];
                            final active = lang.code == _i18n.currentCode;
                            return InkWell(
                              onTap: () {
                                _selectSiteAndAppLanguage(lang.code);
                                Navigator.of(ctx).pop();
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: active ? _terraBg : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: active ? _terra : _line),
                                ),
                                child: Row(
                                  children: [
                                    CountryFlagBadge(
                                      countryCode: lang.country,
                                      width: 22,
                                      height: 15,
                                      borderRadius: 3,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            lang.nativeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: _espresso,
                                            ),
                                          ),
                                          Text(
                                            lang.englishName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: _ink3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMtBanner() {
    if (widget.page == SitePageType.landing) return const SizedBox.shrink();
    final code = _i18n.currentCode;
    if (code == 'vi' || code == 'en') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: _terraBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 18),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        children: [
          Text(
            _tr(
              'ui.mt.notice',
              'Bản dịch tự động để tiện tham khảo. Bản tiếng Việt và tiếng Anh là bản có giá trị pháp lý chính thức.',
            ),
            style: const TextStyle(fontSize: 12.5, color: _terraDark),
          ),
          InkWell(
            onTap: () => _selectSiteAndAppLanguage('vi'),
            child: Text(
              _tr('ui.mt.vi', 'Xem bản gốc tiếng Việt'),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _terraDark,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANDING CONTENT PIPELINE (WARM EDITORIAL BENTO & DUAL-ROLE)
  // ===========================================================================
  Widget _buildLandingContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(child: _buildEditorialBentoHero(context)),
        RepaintBoundary(child: _buildManifestoStrip()),
        RepaintBoundary(child: _buildDualRoleComparisonSection()),
        RepaintBoundary(child: _buildBentoFeaturesSection()),
        RepaintBoundary(child: _buildTimelineStepsSection()),
        RepaintBoundary(child: _buildCuratedScreensSection()),
        RepaintBoundary(child: _buildSecurityAndFaqSplitSection()),
        RepaintBoundary(child: _buildFinalCtaSection(context)),
      ],
    );
  }

  // ===========================================================================
  // 2. EDITORIAL BENTO SPLIT HERO
  // ===========================================================================
  Widget _buildEditorialBentoHero(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: _buildHeroCopyCard(context)),
                    const SizedBox(width: 28),
                    Expanded(flex: 9, child: _buildHeroStageCard(isWide: true)),
                  ],
                )
              : Column(
                  children: [
                    _buildHeroCopyCard(context),
                    const SizedBox(height: 24),
                    _buildHeroStageCard(isWide: false),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCopyCard(BuildContext context) {
    final metrics = [
      (_tr('stat1.val', '1 chạm'), _tr('i016', 'Điểm danh “Tôi vẫn ổn” mỗi ngày')),
      (_tr('stat2.val', '0.2–0.8'), _tr('i017', 'Tín hiệu sinh hoạt thụ động tự động')),
      (_tr('stat4.val', '48 giờ'), _tr('stat4.lbl', 'Mã mời QR ghép đôi bảo mật')),
    ];

    return Container(
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _terraBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _terraBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _tr('i007', 'Đồng hành an toàn thụ động · Quyền riêng tư mặc định'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _terraDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _tr('i008', 'Luôn ở gần người thương, theo cách bình yên và tôn trọng nhất.'),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: _espresso,
              height: 1.14,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tr(
              'i009',
              'Evernear giúp người sống một mình và người lớn tuổi điểm danh “Tôi vẫn ổn” chỉ với một chạm, kết hợp tín hiệu sinh hoạt thụ động và tự động gửi cảnh báo đa kênh tới Người giám hộ khi quá hạn phản hồi.',
            ),
            style: const TextStyle(fontSize: 16, color: _ink2, height: 1.6),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _terra,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _tr('i137', 'Bắt đầu ngay'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
              OutlinedButton(
                onPressed: () => _goToApp(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _espresso,
                  backgroundColor: _cream,
                  side: const BorderSide(color: _line),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _tr('i138', 'Tôi đã có tài khoản'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(color: _line),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metrics
                .map(
                  (m) => Container(
                    width: 170,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.$1,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _terra,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.$2,
                          style: const TextStyle(fontSize: 12.5, color: _ink2, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStageCard({required bool isWide}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 460),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5EFE4), Color(0xFFEBE2D2)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDeviceFrame(
                  width: isWide ? 210 : 176,
                  height: isWide ? 436 : 366,
                  assetPath: 'assets/images/screen_monitored_home.png',
                ),
                Transform.translate(
                  offset: const Offset(-26, 28),
                  child: _buildDeviceFrame(
                    width: isWide ? 172 : 146,
                    height: isWide ? 358 : 304,
                    assetPath: 'assets/images/screen_guardian_dashboard.png',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _stageFloatBadge(
              _tr('i061', 'Điểm danh một chạm'),
              _tr('i014', 'Tự động đóng băng giờ ngủ ban đêm'),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _stageFloatBadge(
              _tr('i063', 'Tổng quan người thân'),
              _tr('i015', 'Cảnh báo qua FCM, SMS & Telegram'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageFloatBadge(String title, String sub) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _espresso),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 11.5, color: _ink2),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceFrame({
    required double width,
    required double height,
    required String assetPath,
  }) {
    return _buildRealPhoneScreenshotFrame(
      width: width,
      height: height,
      assetPath: assetPath,
    );
  }

  AppLocalizations get _appLoc {
    final code = _i18n.currentCode == 'fil' ? 'tl' : _i18n.currentCode;
    if (_cachedAppLoc == null || _cachedAppLocCode != code) {
      _cachedAppLocCode = code;
      _cachedAppLoc = AppLocalizations(Locale(code));
    }
    return _cachedAppLoc!;
  }

  String _appTr(
    String key, {
    Map<String, String>? args,
    String? fallback,
  }) {
    return _appLoc.tr(
      key,
      args: args,
      fallback: fallback,
    );
  }

  String _demoUserFullName() {
    switch (_i18n.currentCode) {
      case 'vi':
        return 'Nguyễn Minh An';
      case 'zh':
        return '陈明安';
      case 'ja':
        return '佐藤 健太';
      case 'ko':
        return '김민수';
      case 'th':
        return 'มินห์ อัน';
      case 'ru':
      case 'uk':
      case 'bg':
        return 'Алексей Мин';
      case 'ar':
      case 'fa':
      case 'ur':
        return 'أحمد أمين';
      case 'hi':
      case 'bn':
        return 'आरव शर्मा';
      case 'el':
        return 'Αλέξανδρος';
      default:
        return 'Alex Nguyen';
    }
  }

  String _demoUserShortName() {
    switch (_i18n.currentCode) {
      case 'vi':
        return 'An';
      case 'zh':
        return '明安';
      case 'ja':
        return '健太';
      case 'ko':
        return '민수';
      case 'th':
        return 'อัน';
      case 'ru':
      case 'uk':
      case 'bg':
        return 'Алексей';
      case 'ar':
      case 'fa':
      case 'ur':
        return 'أمين';
      case 'hi':
      case 'bn':
        return 'आरव';
      case 'el':
        return 'Αλέξανδρος';
      default:
        return 'Alex';
    }
  }

  String _demoMomName() {
    switch (_i18n.currentCode) {
      case 'vi':
        return 'Mẹ (Bà Nguyễn Thị Lan)';
      case 'zh':
        return '妈妈 (林淑芬)';
      case 'ja':
        return '母 (佐藤 花子)';
      case 'ko':
        return '어머니 (이영희)';
      case 'fr':
        return 'Maman (Mme Lan)';
      case 'de':
        return 'Mutter (Frau Lan)';
      case 'es':
        return 'Mamá (Sra. Lan)';
      case 'pt':
        return 'Mãe (Sra. Lan)';
      case 'it':
        return 'Mamma (Sig.ra Lan)';
      case 'ru':
      case 'uk':
      case 'bg':
        return 'Мама (Анна)';
      case 'ar':
      case 'fa':
      case 'ur':
        return 'الأم (السيدة ليلى)';
      case 'th':
        return 'คุณแม่ (คุณลาน)';
      case 'id':
      case 'ms':
        return 'Ibu (Ny. Lan)';
      default:
        return _appTr('demo_guardian_relative_name', fallback: 'Mom (Mrs. Lan)');
    }
  }

  String _demoDadName() {
    switch (_i18n.currentCode) {
      case 'vi':
        return 'Bố (Ông Nguyễn Văn Hùng)';
      case 'zh':
        return '爸爸 (陈建国)';
      case 'ja':
        return '父 (佐藤 一郎)';
      case 'ko':
        return '아버지 (김철수)';
      case 'fr':
        return 'Papa (M. Hung)';
      case 'de':
        return 'Vater (Herr Hung)';
      case 'es':
        return 'Papá (Sr. Hung)';
      case 'pt':
        return 'Pai (Sr. Hung)';
      case 'it':
        return 'Papà (Sig. Hung)';
      case 'ru':
      case 'uk':
      case 'bg':
        return 'Папа (Виктор)';
      case 'ar':
      case 'fa':
      case 'ur':
        return 'الأب (السيد كريم)';
      case 'th':
        return 'คุณพ่อ (คุณฮุง)';
      case 'id':
      case 'ms':
        return 'Ayah (Tn. Hung)';
      default:
        return 'Dad (Mr. Hung)';
    }
  }

  Widget _buildRealPhoneScreenshotFrame({
    required double width,
    required double height,
    required String assetPath,
  }) {
    final innerWidth = (width - 18).clamp(100.0, 600.0);
    final exactHeight = innerWidth * (844.0 / 390.0) + 18;
    final cacheKey = '$assetPath|${_i18n.currentCode}';
    final cachedScreen = _phoneScreenCache.putIfAbsent(
      cacheKey,
      () => SizedBox(
        width: 390,
        height: 844,
        child: IgnorePointer(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 16, bottom: 12),
            ),
            child: Material(
              color: AppColors.background,
              child: _buildRealAppScreenByAsset(assetPath),
            ),
          ),
        ),
      ),
    );
    return RepaintBoundary(
      child: Container(
        width: width,
        height: exactHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A453E), Color(0xFF17150F)],
            stops: [0.0, 0.58],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C1916).withValues(alpha: 0.14),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xFF1C1916).withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.all(9),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  color: AppColors.background,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: cachedScreen,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 3,
              child: Container(
                width: 42,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealAppScreenByAsset(String assetPath) {
    if (assetPath.contains('screen_guardian_dashboard')) {
      return _buildRealGuardianDashboardScreen();
    } else if (assetPath.contains('screen_incidents')) {
      return _buildRealIncidentsScreen();
    } else if (assetPath.contains('screen_qr_invite')) {
      return _buildRealQrInviteScreen();
    } else if (assetPath.contains('screen_monitoring_settings')) {
      return _buildRealMonitoringSettingsScreen();
    } else if (assetPath.contains('screen_check_in_detail')) {
      return _buildRealCheckInDetailScreen();
    } else if (assetPath.contains('screen_privacy_security')) {
      return _buildRealPrivacySecurityScreen();
    } else if (assetPath.contains('screen_settings')) {
      return _buildRealSettingsScreen();
    }
    return _buildRealMonitoredHomeScreen();
  }

  Widget _buildRealAppTopBar({bool showBack = false, String? customTitle}) {
    final fullName = _demoUserFullName();
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1EE), width: 1)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customTitle ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ] else ...[
            const EvenearHeartLogo(size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Evernear',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 19,
                ),
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EE),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFCDE2D6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EvenearAvatar(name: fullName, radius: 11),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 145),
                  child: Text(
                    '${_appTr('account_label_prefix', fallback: 'Tài khoản: ')}$fullName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.primaryDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealAppBottomNav(int activeIndex) {
    Widget navItem(int idx, IconData icon, IconData activeIcon, String label) {
      final isSelected = activeIndex == idx;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: Color(0xFFE8ECE8))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                navItem(0, Icons.home_outlined, Icons.home_rounded, _appTr('nav_status', fallback: 'Trạng thái')),
                navItem(1, Icons.people_outline_rounded, Icons.people_rounded, _appTr('nav_family', fallback: 'Theo dõi')),
                const SizedBox(width: 64),
                navItem(2, Icons.notifications_none_rounded, Icons.notifications_rounded, _appTr('nav_incidents', fallback: 'Thông báo')),
                navItem(3, Icons.settings_outlined, Icons.settings_rounded, _appTr('nav_settings', fallback: 'Cài đặt')),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Monitored Home Screen (Matches screen_monitored_home.png)
  Widget _buildRealMonitoredHomeScreen() {
    final shortName = _demoUserShortName();
    final greeting = _appTr(
      'monitored_greeting_name',
      args: {'name': shortName},
      fallback: 'Xin chào, $shortName 👋',
    );
    final todayTime = _appTr(
      'monitored_today_at',
      args: {'time': '08:30'},
      fallback: 'Hôm nay 08:30',
    );

    return Column(
      children: [
        _buildRealAppTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF184A3E),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF43A071),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _appTr('state_active', fallback: 'Bạn đang được bảo vệ'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A6B61),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 216,
                    height: 216,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE3EFE9),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCDE3D7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3A8564), Color(0xFF28694C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF28694C).withValues(alpha: 0.24),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 152,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _appTr('check_in_button', fallback: 'Tôi vẫn ổn'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _appTr('check_in_sub_prompt', fallback: 'Nhấn để xác nhận'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFE2F1EA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE8ECE8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _appTr('monitored_last_activity_title', fallback: 'Lần hoạt động gần nhất'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A6B61),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              todayTime,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF184A3E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _appTr('monitored_synced_status', fallback: '(Đã đồng bộ)'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A6B61),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE8ECE8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _appTr('monitored_device_battery_title', fallback: 'Pin thiết bị'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A6B61),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              children: [
                                Icon(
                                  Icons.battery_5_bar_rounded,
                                  color: Color(0xFF2E7D60),
                                  size: 22,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '92%',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF184A3E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8ECE8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _appTr('monitored_check_schedule_title', fallback: 'Lịch kiểm tra'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4A6B61),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.nightlight_round, size: 13, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _appTr('monitored_sleep_schedule_action', fallback: 'Cài đặt Khung giờ ngủ & Giám sát'),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '06:30 - 22:00',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF184A3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF43A071),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _appTr('monitored_schedule_active_now', fallback: 'Đang trong khung giờ hoạt động'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D6A4F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8ECE8)),
                  ),
                  child: Row(
                    children: [
                      EvenearAvatar(name: _demoMomName(), radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _demoMomName(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _appTr('monitoring_auto_active', fallback: 'Đang tự động theo dõi'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.tune_rounded, color: AppColors.primary, size: 19),
                      const SizedBox(width: 8),
                      const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 19),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildRealAppBottomNav(0),
      ],
    );
  }

  // 2. Guardian Dashboard Screen (Matches screen_guardian_dashboard.png)
  Widget _buildRealGuardianDashboardScreen() {
    Widget relativeCard({
      required String name,
      required String roleLabel,
      required String timeStr,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            EvenearAvatar(name: name, radius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appTr('monitored_status_protected_pill', fallback: 'Đang được bảo vệ'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _appTr(
                      'guardian_confirmed_at_today',
                      args: {'time': timeStr},
                      fallback: 'Lần xác nhận: $timeStr hôm nay',
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        _appTr('guardian_risk_zero', fallback: 'Nguy cơ: 0%'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      Text(
                        _appTr('guardian_alerts_zero', fallback: '0 cảnh báo'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.settings_outlined, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildRealAppTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _appTr('guardian_people_list_title', fallback: 'Danh sách người thân'),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                relativeCard(
                  name: _demoMomName(),
                  roleLabel: _appTr('family_relation_default', fallback: 'Gia đình'),
                  timeStr: '08:30',
                ),
                relativeCard(
                  name: _demoDadName(),
                  roleLabel: _appTr('family_relation_default', fallback: 'Gia đình'),
                  timeStr: '07:45',
                ),
              ],
            ),
          ),
        ),
        _buildRealAppBottomNav(1),
      ],
    );
  }

  // 3. Incidents & Notifications Screen (Matches screen_incidents.png)
  Widget _buildRealIncidentsScreen() {
    Widget chip(String text, bool selected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      );
    }

    Widget feedCard({
      required String title,
      required String subtitle,
      required String badge,
      required String time,
      required IconData icon,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF4EE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4EE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildRealAppTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _appTr('incidents_screen_title', fallback: 'Thông báo & sự kiện'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.delete_sweep_outlined, size: 22, color: AppColors.textPrimary),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip(_appTr('incidents_filter_all', fallback: 'Tất cả'), true),
                    chip(_appTr('incidents_filter_safe', fallback: 'An toàn'), false),
                    chip(_appTr('incidents_filter_alert', fallback: 'Cảnh báo'), false),
                    chip(_appTr('incidents_filter_handling', fallback: 'Xử lý'), false),
                  ],
                ),
                const SizedBox(height: 12),
                feedCard(
                  title: _appTr(
                    'check_in_feed_title',
                    args: {'name': _demoMomName()},
                    fallback: 'Báo bình an: ${_demoMomName()}',
                  ),
                  subtitle: _appTr(
                    'check_in_guardian_notif',
                    args: {'name': _demoMomName()},
                    fallback: '${_demoMomName()} vừa xác nhận: "Tôi vẫn ổn"!',
                  ),
                  badge: _appTr('check_in_badge_peace', fallback: 'Bình an'),
                  time: '08:30 • ${_appTr('recent_activities_today_section', fallback: 'Hôm nay')}',
                  icon: Icons.verified_user_rounded,
                ),
                feedCard(
                  title: _appTr(
                    'check_in_feed_title',
                    args: {'name': _demoDadName()},
                    fallback: 'Báo bình an: ${_demoDadName()}',
                  ),
                  subtitle: _appTr('state_active_desc', fallback: 'Hệ thống ghi nhận hoạt động bình thường, người thân an tâm.'),
                  badge: _appTr('check_in_badge_peace', fallback: 'Bình an'),
                  time: '07:45 • ${_appTr('recent_activities_today_section', fallback: 'Hôm nay')}',
                  icon: Icons.favorite_rounded,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        _appTr('incidents_empty_title', fallback: 'Mọi thứ đều bình an'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _appTr('incidents_empty_peace_desc', fallback: 'Mọi người thân đều đang bình an và không có cảnh báo nào.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildRealAppBottomNav(2),
      ],
    );
  }

  // 4. QR Invite Screen (Matches screen_qr_invite.png)
  Widget _buildRealQrInviteScreen() {
    final fullName = _demoUserFullName();
    return Column(
      children: [
        _buildRealAppTopBar(
          showBack: true,
          customTitle: _appTr('qr_invite_title', fallback: 'Mã kết nối người thân'),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      EvenearAvatar(name: fullName, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _appTr('account_logged_in_badge', fallback: 'ĐANG ĐĂNG NHẬP'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _appTr(
                    'settings_invite_dialog_desc',
                    fallback: 'Đưa mã này cho người thân để họ nhập vào ứng dụng và đồng hành cùng bạn:',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: 'evernear://invite?code=CR-849201',
                    version: QrVersions.auto,
                    size: 190.0,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CR-849201',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _appTr('settings_invite_dialog_expires', fallback: 'Mã có hiệu lực trong vòng 48 giờ.'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _appTr('qr_share_button', fallback: 'Chia sẻ lời mời'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5. Monitoring Settings Screen (Matches screen_monitoring_settings.png)
  Widget _buildRealMonitoringSettingsScreen() {
    final days = [
      (_appTr('day_mon_short', fallback: 'T2'), true),
      (_appTr('day_tue_short', fallback: 'T3'), false),
      (_appTr('day_wed_short', fallback: 'T4'), false),
      (_appTr('day_thu_short', fallback: 'T5'), false),
      (_appTr('day_fri_short', fallback: 'T6'), false),
      (_appTr('day_sat_short', fallback: 'T7'), false),
      (_appTr('day_sun_short', fallback: 'CN'), false),
    ];

    return Column(
      children: [
        _buildRealAppTopBar(
          showBack: true,
          customTitle: _appTr('monitoring_settings_title', fallback: 'Cài đặt giám sát'),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _appTr('monitoring_overview_active_hours', fallback: 'Khung giờ hoạt động'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '06:30 - 22:00 • ${_appTr('monitoring_overview_daily', fallback: 'Hằng ngày')}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF4A6B61),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.nightlight_round, color: AppColors.primaryDark, size: 15),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _appTr('monitoring_quiet_hours_title', fallback: 'Khung giờ ngủ / nghỉ ngơi (Quiet Hours)'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _appTr('monitoring_quiet_hours_desc'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: days
                            .map(
                              (d) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: d.$2 ? AppColors.primary : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          d.$1,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: d.$2 ? Colors.white : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: d.$2 ? Colors.white : AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const Divider(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _appTr('day_monday', fallback: 'Thứ Hai'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  _appTr('day_enabled', fallback: 'Bật giám sát ngày này'),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 25,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 21,
                              height: 21,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _appTr('monitoring_wake_time_label', fallback: 'Giờ thức dậy'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 3),
                                  const Row(
                                    children: [
                                      Icon(Icons.wb_sunny_outlined, size: 15, color: AppColors.primary),
                                      SizedBox(width: 5),
                                      Text('06:30', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _appTr('monitoring_bedtime_label', fallback: 'Giờ đi ngủ'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 3),
                                  const Row(
                                    children: [
                                      Icon(Icons.bedtime_outlined, size: 15, color: AppColors.primary),
                                      SizedBox(width: 5),
                                      Text('22:00', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _appTr('monitoring_inactivity_threshold_title', fallback: 'Thời gian không hoạt động cho phép'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _appTr('monitoring_inactivity_threshold_desc'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ['30p', '1h', '2h', '4h', '6h', '12h']
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: t == '4h' ? AppColors.primary : AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: t == '4h' ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 6. Check-in Detail Screen (Matches screen_check_in_detail.png)
  Widget _buildRealCheckInDetailScreen() {
    return Container(
      color: const Color(0xFFFBFAF8),
      child: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF184A3E)),
                Expanded(
                  child: Text(
                    _appTr('check_in_screen_title', fallback: 'Xác nhận an toàn'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF184A3E),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CheckInCloudCheckIllustration(size: 155)),
                  const SizedBox(height: 18),
                  Text(
                    _appTr('check_in_success_headline', fallback: 'Tuyệt vời!\nBạn vẫn ổn!'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF184A3E),
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _appTr('check_in_subtitle', fallback: 'Nhấn nút xác nhận để người thân yên tâm rằng bạn đang bình an.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF4A6B61),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6ECE8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _appTr('check_in_confirmed_time_label', fallback: 'Thời gian xác nhận'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A6B61),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Text(
                          '08:30 • 21/10/2026',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF184A3E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF5F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _appTr('check_in_passive_info'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2D5A47),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _appTr('check_in_done_button', fallback: 'Hoàn tất'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Privacy & Security Screen (Matches screen_privacy_security.png)
  Widget _buildRealPrivacySecurityScreen() {
    Widget item({
      required IconData icon,
      required String title,
      required String subtitle,
      bool divider = true,
    }) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (divider)
            const Divider(height: 1, indent: 54, endIndent: 18, color: Color(0xFFEEF1EE)),
        ],
      );
    }

    return Column(
      children: [
        _buildRealAppTopBar(
          showBack: true,
          customTitle: _appTr('settings_privacy_security', fallback: 'Quyền riêng tư & bảo mật'),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      item(
                        icon: Icons.location_on_rounded,
                        title: _appTr('privacy_location_data_title', fallback: 'Dữ liệu vị trí'),
                        subtitle: _appTr('privacy_location_data_sub', fallback: 'Chỉ chia sẻ vị trí khi có cảnh báo bất thường'),
                      ),
                      item(
                        icon: Icons.videocam_off_outlined,
                        title: _appTr('privacy_access_permissions_title', fallback: 'Quyền truy cập'),
                        subtitle: _appTr('privacy_access_permissions_sub', fallback: 'Camera / Microphone (không sử dụng)'),
                      ),
                      item(
                        icon: Icons.home_work_outlined,
                        title: _appTr('privacy_backup_restore_title', fallback: 'Sao lưu & khôi phục'),
                        subtitle: _appTr('privacy_backup_restore_sub', fallback: 'Đồng bộ an toàn cấu hình giám sát trên đám mây'),
                      ),
                      item(
                        icon: Icons.delete_outline_rounded,
                        title: _appTr('privacy_delete_account_title', fallback: 'Xóa tài khoản'),
                        subtitle: _appTr('privacy_delete_account_sub', fallback: 'Xóa dữ liệu cá nhân'),
                        divider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined, color: AppColors.primaryDark, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _appTr('monitored_privacy_pledge'),
                          style: const TextStyle(
                            fontSize: 12.2,
                            color: AppColors.primaryDark,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 8. Settings Screen (Matches screen_settings.png)
  Widget _buildRealSettingsScreen() {
    final currentLangMeta = _i18n.currentMeta;
    Widget menuRow({
      required IconData icon,
      required String label,
      String? subtitle,
      bool divider = true,
    }) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12.5),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
          if (divider)
            const Divider(height: 1, indent: 54, endIndent: 18, color: Color(0xFFEEF1EE)),
        ],
      );
    }

    return Column(
      children: [
        _buildRealAppTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _appTr('settings_title', fallback: 'Cài đặt & Tài khoản'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      menuRow(
                        icon: Icons.person_outline_rounded,
                        label: _appTr('settings_personal_info', fallback: 'Thông tin cá nhân'),
                      ),
                      menuRow(
                        icon: Icons.people_outline_rounded,
                        label: _appTr('settings_relatives_authorization', fallback: 'Người thân & ủy quyền'),
                      ),
                      menuRow(
                        icon: Icons.access_time_rounded,
                        label: _appTr('settings_monitoring_reminders', fallback: 'Giám sát & nhắc nhở'),
                      ),
                      menuRow(
                        icon: Icons.smartphone_rounded,
                        label: _appTr('settings_devices_menu', fallback: 'Thiết bị'),
                      ),
                      menuRow(
                        icon: Icons.shield_outlined,
                        label: _appTr('settings_privacy_security', fallback: 'Quyền riêng tư & bảo mật'),
                      ),
                      menuRow(
                        icon: Icons.notifications_none_rounded,
                        label: _appTr('settings_notifications_menu', fallback: 'Cài đặt thông báo'),
                      ),
                      menuRow(
                        icon: Icons.language_rounded,
                        label: _appTr('settings_language_label', fallback: 'Ngôn ngữ / Language'),
                        subtitle: '${currentLangMeta.flag} ${currentLangMeta.nativeName}',
                        divider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        _appTr('settings_logout', fallback: 'Đăng xuất'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 17),
                    const SizedBox(width: 6),
                    Text(
                      _appTr('settings_delete_account', fallback: 'Xóa tài khoản'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _buildRealAppBottomNav(3),
      ],
    );
  }

  // ===========================================================================
  // 3. DARK ESPRESSO PRIVACY MANIFESTO STRIP
  // ===========================================================================
  Widget _buildManifestoStrip() {
    final items = [
      (
        '01',
        _tr('i111', 'Không Camera, Không Micro, Không GPS nền'),
        _tr('i112', 'Tuyệt đối không ghi âm, không quay hình và không theo dõi toạ độ chạy nền liên tục.'),
      ),
      (
        '02',
        _tr('i117', 'Tách biệt Heartbeat (0.0) và Hành vi thật'),
        _tr('i118', 'Tín hiệu mạng kỹ thuật không bao giờ tự gia hạn giả bộ đếm an toàn của con người.'),
      ),
      (
        '03',
        _tr('i113', 'Cô lập theo mối quan hệ giám hộ hai chiều'),
        _tr('i114', 'Chỉ người thân được bạn chấp thuận qua mã QR 48h mới xem được trạng thái an toàn.'),
      ),
    ];

    return Container(
      color: _espresso,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Wrap(
            spacing: 28,
            runSpacing: 20,
            alignment: WrapAlignment.spaceBetween,
            children: items
                .map(
                  (it) => SizedBox(
                    width: 356,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _terra.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            it.$1,
                            style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                it.$3,
                                style: const TextStyle(
                                  color: Color(0xFFA8A29E),
                                  fontSize: 13.2,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. DUAL-ROLE SIDE-BY-SIDE COMPARISON PANELS (#roles)
  // ===========================================================================
  Widget _buildDualRoleComparisonSection() {
    final isWide = MediaQuery.of(context).size.width >= 980;

    final monitoredPanel = _buildRolePanel(
      tag: _tr('role.monitored.tag', 'Chế độ Người được bảo vệ'),
      tagColor: _terra,
      bgGradient: const [Color(0xFFFFFDFB), _terraBg],
      borderColor: _terraBorder,
      title: _tr('i043', 'Chế độ Người được bảo vệ'),
      subtitle: _tr(
        'i044',
        'Giao diện tối giản, chữ lớn, màu sắc êm dịu dành cho người sống một mình hoặc người lớn tuổi.',
      ),
      ticks: [
        _tr('i023', 'Nút “Tôi vẫn ổn” (trọng số 1.0) kèm tín hiệu mở khoá máy, cắm sạc, bước chân (0.2–0.8).'),
        _tr('i029', 'Tự động đóng băng đồng hồ trong khung giờ ngủ ban đêm (Quiet Hours).'),
      ],
      assetPath: 'assets/images/screen_monitored_home.png',
    );

    final guardianPanel = _buildRolePanel(
      tag: _tr('role.guardian.tag', 'Chế độ Người bảo vệ'),
      tagColor: _sage,
      bgGradient: const [Color(0xFFFBFEFC), _sageSoft],
      borderColor: _sageBorder,
      title: _tr('i045', 'Chế độ Người giám hộ'),
      subtitle: _tr(
        'i046',
        'Bảng điều khiển trực quan giúp con cái, người thân ở xa nắm bắt trạng thái bình an và phối hợp xử lý sự cố.',
      ),
      ticks: [
        _tr('i064', 'Theo dõi trạng thái an toàn, hạn điểm danh tiếp theo và điểm ưu tiên vận hành 0–100.'),
        _tr('show3.t2', 'Quy trình xử lý sự cố minh bạch: Tiếp nhận (Acknowledge) → Giải quyết (Resolve) kèm ghi chú.'),
        _tr('show3.t3', 'Nhận cảnh báo đồng thời qua thông báo đẩy FCM, tin nhắn SMS và Telegram.'),
      ],
      assetPath: 'assets/images/screen_guardian_dashboard.png',
    );

    return Container(
      key: _rolesKey,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionSplitHeader(
                kicker: _tr('i040', 'Thiết kế Điềm tĩnh (Calm UX)'),
                title: _tr('i041', 'Một ứng dụng, hai góc nhìn tối ưu cho từng vai trò trong gia đình'),
                subtitle: _tr(
                  'i042',
                  'Chuyển đổi linh hoạt giữa chế độ Người được bảo vệ và Người giám hộ ngay trên thanh điều hướng mà không cần đăng nhập lại.',
                ),
              ),
              const SizedBox(height: 36),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: monitoredPanel),
                    const SizedBox(width: 24),
                    Expanded(child: guardianPanel),
                  ],
                )
              else
                Column(
                  children: [
                    monitoredPanel,
                    const SizedBox(height: 24),
                    guardianPanel,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRolePanel({
    required String tag,
    required Color tagColor,
    required List<Color> bgGradient,
    required Color borderColor,
    required String title,
    required String subtitle,
    required List<String> ticks,
    required String assetPath,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _espresso,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 15, color: _ink2, height: 1.55),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 270),
                child: Column(
                  children: ticks
                      .map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 8, color: tagColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t,
                                  style: const TextStyle(fontSize: 14, color: _ink, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildDeviceFrame(width: 175, height: 364, assetPath: assetPath),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. ASYMMETRIC BENTO GRID FEATURES (#features)
  // ===========================================================================
  Widget _buildBentoFeaturesSection() {
    final isWide = MediaQuery.of(context).size.width >= 980;

    final card1 = _bentoCard(
      badge: '01',
      title: _tr('i022', 'Điểm danh “Tôi vẫn ổn” & Tín hiệu thụ động'),
      body: _tr(
        'i023',
        'Chạm nhẹ nút “Tôi vẫn ổn” (trọng số 1.0) để đặt lại chu kỳ an toàn, hoặc để ứng dụng tự ghi nhận thao tác mở khoá màn hình, cắm sạc, bước chân (trọng số 0.2–0.8).',
      ),
      dark: false,
    );

    final card2 = _bentoCard(
      badge: '02',
      title: _tr('i024', 'Ghi nhận tín hiệu sinh hoạt thụ động'),
      body: _tr(
        'i025',
        'Tự động ghi nhận mở khoá màn hình, cắm sạc pin và chuyển động bước chân (trọng số 0.2–0.8) giúp gia đình an tâm mà không làm phiền người lớn tuổi.',
      ),
      dark: true,
    );

    final bottomCards = [
      _bentoCard(
        badge: '03',
        title: _tr('i026', 'Máy trạng thái 8 bước & Điểm rủi ro 0–100'),
        body: _tr(
          'i027',
          'Vòng đời giám sát chặt chẽ từ ACTIVE, CHECK_IN_REQUIRED, GRACE_PERIOD đến ALERT_TRIGGERED, ACKNOWLEDGED và RESOLVED.',
        ),
        dark: false,
      ),
      _bentoCard(
        badge: '04',
        title: _tr('i028', 'Khung giờ yên tĩnh (Quiet Hours) & Tạm dừng'),
        body: _tr(
          'i029',
          'Tự động đóng băng đồng hồ đếm ngược trong khung giờ ngủ ban đêm (ví dụ 22:00 – 07:00) theo đúng múi giờ từng người.',
        ),
        dark: false,
      ),
      _bentoCard(
        badge: '05',
        title: _tr('i032', 'Vị trí một lần khi có sự đồng ý'),
        body: _tr(
          'i033',
          'Tuyệt đối không theo dõi GPS chạy nền. Tọa độ vị trí chỉ được gửi một lần duy nhất khi chính bạn bấm Check-in hoặc khi xảy ra sự cố khẩn cấp.',
        ),
        dark: false,
      ),
    ];

    return Container(
      key: _featuresKey,
      decoration: const BoxDecoration(
        color: _sand,
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionSplitHeader(
                kicker: _tr('i019', 'Tính năng cốt lõi'),
                title: _tr('i020', 'Chỉ những gì thật sự cần thiết để giữ an toàn cho người thương'),
                subtitle: _tr(
                  'i021',
                  'Evernear không nhồi nhét các tính năng ngoài lề. Mọi thành phần đều xoay quanh việc phát hiện sớm bất thường và giảm thiểu báo động giả.',
                ),
              ),
              const SizedBox(height: 36),
              if (isWide) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: card1),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: card2),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: bottomCards[0]),
                    const SizedBox(width: 20),
                    Expanded(child: bottomCards[1]),
                    const SizedBox(width: 20),
                    Expanded(child: bottomCards[2]),
                  ],
                ),
              ] else ...[
                card1,
                const SizedBox(height: 16),
                card2,
                const SizedBox(height: 16),
                ...bottomCards.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: c,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bentoCard({
    required String badge,
    required String title,
    required String body,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: dark ? _espresso : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dark ? _espresso : _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: dark ? _terra : _terraBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: dark ? Colors.white : _terra,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : _espresso,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14.5,
              color: dark ? const Color(0xFFD6D3D1) : _ink2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. 3-STEP PROTECTION TIMELINE (#how)
  // ===========================================================================
  Widget _buildTimelineStepsSection() {
    final isWide = MediaQuery.of(context).size.width >= 980;
    final steps = [
      (
        _tr('step1.badge', 'Bước 01'),
        _terra,
        _tr('i079', 'Tạo tài khoản'),
        _tr('i080', 'Đăng ký nhanh bằng email và mật khẩu. Chọn vai trò Người được bảo vệ hoặc Người giám hộ.'),
      ),
      (
        _tr('step2.badge', 'Bước 02'),
        _sage,
        _tr('i081', 'Ghép đôi bằng mã QR 48h'),
        _tr('i082', 'Tạo lời mời kèm mã QR hoặc mã 6 ký tự có hiệu lực 48 giờ để liên kết hai chiều giữa người thân và người giám hộ.'),
      ),
      (
        _tr('step3.badge', 'Bước 03'),
        _espresso,
        _tr('i083', 'Đặt ngưỡng & Giờ yên tĩnh'),
        _tr('i084', 'Chọn chu kỳ kiểm tra, thời gian ân hạn (Grace Period), khung giờ ngủ ban đêm và các kênh nhận cảnh báo (FCM, SMS, Telegram).'),
      ),
    ];

    Widget buildStepCard((String, Color, String, String) s) {
      return Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: s.$2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _terraBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.$1,
                style: const TextStyle(
                  color: _terra,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.$3,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _espresso,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.$4,
              style: const TextStyle(fontSize: 14.2, color: _ink2, height: 1.55),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionSplitHeader(
                kicker: _tr('i077', 'Bắt đầu thế nào'),
                title: _tr('i078', 'Ba bước thiết lập vòng bảo vệ cho người thân'),
              ),
              const SizedBox(height: 32),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildStepCard(steps[0])),
                    const SizedBox(width: 22),
                    Expanded(child: buildStepCard(steps[1])),
                    const SizedBox(width: 22),
                    Expanded(child: buildStepCard(steps[2])),
                  ],
                )
              else
                Column(
                  children: steps
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: buildStepCard(s),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 7. CLANIFY-STYLE 8 FREESTANDING PHONES (#screens)
  // ===========================================================================
  Widget _buildCuratedScreensSection() {
    final isWide = MediaQuery.of(context).size.width >= 980;
    final shots = [
      (
        'assets/images/screen_monitored_home.png',
        _tr('i061', 'Điểm danh một chạm'),
        _tr('i062', 'Vòng hào quang an toàn và nút “Tôi vẫn ổn” nổi bật ở chính giữa màn hình.'),
      ),
      (
        'assets/images/screen_guardian_dashboard.png',
        _tr('i063', 'Tổng quan người thân'),
        _tr('i064', 'Biết ngay ai đang an toàn, ai sắp đến hạn điểm danh và điểm rủi ro vận hành.'),
      ),
      (
        'assets/images/screen_incidents.png',
        _tr('shot6.title', 'Thông báo & Sự kiện'),
        _tr('shot6.desc', 'Theo dõi toàn bộ lịch sử điểm danh và cảnh báo theo thời gian thực.'),
      ),
      (
        'assets/images/screen_check_in_detail.png',
        _tr('shot5.title', 'Xác nhận Điểm danh'),
        _tr('shot5.desc', 'Ghi chú trạng thái nhanh, cảm xúc và chia sẻ vị trí một lần khi bạn muốn.'),
      ),
      (
        'assets/images/screen_qr_invite.png',
        _tr('i065', 'Ghép đôi bằng mã QR'),
        _tr('i066', 'Quét mã QR hoặc nhập mã 6 ký tự có hạn 48 giờ để kết nối an toàn.'),
      ),
      (
        'assets/images/screen_monitoring_settings.png',
        _tr('i067', 'Giờ ngủ yên tĩnh'),
        _tr('i068', 'Không bao giờ đánh thức người thân lúc nửa đêm nhờ lịch trình theo múi giờ chuẩn.'),
      ),
      (
        'assets/images/screen_privacy_security.png',
        _tr('shot7.title', 'Quyền riêng tư & Bảo mật'),
        _tr('shot7.desc', 'Không camera, không micro, không theo dõi GPS chạy nền liên tục.'),
      ),
      (
        'assets/images/screen_settings.png',
        _tr('shot8.title', 'Cài đặt cá nhân hóa'),
        _tr('shot8.desc', 'Quản lý ngôn ngữ (36 thứ tiếng), giao diện Sáng/Tối và kênh liên hệ dự phòng.'),
      ),
    ];

    Widget buildShotItem((String, String, String) s) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _buildDeviceFrame(
              width: 226,
              height: 472,
              assetPath: s.$1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, left: 6, right: 6),
            child: Column(
              children: [
                Text(
                  s.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: _espresso,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.$3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.2,
                    color: _ink2,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      key: _screensKey,
      decoration: const BoxDecoration(
        color: _sand,
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 84, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _tr('i058', 'Giao diện trực quan').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: _terra,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _tr('i059', 'Rõ ràng, ấm áp và không gây lo âu'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: isWide ? 40 : 30,
                        fontWeight: FontWeight.w600,
                        height: 1.12,
                        letterSpacing: -0.8,
                        color: _espresso,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _tr(
                        'i060',
                        'Mọi màn hình trong Evernear đều tuân thủ triết lý Calm UX: không dùng màu sắc gây hoảng loạn khi chưa cần thiết, chữ dễ đọc và thao tác một chạm.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17.5,
                        color: _ink2,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 52),
              if (isWide) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildShotItem(shots[0])),
                    const SizedBox(width: 26),
                    Expanded(child: buildShotItem(shots[1])),
                    const SizedBox(width: 26),
                    Expanded(child: buildShotItem(shots[2])),
                    const SizedBox(width: 26),
                    Expanded(child: buildShotItem(shots[3])),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildShotItem(shots[4])),
                    const SizedBox(width: 26),
                    Expanded(child: buildShotItem(shots[5])),
                    const SizedBox(width: 26),
                    Expanded(child: buildShotItem(shots[6])),
                    const SizedBox(width: 26),
                    Expanded(child: buildShotItem(shots[7])),
                  ],
                ),
              ] else
                Wrap(
                  spacing: 26,
                  runSpacing: 48,
                  alignment: WrapAlignment.center,
                  children: shots
                      .map(
                        (s) => SizedBox(
                          width: 248,
                          child: buildShotItem(s),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 8. TWO-COLUMN SPLIT: SECURITY ARCHITECTURE (LEFT) + FAQ (RIGHT)
  // ===========================================================================
  Widget _buildSecurityAndFaqSplitSection() {
    final isWide = MediaQuery.of(context).size.width >= 980;

    final secRows = [
      (
        _tr('i115', 'Vị trí một lần có điều kiện'),
        _tr('i116', 'Toạ độ vị trí chỉ được lấy một lần duy nhất khi có sự đồng ý của bạn lúc bấm Check-in hoặc khi cảnh báo khẩn cấp được kích hoạt.'),
      ),
      (
        _tr('i119', 'Mã hoá TLS & Mật khẩu băm bcrypt'),
        _tr('i120', 'Toàn bộ kết nối REST API và kênh thời gian thực WebSocket đều đi qua TLS mã hoá. Mật khẩu người dùng được băm một chiều bằng bcrypt.'),
      ),
      (
        _tr('i121', 'Quyền được lãng quên & Xoá tức thì'),
        _tr('i122', 'Tuân thủ chuẩn GDPR: bạn có thể xuất dữ liệu cá nhân hoặc xoá vĩnh viễn toàn bộ tài khoản, lịch sử tín hiệu và sự cố ngay trong ứng dụng (DELETE /api/v1/users/me).'),
      ),
    ];

    final faqs = [
      (
        _tr('i125', 'Vì sao tín hiệu Heartbeat của điện thoại có trọng số 0.0?'),
        _tr('i126', 'Một chiếc điện thoại còn pin và còn kết nối mạng nằm trên bàn không chứng minh được chủ nhân của nó đang an toàn. Vì vậy, Evernear tách biệt hoàn toàn tín hiệu mạng kỹ thuật (Heartbeat = 0.0) khỏi các tương tác sinh hoạt thật của con người (0.2–0.8) và nút bấm “Tôi vẫn ổn” (1.0).'),
      ),
      (
        _tr('i127', 'Ứng dụng có làm phiền người lớn tuổi vào ban đêm không?'),
        _tr('i128', 'Không. Với tính năng Khung giờ yên tĩnh (Quiet Hours / Sleep Windows), đồng hồ đếm ngược trên máy chủ sẽ tự động đóng băng trong suốt giờ ngủ ban đêm (ví dụ từ 22:00 đến 07:00 sáng hôm sau theo đúng múi giờ của người dùng).'),
      ),
      (
        _tr('i129', 'Định vị vị trí hoạt động như thế nào? Có theo dõi liên tục không?'),
        _tr('i130', 'Evernear tuyệt đối không theo dõi GPS chạy nền liên tục. Vị trí chỉ được lấy một lần duy nhất (single-shot) khi bạn cấp quyền và chủ động bấm Check-in hoặc khi có sự cố khẩn cấp.'),
      ),
      (
        _tr('i131', 'Điểm rủi ro (Composite Risk Score 0–100) có phải là chẩn đoán y tế không?'),
        _tr('i132', 'Hoàn toàn không. Điểm rủi ro từ 0 đến 100 trong Evernear chỉ là chỉ số ưu tiên vận hành (Operational Prioritization) dựa trên độ trễ check-in và lịch sử tín hiệu. Evernear không phải thiết bị y tế.'),
      ),
      (
        _tr('i133', 'Làm sao để xoá sạch tài khoản và toàn bộ dữ liệu cá nhân?'),
        _tr('i134', 'Bạn có thể tự xóa vĩnh viễn tài khoản và toàn bộ dữ liệu bất cứ lúc nào ngay trong ứng dụng Evernear (Cài đặt → Xóa tài khoản) hoặc gửi yêu cầu tại /delete-account.'),
      ),
    ];

    final leftCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionSplitHeader(
          kicker: _tr('i109', 'Kiến trúc bảo mật & Quyền riêng tư'),
          title: _tr('i110', 'An toàn cho người thân, nhưng dữ liệu phải thuộc về riêng bạn'),
        ),
        const SizedBox(height: 24),
        ...secRows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _sage,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.$1,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _espresso),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.$2,
                  style: const TextStyle(fontSize: 14, color: _ink2, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final rightCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionSplitHeader(
          kicker: _tr('i123', 'Câu hỏi thường gặp'),
          title: _tr('i124', 'Trước khi bắt đầu'),
        ),
        const SizedBox(height: 24),
        ...faqs.map(
          (f) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                f.$1,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _espresso),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  f.$2,
                  style: const TextStyle(fontSize: 14, color: _ink2, height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Container(
      key: _securityKey,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftCol),
                    const SizedBox(width: 40),
                    Expanded(child: rightCol),
                  ],
                )
              : Column(
                  children: [
                    leftCol,
                    const SizedBox(height: 40),
                    rightCol,
                  ],
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 9. FINAL CTA BANNER & DARK ESPRESSO FOOTER
  // ===========================================================================
  Widget _buildFinalCtaSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 38),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_espresso, Color(0xFF2C221E), _terraDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: _espresso.withValues(alpha: 0.22),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 20,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr('i135', 'An tâm hơn cho bạn, tự do hơn cho người thương'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr('i136', 'Tạo tài khoản, ghép đôi qua mã QR 48 giờ và thiết lập khung giờ yên tĩnh chỉ trong vài phút.'),
                        style: const TextStyle(fontSize: 15, color: Color(0xFFD6D3D1)),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _terra,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _tr('i137', 'Bắt đầu ngay'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _goToApp(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _tr('i138', 'Tôi đã có tài khoản'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LEGAL PAGES: PRIVACY (/privacy), TERMS (/terms), DELETE ACCOUNT (/delete-account)
  // ===========================================================================
  Widget _buildPrivacyBody(BuildContext context) {
    return _legalContainer(
      context: context,
      title: _tr('p006', 'Chính sách bảo mật'),
      updated: _tr('p007', 'Áp dụng cho ứng dụng di động Evernear và bản web Evernear. Cập nhật lần cuối: ngày 15 tháng 10 năm 2026.'),
      intro: _tr('p008', 'Evernear là ứng dụng theo dõi bất động (Inactivity Monitor) và điểm danh an toàn cho người sống một mình hoặc người lớn tuổi. Chúng tôi xây dựng Evernear dựa trên nguyên tắc Bảo mật mặc định (Privacy-by-Default): không camera giám sát, không micro, không theo dõi GPS chạy nền liên tục.'),
      sections: [
        ('1. ${_tr('p021', 'Chúng tôi thu thập gì')}', [
          '${_tr('p022', 'Tài khoản và hồ sơ')}: ${_tr('p023', 'Địa chỉ email, mật khẩu đã băm một chiều bằng bcrypt (chúng tôi không bao giờ lưu mật khẩu gốc), tên hiển thị, số điện thoại khẩn cấp (nếu bạn cung cấp), ngôn ngữ giao diện, múi giờ IANA và vai trò sử dụng (Người được bảo vệ / Người giám hộ).')}',
          '${_tr('p024', 'Tín hiệu điểm danh và Hoạt động thụ động')}: ${_tr('p025', 'Ghi nhận các lần bấm nút “Tôi vẫn ổn” (trọng số 1.0) và các tín hiệu sinh hoạt thụ động (mở khoá màn hình, cắm sạc pin, bước chân — trọng số 0.2 đến 0.8). Tín hiệu kỹ thuật Heartbeat của thiết bị (trọng số 0.0) chỉ ghi nhận kết nối và mức pin để chẩn đoán kỹ thuật.')}',
          '${_tr('p026', 'Vị trí (Chỉ lấy một lần khi có sự đồng ý)')}: ${_tr('p027', 'Evernear tuyệt đối không theo dõi GPS chạy nền liên tục. Ứng dụng chỉ lấy toạ độ vị trí một lần duy nhất (single-shot) khi bạn đã cấp quyền và chủ động bấm Check-in hoặc khi xảy ra sự cố khẩn cấp (ALERT_TRIGGERED) để giúp Người giám hộ trong gia đình biết vị trí hỗ trợ.')}',
          '${_tr('p028', 'Thông tin thiết bị & thông báo đẩy:')} ${_tr('p029', 'Mã thông báo đẩy (APNs / FCM Push Token), hệ điều hành, phiên bản ứng dụng và địa chỉ nhận cảnh báo (SMS / Telegram) do bạn cấu hình.')}',
        ]),
        ('2. ${_tr('p_perm_title', 'Quyền truy cập thiết bị trên iOS & Android (Purpose Strings)')}', [
          _tr('p_perm_camera', 'Camera (NSCameraUsageDescription): Chỉ sử dụng khi bạn chủ động mở màn hình quét mã QR 48 giờ để ghép đôi với người thân. Evernear tuyệt đối không chụp ảnh, không quay video, không nhận diện khuôn mặt và không lưu trữ hay tải hình ảnh/video lên máy chủ. Bạn có thể nhập mã mời 6 ký tự thủ công mà không cần cấp quyền Camera.'),
          _tr('p_perm_location', 'Vị trí khi sử dụng (NSLocationWhenInUseUsageDescription): Chỉ truy cập toạ độ GPS một lần (single-shot) khi bạn bấm Check-in hoặc khi phát cảnh báo quá hạn. Bạn vẫn có thể sử dụng tính năng điểm danh bình thường ngay cả khi tắt quyền vị trí.'),
          _tr('p_perm_motion', 'Chuyển động & Thể chất (NSMotionUsageDescription): Chỉ đọc trạng thái chuyển động và bước chân thiết bị để ghi nhận tín hiệu sinh hoạt thụ động (trọng số 0.2–0.8), không thu thập dữ liệu sinh trắc học hay hồ sơ y tế.'),
          _tr('p_perm_notif', 'Thông báo đẩy (APNs / FCM): Dùng để gửi lời nhắc điểm danh trong thời gian ân hạn (Grace Period) và thông báo sự cố tới Người giám hộ.'),
        ]),
        ('3. ${_tr('p052', 'Vì sao chúng tôi dùng dữ liệu của bạn & Cam kết Không theo dõi')}', [
          _tr('p053', 'Để vận hành máy trạng thái an toàn 8 bước — đánh giá đúng hạn check-in, thời gian ân hạn (Grace Period) và đóng băng đồng hồ trong Khung giờ yên tĩnh (Quiet Hours).'),
          _tr('p054', 'Để gửi nhắc nhở và cảnh báo đa kênh — gửi thông báo đẩy APNs/FCM, SMS hoặc Telegram tới Người giám hộ khi quá hạn phản hồi.'),
          _tr('p055', 'Tính toán Điểm Rủi ro Ưu tiên Vận hành (0–100) — giúp Người giám hộ biết mức độ ưu tiên phản hồi (phi y tế, không chẩn đoán bệnh).'),
          _tr('p058', 'Chúng tôi không bao giờ bán dữ liệu cá nhân của bạn, không hiển thị quảng cáo, không sử dụng SDK theo dõi của bên thứ ba và không theo dõi người dùng xuyên ứng dụng (NSPrivacyTracking = false theo chuẩn App Tracking Transparency).'),
        ]),
        ('4. ${_tr('p059', 'Ai có thể nhận dữ liệu của bạn & Dịch vụ hạ tầng')}', [
          _tr('p060', 'Người bảo vệ được bạn phê duyệt — chỉ những người đã hoàn tất ghép đôi hai chiều qua mã mời QR 48 giờ mới thấy trạng thái an toàn và nhận cảnh báo của bạn.'),
          _tr('p061', 'Hạ tầng kỹ thuật thiết yếu — dịch vụ gửi thông báo đẩy (Apple Push Notification service / Firebase Cloud Messaging) và cổng tin nhắn SMS / Telegram để chuyển phát cảnh báo khẩn cấp.'),
        ]),
        ('5. ${_tr('p072', 'Lưu trữ, Thời hạn lưu giữ và Bảo mật')}', [
          _tr('p073', 'Mọi giao tiếp giữa ứng dụng di động, trình duyệt web và máy chủ đều được mã hoá qua HTTPS / TLS (WSS cho WebSocket).'),
          _tr('p074', 'Mật khẩu được băm bằng thuật toán bcrypt; phiên đăng nhập sử dụng JWT Access Token ngắn hạn kết hợp Refresh Token xoay vòng.'),
          _tr('p075', 'Thông tin tài khoản và cấu hình giám sát được lưu giữ trong suốt thời gian bạn duy trì tài khoản Evernear. Khi bạn xoá tài khoản, toàn bộ dữ liệu định danh cá nhân, thiết bị, tín hiệu hoạt động, check-in, vị trí và sự cố sẽ bị xoá và ẩn danh hoá vĩnh viễn ngay lập tức.'),
        ]),
        ('6. ${_tr('p076', 'Quyền của bạn (GDPR, CCPA & Bảo vệ dữ liệu cá nhân)')}', [
          _tr('p077', 'Theo GDPR và các quy định bảo vệ dữ liệu hiện hành, bạn có toàn quyền xem, chỉnh sửa hồ sơ, tạm dừng giám sát, xuất dữ liệu cá nhân (GET /api/v1/users/me/export), thu hồi quyền giám hộ hoặc xoá vĩnh viễn tài khoản bất cứ lúc nào. Mọi yêu cầu hỗ trợ xin gửi về support@erai.vn.'),
        ]),
        ('7. ${_tr('p078', 'Xoá tài khoản và dữ liệu của bạn')}', [
          _tr('p079', 'Bạn có thể tự xóa vĩnh viễn tài khoản và toàn bộ dữ liệu cá nhân bất cứ lúc nào trực tiếp ngay trong ứng dụng Evernear tại: Cài đặt (Settings) → Quyền riêng tư & bảo mật → Xóa tài khoản (Delete Account). Thao tác này gọi trực tiếp API DELETE /api/v1/users/me và có hiệu lực ngay lập tức.'),
          _tr('p080', 'Nếu bạn đã gỡ cài đặt ứng dụng, bạn có thể gửi yêu cầu tại trang Yêu cầu xoá tài khoản (/delete-account) hoặc gửi email tới support@erai.vn.'),
        ]),
        ('8. ${_tr('p_children_title', 'Quyền riêng tư của trẻ em & Thay đổi chính sách')}', [
          _tr('p_children_desc', 'Evernear là dịch vụ hỗ trợ an toàn gia đình dành cho người trưởng thành tự nguyện đăng ký hoặc có sự quản lý hợp pháp của người giám hộ trong gia đình. Chúng tôi không cố ý thu thập trái phép dữ liệu cá nhân của trẻ em dưới 13 tuổi.'),
          _tr('p091', 'Nếu chính sách này có thay đổi quan trọng, chúng tôi sẽ cập nhật ngày hiệu lực ở đầu trang và thông báo trong ứng dụng.'),
          _tr('p097', 'Mọi câu hỏi về quyền riêng tư và bảo vệ dữ liệu cá nhân, vui lòng liên hệ: support@erai.vn.'),
        ]),
      ],
    );
  }

  Widget _buildTermsBody(BuildContext context) {
    return _legalContainer(
      context: context,
      title: _tr('t006', 'Điều khoản dịch vụ'),
      updated: _tr('t007', 'Cập nhật lần cuối: ngày 15 tháng 10 năm 2026.'),
      intro: _tr('t008', 'Những điều khoản này là thoả thuận giữa bạn và Evernear. Khi tạo tài khoản, ghép đôi giám hộ hay sử dụng ứng dụng, bạn đồng ý với các điều khoản dưới đây.'),
      sections: [
        ('1. ${_tr('t025', 'Evernear là gì')}', [
          _tr('t026', 'Evernear là hệ thống theo dõi bất động (Inactivity Monitor) và điểm danh an toàn thụ động dành cho người sống một mình, người cao tuổi và người thân ở xa. Ứng dụng hỗ trợ điểm danh “Tôi vẫn ổn” (trọng số 1.0), ghi nhận tín hiệu sinh hoạt thụ động (0.2–0.8) và cảnh báo đa kênh tới Người giám hộ.'),
        ]),
        ('2. ${_tr('t028', 'Tài khoản và xác thực')}', [
          _tr('t029', 'Bạn có thể đăng ký và đăng nhập bằng địa chỉ email và mật khẩu bảo mật.'),
          _tr('t031', 'Bạn chịu trách nhiệm bảo mật thiết bị, thông tin đăng nhập và đảm bảo số điện thoại nhận cảnh báo của mình là chính xác.'),
        ]),
        ('3. ${_tr('t033', 'Ghép đôi và sự đồng thuận hai chiều')}', [
          _tr('t035', 'Mọi mối quan hệ giữa Người được bảo vệ và Người giám hộ trong Evernear đều dựa trên sự đồng thuận tự nguyện thông qua mã mời QR 48 giờ. Bạn tuyệt đối không được sử dụng Evernear để theo dõi bất kỳ cá nhân nào khi chưa có sự đồng ý rõ ràng của họ. Cả hai phía đều có quyền tạm dừng hoặc huỷ liên kết bất cứ lúc nào.'),
        ]),
        ('4. ${_tr('t038', 'Giới hạn về dịch vụ khẩn cấp (Không thay thế 113/114/115/911)')}', [
          _tr('t040', 'Evernear KHÔNG phải là dịch vụ cứu hộ hay cấp cứu khẩn cấp công cộng.'),
          _tr('t041', 'Tính năng cảnh báo quá hạn chỉ gửi thông báo tới những Người giám hộ trong gia đình bạn (qua FCM, SMS, Telegram). Ứng dụng không kết nối với cảnh sát, cứu hoả hay cấp cứu y tế (113, 114, 115, 911). Trong tình huống nguy hiểm tính mạng tức thời, vui lòng gọi trực tiếp cơ quan cấp cứu địa phương.'),
        ]),
        ('5. ${_tr('t045', 'Miễn trừ y tế (Phi chẩn đoán y khoa)')}', [
          _tr('t046', 'Evernear không phải thiết bị y tế và không đưa ra chẩn đoán y khoa.'),
          _tr('t047', 'Điểm rủi ro tổng hợp (Composite Risk Score 0–100) và trạng thái máy chủ chỉ là công cụ ưu tiên vận hành (Operational Prioritization) dựa trên độ trễ điểm danh, hoàn toàn không phản ánh tình trạng bệnh lý hay chẩn đoán sức khoẻ.'),
        ]),
        ('6. ${_tr('t_bg_title', 'Giới hạn hoạt động nền của Hệ điều hành & Kết nối viễn thông')}', [
          _tr('t_bg_desc', 'Mặc dù đồng hồ đếm ngược an toàn được vận hành độc lập trên máy chủ trung tâm (Server-Authoritative Clock), việc thu thập tín hiệu sinh hoạt thụ động dưới nền phụ thuộc vào cơ chế quản lý năng lượng của hệ điều hành (như iOS BGAppRefreshTask, Chế độ nguồn điện thấp / Low Power Mode). Ngoài ra, thông báo đẩy, SMS hoặc tọa độ vị trí có thể bị trễ nếu thiết bị hết pin, tắt nguồn, mất sóng viễn thông hoặc bị tắt quyền thông báo.'),
        ]),
        ('7. ${_tr('t051', 'Sử dụng hợp lệ')}', [
          _tr('t052', 'Bạn cam kết không sử dụng Evernear để xâm phạm đời tư người khác, không gửi báo động giả gây hoang mang, và không tìm cách truy cập trái phép vào hệ thống máy chủ hoặc dữ liệu của tài khoản khác.'),
        ]),
        ('8. ${_tr('t060', 'Chấm dứt và xoá tài khoản')}', [
          _tr('t061', 'Bạn có thể ngừng sử dụng Evernear và tự xoá vĩnh viễn tài khoản ngay lập tức trong mục Cài đặt của ứng dụng, hoặc gửi yêu cầu qua trang Yêu cầu xoá tài khoản (/delete-account).'),
        ]),
        ('9. ${_tr('t064', 'Giới hạn trách nhiệm')}', [
          _tr('t065', 'Trong phạm vi pháp luật cho phép, Evernear được cung cấp trên cơ sở “nguyên trạng” và không chịu trách nhiệm đối với các thiệt hại gián tiếp phát sinh từ việc thông báo bị trì hoãn do mất kết nối viễn thông, thiết bị tắt nguồn hoặc cài đặt thông báo của hệ điều hành.'),
        ]),
        ('10. ${_tr('t066', 'Luật áp dụng & liên hệ')}', [
          _tr('t069', 'Các điều khoản này được điều chỉnh bởi pháp luật Cộng hoà Xã hội Chủ nghĩa Việt Nam. Mọi câu hỏi xin liên hệ support@erai.vn.'),
        ]),
      ],
    );
  }

  Widget _buildDeleteAccountBody(BuildContext context) {
    return _legalContainer(
      context: context,
      title: _tr('d.h1', 'Yêu cầu xoá tài khoản Evernear'),
      updated: _tr('d.sub', 'Account and Personal Data Deletion Request (GDPR Right to Erasure)'),
      intro: _tr('d.inapp', 'Bạn đang cài ứng dụng Evernear? Bạn có thể tự xoá vĩnh viễn tài khoản ngay lập tức trực tiếp trong ứng dụng tại: Cài đặt (Settings) → Xoá tài khoản (Delete Account) (gọi trực tiếp DELETE /api/v1/users/me). Trang web này phục vụ trường hợp bạn không còn giữ ứng dụng hoặc thiết bị.'),
      sections: [
        (_tr('d.web.h2', 'Cách gửi yêu cầu xoá qua Web / Email'), [
          _tr('d.web.step1', '1. Gửi email từ chính địa chỉ email dùng để đăng nhập Evernear tới support@erai.vn.'),
          _tr('d.web.step2', '2. Tiêu đề ghi “Yêu cầu xoá tài khoản Evernear”, kèm theo tên hiển thị của bạn. Tuyệt đối không gửi mật khẩu hay token đăng nhập.'),
          _tr('d.web.step3', '3. Chúng tôi xác minh quyền sở hữu tài khoản qua email, thực hiện xoá vĩnh viễn và phản hồi xác nhận trong vòng tối đa 30 ngày.'),
          '${_tr('d.cta', 'Gửi email yêu cầu xoá tài khoản')}: support@erai.vn',
        ]),
        (_tr('d.what.h2', 'Dữ liệu sẽ bị xoá vĩnh viễn'), [
          _tr('d.what.p', 'Toàn bộ tài khoản, hồ sơ cá nhân, danh sách thiết bị đã đăng ký, cấu hình giám sát, khung giờ yên tĩnh, lịch sử điểm danh (Check-in), tín hiệu sinh hoạt thụ động, toạ độ vị trí một lần, lịch sử sự cố (Incidents), kênh thông báo và các mối quan hệ giám hộ.'),
        ]),
        (_tr('d.keep.h2', 'Dữ liệu có thể được giữ lại tạm thời'), [
          _tr('d.keep.p', 'Một phần nhật ký kiểm toán bảo mật tối thiểu (Audit Log đã ẩn danh) có thể được lưu giữ khi pháp luật bắt buộc nhằm chống gian lận và bảo vệ an toàn dịch vụ.'),
        ]),
      ],
    );
  }

  Widget _buildLegalPageContent(BuildContext context, SitePageType type) {
    switch (type) {
      case SitePageType.privacy:
        return _buildPrivacyBody(context);
      case SitePageType.terms:
        return _buildTermsBody(context);
      case SitePageType.deleteAccount:
        return _buildDeleteAccountBody(context);
      default:
        return _buildPrivacyBody(context);
    }
  }

  Widget _legalContainer({
    required BuildContext context,
    required String title,
    required String updated,
    required String intro,
    required List<(String, List<String>)> sections,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMtBanner(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(_tr('p005', 'Về trang chủ')),
                style: TextButton.styleFrom(
                  foregroundColor: _terra,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _espresso,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(updated, style: const TextStyle(fontSize: 13.5, color: _ink3)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _terraBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _terraBorder),
                ),
                child: Text(
                  intro,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _espresso,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...sections.map(
                (sec) => Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sec.$1,
                        style: const TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: _terraDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...sec.$2.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            p,
                            style: const TextStyle(fontSize: 14.5, color: _ink2, height: 1.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SHARED HELPERS & FOOTER
  // ===========================================================================
  Widget _sectionSplitHeader({
    required String kicker,
    required String title,
    String? subtitle,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _terra,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _espresso,
              height: 1.18,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 15.5, color: _ink2, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: _espresso,
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 48,
                runSpacing: 28,
                children: [
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Evernear',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _tr('i139', 'Hệ thống đồng hành an toàn thụ động & điểm danh bình yên cho người sống một mình và người thân ở xa — tôn trọng tuyệt đối quyền riêng tư.'),
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFFA8A29E), height: 1.55),
                        ),
                      ],
                    ),
                  ),
                  _footerCol(_tr('i140', 'Sản phẩm'), [
                    (_tr('nav.roles', 'Hai vai trò'), () => _navigateToSection('roles')),
                    (_tr('i141', 'Tính năng'), () => _navigateToSection('features')),
                    (_tr('i142', 'Giao diện'), () => _navigateToSection('screens')),
                    (_tr('i143', 'Đăng nhập'), () => Navigator.of(context).pushNamed('/login')),
                    (_tr('i144', 'Tạo tài khoản'), () => Navigator.of(context).pushNamed('/register')),
                  ]),
                  _footerCol(_tr('i145', 'Pháp lý & Bảo mật'), [
                    (_tr('i146', 'Chính sách bảo mật'), () => _navigateToLegalPage(SitePageType.privacy, '/privacy')),
                    (_tr('i147', 'Điều khoản dịch vụ'), () => _navigateToLegalPage(SitePageType.terms, '/terms')),
                    (_tr('i_del_page', 'Yêu cầu xoá tài khoản'), () => _navigateToLegalPage(SitePageType.deleteAccount, '/delete-account')),
                  ]),
                  _footerCol(_tr('i150', 'Liên hệ'), [
                    ('support@erai.vn', () {}),
                    (_tr('i151', 'Hỗ trợ & giải đáp trong 5 ngày làm việc'), () {}),
                  ]),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              Text(
                '© 2026 Evernear · ${_tr('i_disclaimer', 'Evernear là công cụ theo dõi bất động và thông báo nội bộ gia đình phi chẩn đoán y khoa, không thay thế cơ sở y tế hay dịch vụ cứu hộ khẩn cấp công cộng (113, 114, 115, 911).')}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF78716C)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerCol(String heading, List<(String, VoidCallback)> links) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF78716C),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...links.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: l.$2,
                child: Text(
                  l.$1,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFFD6D3D1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
