import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/services/web_landing_launcher.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../../core/widgets/language_selector.dart';
import 'auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      LocaleProvider? localeProvider;
      try {
        localeProvider = Provider.of<LocaleProvider>(
          context,
          listen: false,
        );
      } catch (_) {}

      if (localeProvider != null) {
        final activeLang = localeProvider.currentLanguageCode;
        final serverLang = auth.currentUser?.preferredLanguage;

        if (localeProvider.isDeviceDefault) {
          // If user has not chosen an explicit language, sync from backend profile
          if (serverLang != null && serverLang.isNotEmpty) {
            try {
              await localeProvider.syncFromUserProfile(serverLang);
            } catch (_) {}
          }
        } else {
          // Client chosen locale is authoritative!
          if (serverLang != activeLang) {
            auth.updateUserPreferredLanguage(activeLang);
            try {
              await localeProvider.syncCurrentLocaleToUser(auth);
            } catch (_) {}
          }
        }
      }

      if (!mounted) return;
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == '/login' || Navigator.of(context).canPop()) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (r) => false);
      }
    } else if (!success && mounted) {
      final errorMsg = auth.getErrorMessage(context) ?? auth.errorMessage;
      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.stateAlertTriggered,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _emailController.text.trim());
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              backgroundColor: const Color(0xFFFBFAF8),
              appBar: AppBar(
                title: Text(
                  ctx.tr('auth_forgot_password', fallback: 'Quên mật khẩu?'),
                ),
                elevation: 0,
              ),
              body: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 24),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          ctx.tr(
                            'auth_forgot_password_coming_soon',
                            fallback:
                                'Nhập email hoặc số điện thoại để nhận liên kết đặt lại mật khẩu.',
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: resetCtrl,
                          decoration: InputDecoration(
                            hintText: ctx.tr(
                              'auth_email_or_phone',
                              fallback: 'Email hoặc số điện thoại',
                            ),
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                ctx.tr('common_cancel', fallback: 'Hủy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.tr(
                                        'auth_forgot_password_coming_soon',
                                        fallback:
                                            'Đã gửi hướng dẫn khôi phục mật khẩu',
                                      ),
                                    ),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              },
                              child: Text(
                                ctx.tr('common_confirm', fallback: 'Gửi'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .whenComplete(() => resetCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      body: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4F0).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(80),
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 20),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26.0, 16.0, 26.0, 44.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top bar with brand landing link & language selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              key: const Key('login_back_to_landing_btn'),
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => WebLandingLauncher.openLanding(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const EvenearHeartLogo(size: 22),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.tr('app_name', fallback: 'Evenear'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF184A3E),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      WebLandingLauncher.isWeb
                                          ? Icons.home_outlined
                                          : Icons.open_in_new_rounded,
                                      size: 14,
                                      color: const Color(0xFF4A6B61),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const LanguageSelector(
                              key: Key('preauth_language_selector'),
                              dropdownKey: Key('login_language_dropdown'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Left-aligned Heading & Subtitle matching 03_login.png
                        Text(
                          context.tr('auth_welcome_back', fallback: 'Chào mừng trở lại!'),
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF184A3E),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('auth_login_subtitle', fallback: 'Đăng nhập để tiếp tục'),
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            color: Color(0xFF4A6B61),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email or Phone Input
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth_email_label',
                              fallback: 'Email',
                            ),
                            hintText: context.tr(
                              'auth_email_or_phone',
                              fallback: 'Email hoặc số điện thoại',
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFF4A6B61),
                              size: 21,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EAE5),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EAE5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E7D60),
                                width: 1.6,
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF2F5F1),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return context.tr(
                                'auth_email_hint',
                                fallback: 'Please enter your email',
                              );
                            }
                            if (!val.contains('@')) {
                              return context.tr(
                                'auth_email_invalid',
                                fallback: 'Invalid email address',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password Input
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'auth_password_label',
                              fallback: 'Mật khẩu',
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF4A6B61),
                              size: 21,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF5A766D),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EAE5),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EAE5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E7D60),
                                width: 1.6,
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF2F5F1),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return context.tr(
                                'auth_password_hint',
                                fallback: 'Please enter your password',
                              );
                            }
                            if (val.length < 6) {
                              return context.tr(
                                'auth_password_min_length',
                                fallback:
                                    'Password must be at least 6 characters',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Remember account & Forgot password row
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: const Color(0xFF246A52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      context.tr('auth_remember_me', fallback: 'Nhớ tài khoản'),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFF4A6B61),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                context.tr('auth_forgot_password', fallback: 'Quên mật khẩu?'),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D60),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Submit Button ("Đăng nhập")
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D60),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              elevation: 0,
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    context.tr(
                                      'auth_login_button',
                                      fallback: 'Đăng nhập',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Register link ("Chưa có tài khoản? Đăng ký")
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.tr(
                                'auth_no_account',
                                fallback: 'Chưa có tài khoản? ',
                              ),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF5A766D),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    context.tr('auth_register_title', fallback: 'Đăng ký'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF2E7D60),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Opacity(
                                    opacity: 0.0,
                                    child: Text(
                                      context.tr(
                                        'auth_register_now',
                                        fallback: 'Đăng ký ngay',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
