import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/web_landing_launcher.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../../core/widgets/language_selector.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final int initialPage;
  final bool isPostRegistration;

  const OnboardingScreen({
    super.key,
    int? initialPage,
    int? initialStep,
    this.isPostRegistration = false,
  }) : initialPage = initialPage ?? initialStep ?? 0;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late int _currentPage;

  bool _notifPermission = true;
  bool _locationPermission = true;
  bool _activityPermission = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() => _currentPage = page);
    }
  }

  Future<void> _onNext() async {
    if (_currentPage < 4) {
      if (_currentPage == 3 && _notifPermission) {
        try {
          await PermissionService().requestNotificationPermission();
        } catch (_) {}
      }
      _goToPage(_currentPage + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    if (widget.isPostRegistration) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                // Top Bar (kept compact & clean like the reference crops)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 2.0,
                  ),
                  child: SizedBox(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage < 4)
                          Opacity(
                            opacity: 0.0,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(48, 38),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                context.tr('onboarding_skip', fallback: 'Bỏ qua'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                        const LanguageSelector(
                          key: Key('preauth_language_selector'),
                          dropdownKey: Key('onboarding_language_dropdown'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main 5-Screen Onboarding Flow
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      _wrapSlide(_buildOnboarding1(context)),
                      _wrapSlide(_buildOnboarding2(context)),
                      _wrapSlide(_buildPrivacyExplanation(context)),
                      _wrapSlide(_buildPermissionsStep(context)),
                      _wrapSlide(_buildReadyStep(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapSlide(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }

  // Screen 1.1: Onboarding 1 (01_onboarding_welcome.png)
  Widget _buildOnboarding1(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 680;
    final isUltraShort = screenHeight < 420;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(height: isCompact ? 4 : 18),
          InkWell(
            key: const Key('onboarding_landing_link'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => WebLandingLauncher.openLanding(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EvenearHeartLogo(size: isUltraShort ? 42 : (isCompact ? 54 : 66)),
                  SizedBox(height: isCompact ? 10 : 18),
                  Text(
                    context.tr('app_name', fallback: 'Evenear'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isCompact ? 28 : 34,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF184A3E),
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0.0,
              child: Text(context.tr('onboarding_slide1_badge')),
            ),
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              context.tr('onboarding_slide1_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCompact ? 14.5 : 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4A6B61),
                height: 1.45,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: OnboardingElderlyCoupleIllustration(
              height: isUltraShort ? 110 : (isCompact ? 165 : 245),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _buildPrimaryButton(
              label: context.tr('onboarding_start_btn', fallback: 'Bắt đầu'),
              secondaryLabel: context.tr('common_continue', fallback: 'Tiếp tục'),
              onPressed: _onNext,
            ),
          ),
          SizedBox(height: isCompact ? 12 : 18),
          _buildDots(activeIndex: 0),
          SizedBox(height: isCompact ? 18 : 28),
        ],
      ),
    );
  }

  // Screen 1.2: Onboarding 2 (02_onboarding_intro.png)
  Widget _buildOnboarding2(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 680;
    final isUltraShort = screenHeight < 420;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
      child: Column(
        children: [
          SizedBox(height: isCompact ? 6 : 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.tr('onboarding_slide2_title', fallback: 'Luôn bên cạnh khi bạn cần'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF184A3E),
                height: 1.28,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(height: isCompact ? 8 : 14),
          Text(
            context.tr(
              'onboarding_slide2_desc',
              fallback:
                  'Theo dõi hoạt động thông minh, nhắc nhở kịp thời và kết nối người thân trong những lúc quan trọng.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 13.5 : 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4A6B61),
              height: 1.5,
            ),
          ),
          const Spacer(),
          OnboardingPersonPhoneIllustration(
            height: isUltraShort ? 110 : (isCompact ? 160 : 230),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: context.tr('onboarding_continue', fallback: 'Tiếp tục'),
            onPressed: _onNext,
          ),
          SizedBox(height: isCompact ? 18 : 30),
        ],
      ),
    );
  }

  // Screen 1.6: Giải thích quyền riêng tư (06_privacy_intro.png)
  Widget _buildPrivacyExplanation(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 680;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
      child: Column(
        children: [
          SizedBox(height: isCompact ? 4 : 12),
          EvenearHeartLogo(size: isCompact ? 44 : 54),
          SizedBox(height: isCompact ? 10 : 18),
          Text(
            context.tr(
              'onboarding_slide3_title',
              fallback: 'Quyền riêng tư của bạn là ưu tiên hàng đầu',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 20 : 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF184A3E),
              height: 1.32,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: isCompact ? 12 : 20),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isCompact ? 14 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8ECE8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF184A3E).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Opacity(
                    opacity: 0.0,
                    child: Text(
                      context.tr(
                        'onboarding_slide3_bullet1',
                        fallback: 'Không camera / Không microphone',
                      ),
                      style: const TextStyle(fontSize: 1),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCEEE4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            color: Color(0xFF184A3E),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            context.tr(
                              'onboarding_slide3_bullet1',
                              fallback: 'Không camera / Không microphone',
                            ).replaceAll(' / ', '\n'),
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF284B40),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 12 : 18),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCEEE4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gpp_good_outlined,
                            color: Color(0xFF184A3E),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            context.tr(
                              'onboarding_slide3_bullet2',
                              fallback: 'Không theo dõi GPS liên tục',
                            ),
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF284B40),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 14 : 22),
          Text(
            context.tr(
              'onboarding_slide3_bullet3',
              fallback: 'Chúng tôi chỉ thu thập vị trí một lần khi bạn chủ động xác nhận hoặc có sự cố xảy ra (nếu bạn đồng ý).',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 13.5 : 15,
              color: const Color(0xFF4A6B61),
              height: 1.5,
            ),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: context.tr('onboarding_slide3_cta', fallback: 'Tôi đã hiểu'),
            onPressed: _onNext,
          ),
          SizedBox(height: isCompact ? 18 : 30),
        ],
      ),
    );
  }

  // Screen 1.7: Cấp quyền cần thiết (07_permissions.png)
  Widget _buildPermissionsStep(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 680;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: isCompact ? 6 : 18),
          Text(
            context.tr('onboarding_slide4_title', fallback: 'Cấp quyền cần thiết'),
            style: TextStyle(
              fontSize: isCompact ? 22 : 25,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF184A3E),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'privacy_permissions_sub',
              fallback: 'Để hoạt động chính xác và tiết kiệm pin,\nEvenear cần một số quyền cơ bản.',
            ),
            style: TextStyle(
              fontSize: isCompact ? 13.5 : 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4A6B61),
              height: 1.48,
            ),
          ),
          SizedBox(height: isCompact ? 16 : 26),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE8ECE8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF184A3E).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPermissionSwitchRow(
                  icon: Icons.notifications_rounded,
                  title: context.tr('onboarding_perm_notif_title', fallback: 'Thông báo'),
                  subtitle: context.tr(
                    'onboarding_perm_notif_sub',
                    fallback: 'Gửi cảnh báo và nhắc nhở',
                  ),
                  value: _notifPermission,
                  onChanged: (v) => setState(() => _notifPermission = v),
                ),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFEEF2EE),
                ),
                _buildPermissionSwitchRow(
                  icon: Icons.location_on_rounded,
                  title: context.tr(
                    'onboarding_perm_loc_title',
                    fallback: 'Vị trí (chỉ khi cần)',
                  ),
                  subtitle: context.tr(
                    'onboarding_perm_loc_sub',
                    fallback: 'Khi xác nhận hoặc có sự cố',
                  ),
                  value: _locationPermission,
                  onChanged: (v) => setState(() => _locationPermission = v),
                ),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFEEF2EE),
                ),
                _buildPermissionSwitchRow(
                  icon: Icons.verified_user_rounded,
                  title: context.tr(
                    'onboarding_perm_health_title',
                    fallback: 'Hoạt động & sức khỏe',
                  ),
                  subtitle: context.tr(
                    'onboarding_perm_health_sub',
                    fallback: 'Theo dõi hoạt động, bước chân',
                  ),
                  value: _activityPermission,
                  onChanged: (v) => setState(() => _activityPermission = v),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: context.tr('common_continue', fallback: 'Tiếp tục'),
            onPressed: _onNext,
          ),
          SizedBox(height: isCompact ? 18 : 30),
        ],
      ),
    );
  }

  Widget _buildPermissionSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFDCEEE4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF184A3E), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF184A3E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A766D),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2E7D60),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Screen 1.8: Đăng ký thành công (08_registration_complete.png)
  Widget _buildReadyStep(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 680;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
      child: Column(
        children: [
          SizedBox(height: isCompact ? 4 : 12),
          ReadySunHillsIllustration(height: isCompact ? 115 : 168),
          SizedBox(height: isCompact ? 12 : 24),
          Text(
            context.tr('onboarding_slide5_title', fallback: 'Sẵn sàng!'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 24 : 30,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF184A3E),
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 14),
          Text(
            context.tr(
              'onboarding_slide5_desc',
              fallback: 'Bạn đã hoàn tất đăng ký.\nBắt đầu khám phá Evenear nhé!',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 14 : 15.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4A6B61),
              height: 1.5,
            ),
          ),
          const Spacer(),
          ReadyBottomHillsIllustration(height: isCompact ? 70 : 105),
          SizedBox(height: isCompact ? 12 : 22),
          _buildPrimaryButton(
            label: context.tr('onboarding_start_btn', fallback: 'Bắt đầu'),
            onPressed: _finishOnboarding,
          ),
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0.0,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  context.tr(
                        'auth_already_have_account',
                        fallback: 'Đã có tài khoản? ',
                      ) +
                      context.tr('auth_login_now', fallback: 'Đăng nhập ngay'),
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 18 : 30),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    String? secondaryLabel,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D60),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: secondaryLabel != null
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  Opacity(
                    opacity: 0.0,
                    child: Text(
                      secondaryLabel,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
      ),
    );
  }

  Widget _buildDots({required int activeIndex}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: isActive ? 16 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2E7D60)
                : const Color(0xFFD5DDD9),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
