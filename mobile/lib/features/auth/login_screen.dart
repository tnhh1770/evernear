import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_catalog_registry.dart';
import '../../core/i18n/locale_provider.dart';
import 'auth_provider.dart';
import 'register_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../demo/showcase_demo_mode.dart';
import '../onboarding/product_showcase_screen.dart';

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
      final preferredLang = auth.currentUser?.preferredLanguage;
      if (preferredLang != null && preferredLang.isNotEmpty) {
        try {
          final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
          await localeProvider.syncFromUserProfile(preferredLang);
        } catch (_) {}
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

  Widget _buildTrustBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.trustBadgeText),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.trustBadgeText,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context, LocaleProvider? localeProvider) {
    final currentCode = localeProvider?.currentLanguageCode ?? 'en';
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: const Key('login_language_dropdown'),
            value: currentCode,
            icon: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
            ),
            isDense: true,
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
                    Text(
                      lang.nativeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (newCode) {
              if (newCode != null && localeProvider != null) {
                localeProvider.setLocale(Locale(newCode));
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    LocaleProvider? localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context);
    } catch (_) {
      localeProvider = null;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation Bar: Showcase Explorer & Language Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProductShowcaseScreen()),
                            );
                          },
                          icon: const Icon(Icons.explore_outlined, size: 18, color: AppColors.primary),
                          label: Text(
                            context.tr('showcase_explore', fallback: 'Explore Carely'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: AppColors.primaryLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLanguageSelector(context, localeProvider),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // App Icon / Logo with gentle breathing halo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('app_name', fallback: AppStrings.appName),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('app_tagline', fallback: AppStrings.appTagline),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Promotional Trust Badges Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTrustBadge(
                          Icons.lock_outline,
                          context.tr('login_trust_privacy', fallback: 'Carely'),
                        ),
                        Container(width: 1, height: 20, color: AppColors.divider),
                        _buildTrustBadge(
                          Icons.battery_charging_full,
                          context.tr('login_trust_battery', fallback: 'Battery Saver'),
                        ),
                        Container(width: 1, height: 20, color: AppColors.divider),
                        _buildTrustBadge(
                          Icons.cloud_done_outlined,
                          context.tr('login_trust_server', fallback: '24/7 Server Guard'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: context.tr('auth_email_label', fallback: 'Email'),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return context.tr('auth_email_hint', fallback: 'Please enter your email');
                      }
                      if (!val.contains('@')) {
                        return context.tr('auth_email_invalid', fallback: 'Invalid email address');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.tr('auth_password_label', fallback: 'Password'),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return context.tr('auth_password_hint', fallback: 'Please enter your password');
                      }
                      if (val.length < 6) {
                        return context.tr('auth_password_min_length', fallback: 'Password must be at least 6 characters');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
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
                            context.tr('auth_login_button', fallback: 'Sign In'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Promotional Demo CTA Button
                  OutlinedButton.icon(
                    onPressed: () {
                      ShowcaseDemoController().enableDemo();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill, size: 20, color: AppColors.primary),
                    label: Text(
                      context.tr('login_try_demo', fallback: 'Try Interactive Demo (No login required)'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr('auth_no_account', fallback: 'Do not have an account? '),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          context.tr('auth_register_now', fallback: 'Register now'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
