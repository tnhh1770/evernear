import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../demo/showcase_demo_mode.dart';

class ProductShowcaseScreen extends StatefulWidget {
  const ProductShowcaseScreen({super.key});

  @override
  State<ProductShowcaseScreen> createState() => _ProductShowcaseScreenState();
}

class _ProductShowcaseScreenState extends State<ProductShowcaseScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<ShowcaseSlideData> _getSlides(BuildContext context) => [
    ShowcaseSlideData(
      icon: Icons.cottage_outlined,
      accentColor: const Color(0xFF2E7D32),
      badgeText: context.tr('showcase_badge_1', fallback: 'SOLO LIVING PEACE OF MIND'),
      title: context.tr('showcase_title_1', fallback: 'Live Independently,\\nNever Truly Alone'),
      description: context.tr('showcase_desc_1',
          fallback: 'Carely quietly senses your natural daily rhythm through device unlocks and charging, without disrupting your routine or privacy.'),
      highlight: context.tr('showcase_highlight_1', fallback: 'Automatic 24/7 Safety'),
    ),
    ShowcaseSlideData(
      icon: Icons.volunteer_activism_outlined,
      accentColor: const Color(0xFF00796B),
      badgeText: context.tr('showcase_badge_2', fallback: 'FAMILY CARE'),
      title: context.tr('showcase_title_2', fallback: 'Parents Safe & Well,\\nChildren at Complete Ease'),
      description: context.tr('showcase_desc_2',
          fallback: 'Look after elderly parents remotely without intrusive cameras or overbearing surveillance.'),
      highlight: context.tr('showcase_highlight_2', fallback: 'Thoughtful Caring Connection'),
    ),
    ShowcaseSlideData(
      icon: Icons.lock_outline,
      accentColor: const Color(0xFF1B5E20),
      badgeText: context.tr('showcase_badge_3', fallback: 'PRIVACY FIRST'),
      title: context.tr('showcase_title_3', fallback: 'Respecting Privacy,\\nNo Cameras & No Mics'),
      description: context.tr('showcase_desc_3',
          fallback: 'No audio recording, no video feeds, no continuous GPS tracking. Location is only shared on check-in or emergency consent.'),
      highlight: context.tr('showcase_highlight_3', fallback: '100% Personal Data Security'),
    ),
    ShowcaseSlideData(
      icon: Icons.shield_outlined,
      accentColor: const Color(0xFFE65100),
      badgeText: context.tr('showcase_badge_4', fallback: 'AUTHORITATIVE RELIABILITY'),
      title: context.tr('showcase_title_4', fallback: 'Authoritative Server Clock,\\nUninterrupted Protection'),
      description: context.tr('showcase_desc_4',
          fallback: 'Even if the phone powers off or drops offline, Carely server deterministically evaluates timers and alerts guardians.'),
      highlight: context.tr('showcase_highlight_4', fallback: 'Immune to OS Background Killers'),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onExploreDemo() {
    ShowcaseDemoController().enableDemo();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _onGetStarted() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _getSlides(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('app_name', fallback: AppStrings.appName),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _onGetStarted,
                    child: Text(
                      context.tr('common_skip', fallback: 'Carely'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carousel Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Card with gentle gradient & illustration icon
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                slide.accentColor.withValues(alpha: 0.18),
                                slide.accentColor.withValues(alpha: 0.04),
                              ],
                            ),
                            border: Border.all(
                              color: slide.accentColor.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: slide.accentColor.withValues(alpha: 0.12),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              slide.icon,
                              size: 72,
                              color: slide.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: slide.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slide.badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: slide.accentColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Highlight pill
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 16, color: slide.accentColor),
                            const SizedBox(width: 6),
                            Text(
                              slide.highlight,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: slide.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _currentPage == slides.length - 1
                          ? _onGetStarted
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == slides.length - 1
                            ? context.tr('auth_login_now', fallback: 'Sign in now')
                            : context.tr('common_continue', fallback: 'Continue'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Demo CTA (Great for marketing viewers / pitches)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _onExploreDemo,
                      icon: const Icon(Icons.play_circle_outline, size: 20, color: AppColors.primary),
                      label: Text(
                        context.tr('showcase_demo_btn', fallback: 'Preview Interactive Demo'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ShowcaseSlideData {
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final String title;
  final String description;
  final String highlight;

  const ShowcaseSlideData({
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.title,
    required this.description,
    required this.highlight,
  });
}
