import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_provider.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    LocaleProvider? localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    } catch (_) {}

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      fullName: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      preferredLanguage: localeProvider?.currentLanguageCode,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('auth_register_title', fallback: 'Create Account')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  context.tr('auth_register_subtitle', fallback: 'Start protecting peace of mind for you and your family'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),

                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('auth_full_name_label', fallback: 'Full Name'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? context.tr('auth_full_name_hint', fallback: 'Please enter your full name') : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.tr('auth_email_label', fallback: 'Email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return context.tr('auth_email_hint', fallback: 'Please enter your email');
                    if (!val.contains('@')) return context.tr('auth_email_invalid', fallback: 'Invalid email address');
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('auth_phone_label', fallback: 'Phone number (for emergency alerts)'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: context.tr('auth_password_label', fallback: 'Password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return context.tr('auth_password_hint', fallback: 'Please enter your password');
                    if (val.length < 6) return context.tr('auth_password_min_length', fallback: 'Password must be at least 6 characters');
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Privacy info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryDark, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('privacy_notice', fallback: AppStrings.privacyNotice),
                          style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Register Button
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                          context.tr('auth_register_button', fallback: 'Privacy: No continuous GPS tracking. No microphone, no camera. Passive reachability only.'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
