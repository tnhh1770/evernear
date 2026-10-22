import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/widgets/language_selector.dart';
import 'package:mobile/core/widgets/language_selector_capsule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocalizations.globalLocaleCode = 'vi';
  });

  group('LanguageSelector Widget Tests', () {
    testWidgets('Renders with default preauth_language_selector key and displays current language code', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: MaterialApp(
            locale: localeProvider.currentLocale,
            supportedLocales: LocaleCatalogRegistry.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: LanguageSelector(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
    });

    testWidgets('Custom dropdownKey and onChanged callback function accurately', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      String? changedTo;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ],
          child: MaterialApp(
            locale: localeProvider.currentLocale,
            supportedLocales: LocaleCatalogRegistry.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: LanguageSelector(
                dropdownKey: const Key('custom_test_dropdown'),
                onChanged: (code) => changedTo = code,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom_test_dropdown')), findsOneWidget);

      // Open dropdown and select French
      await tester.tap(find.byKey(const Key('custom_test_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();

      expect(changedTo, 'fr');
      expect(localeProvider.currentLanguageCode, 'fr');
    });

    testWidgets('LanguageSelectorCapsule alias is identical to LanguageSelector', (tester) async {
      const capsule = LanguageSelectorCapsule(dropdownKey: Key('capsule_key'));
      expect(capsule, isA<LanguageSelector>());
    });

    testWidgets('Gracefully renders when LocaleProvider is not in context (unwrapped test safety)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageSelector(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelector), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
    });
  });
}
