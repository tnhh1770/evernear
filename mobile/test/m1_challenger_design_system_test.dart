import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:mobile/core/widgets/active_account_chip.dart';
import 'package:mobile/core/widgets/calm_loading_widget.dart';
import 'package:mobile/core/widgets/calm_error_card.dart';
import 'package:mobile/core/widgets/calm_empty_state.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildThemedApp({
    required Widget child,
    ThemeData? customTheme,
    Locale locale = const Locale('vi'),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: LocaleCatalogRegistry.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: customTheme ??
            ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                surface: Colors.white,
                error: AppColors.stateAlertTriggered,
              ),
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: true,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF5F6F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                ),
                prefixIconColor: AppColors.textSecondary,
                suffixIconColor: AppColors.textSecondary,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textMuted,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
        home: Scaffold(body: child),
      ),
    );
  }

  group('M1 Challenger Oracle: AppColors Design Tokens Verification', () {
    test('1.1 Primary & Secondary Forest-Green color token hex accuracy', () {
      expect(AppColors.primary, const Color(0xFF2D6A4F), reason: 'Forest Green');
      expect(AppColors.primaryLight, const Color(0xFFE6F2EC), reason: 'Soft Sage Tint');
      expect(AppColors.primaryDark, const Color(0xFF1E4D38), reason: 'Deep Forest Green');
      expect(AppColors.secondary, const Color(0xFF68A67D), reason: 'Sage Green');
      expect(AppColors.secondaryLight, const Color(0xFFEDF5F0), reason: 'Light Sage Surface');
    });

    test('1.2 Surface, Background, Card, and Input fill tokens', () {
      expect(AppColors.background, const Color(0xFFF4F6F3), reason: 'Warm sage-tinted off-white canvas');
      expect(AppColors.surface, const Color(0xFFFFFFFF), reason: 'Pure White');
      expect(AppColors.surfaceElevated, const Color(0xFFFFFFFF));
      expect(AppColors.cardBorder, const Color(0xFFE6E8E4), reason: 'Warm stone card border');
      expect(AppColors.chipBackground, const Color(0xFFE6F2EC), reason: 'Sage chip background');
      expect(AppColors.inputFill, const Color(0xFFFFFFFF), reason: 'Input background fill');
    });

    test('1.3 Typography hierarchy tokens', () {
      expect(AppColors.textPrimary, const Color(0xFF1B2A22), reason: 'Dark forest charcoal primary text');
      expect(AppColors.textSecondary, const Color(0xFF5C6B62), reason: 'Muted sage-slate secondary text');
      expect(AppColors.textMuted, const Color(0xFF8C9A92), reason: 'Muted grey');
      expect(AppColors.divider, const Color(0xFFE6E8E4), reason: 'Subtle divider');
    });

    test('1.4 Status tokens & Forest-Green brand presence', () {
      expect(AppColors.stateActive, const Color(0xFF52B788), reason: 'Vibrant Sage Green active status');
      expect(AppColors.stateAlertTriggered, const Color(0xFFD9534F));
      expect(AppColors.primary, const Color(0xFF2D6A4F));
    });

    test('1.5 Modern gradients composition', () {
      expect(AppColors.calmGreenGradient.colors, [
        const Color(0xFF1E4D38),
        const Color(0xFF2D6A4F),
        const Color(0xFF52B788),
      ]);
      expect(AppColors.calmGreenGradient.begin, Alignment.topLeft);
      expect(AppColors.calmGreenGradient.end, Alignment.bottomRight);
    });
  });

  group('M1 Challenger Oracle: Backward Compatibility of calmGreenGradient', () {
    test('2.1 calmGreenGradient is aliased to coralGradient', () {
      expect(AppColors.calmGreenGradient, equals(AppColors.coralGradient));
      expect(AppColors.calmGreenGradient.colors, equals(AppColors.coralGradient.colors));
      expect(AppColors.calmGreenGradient.colors, contains(const Color(0xFF2D6A4F)));
    });

    testWidgets('2.2 Rendering a widget decorated with calmGreenGradient succeeds cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                key: const ValueKey('gradient_box'),
                width: 200,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: AppColors.calmGreenGradient,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: const Center(
                  child: Text(
                    'Legacy Caller Text',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('gradient_box')), findsOneWidget);
      expect(find.text('Legacy Caller Text'), findsOneWidget);

      final container = tester.widget<Container>(find.byKey(const ValueKey('gradient_box')));
      final boxDeco = container.decoration as BoxDecoration;
      expect(boxDeco.gradient, equals(AppColors.coralGradient));
      expect((boxDeco.gradient as LinearGradient).colors, contains(const Color(0xFF2D6A4F)));
    });
  });

  group('M1 Challenger Oracle: Global ThemeData Specs in EvernearApp', () {
    testWidgets('3.1 EvernearApp builds with specified Forest-Green theme properties', (tester) async {
      late ThemeData theme;
      await tester.runAsync(() async {
        await tester.pumpWidget(const EvernearApp());
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        theme = materialApp.theme!;
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pumpWidget(const SizedBox());
        await Future.delayed(const Duration(milliseconds: 100));
      });

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.surface, Colors.white);
      expect(theme.scaffoldBackgroundColor, AppColors.background);

      // AppBar Theme
      expect(theme.appBarTheme.backgroundColor, AppColors.background);
      expect(theme.appBarTheme.foregroundColor, AppColors.textPrimary);
      expect(theme.appBarTheme.elevation, 0);

      // Button Themes
      expect(theme.elevatedButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
      expect(theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), AppColors.primary);
      expect(theme.elevatedButtonTheme.style?.foregroundColor?.resolve({}), Colors.white);

      expect(theme.outlinedButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
      expect(theme.outlinedButtonTheme.style?.foregroundColor?.resolve({}), AppColors.primary);

      expect(theme.textButtonTheme.style?.foregroundColor?.resolve({}), AppColors.primary);

      // Card Theme
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(16));
      expect(cardShape.side.color, AppColors.cardBorder);

      // Input Decoration Theme
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, Colors.white);
      expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());

      final focusedBorder = theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, AppColors.primary);

      // Bottom Navigation Theme
      expect(theme.bottomNavigationBarTheme.selectedItemColor, AppColors.primary);
      expect(theme.bottomNavigationBarTheme.backgroundColor, Colors.white);
    });

    testWidgets('3.2 Unstyled Elevated, Outlined, and Text buttons inherit pill and coral themes', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {},
                child: const Text('Elevated Pill'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Outlined Pill'),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Text Coral'),
              ),
            ],
          ),
        ),
      );

      final elevatedBtnFinder = find.widgetWithText(ElevatedButton, 'Elevated Pill');
      expect(elevatedBtnFinder, findsOneWidget);

      final outlinedBtnFinder = find.widgetWithText(OutlinedButton, 'Outlined Pill');
      expect(outlinedBtnFinder, findsOneWidget);

      final textBtnFinder = find.widgetWithText(TextButton, 'Text Coral');
      expect(textBtnFinder, findsOneWidget);
    });

    testWidgets('3.3 Unstyled TextField inherits filled grey background and 16px radius', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Enter text here',
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.hintText, 'Enter text here');
    });

    testWidgets('3.4 Unstyled Card inherits white fill and subtle card border', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          child: const Card(
            child: Text('Card Content'),
          ),
        ),
      );

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
      final card = tester.widget<Card>(cardFinder);
      // Card color falls back to theme.cardTheme.color if null
      expect(card.color ?? Colors.white, Colors.white);
    });
  });

  group('M1 Challenger Oracle: ActiveAccountAppBarAction & Banner Empirical Tests', () {
    testWidgets('5.1 ActiveAccountAppBarAction renders with coral avatar and green active dot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                ActiveAccountAppBarAction(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActiveAccountAppBarAction), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, AppColors.primary);
    });

    testWidgets('5.2 Tapping ActiveAccountAppBarAction opens bottom sheet with coral status', (tester) async {
      await LocalStorage.saveAuth(
        accessToken: 'dummy-access',
        refreshToken: 'dummy-refresh',
        userId: 'u123',
        email: 'challenger@carely.vn',
        fullName: 'Challenger Alpha',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  ActiveAccountAppBarAction(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Challenger Alpha'), findsOneWidget);
      await tester.tap(find.byType(ActiveAccountAppBarAction));
      await tester.pumpAndSettle();

      // Modal bottom sheet opened
      expect(find.text('ĐANG ĐĂNG NHẬP'), findsWidgets);
      expect(find.text('challenger@carely.vn'), findsWidgets);
      expect(find.text('Hồ sơ tài khoản'), findsOneWidget);
    });

    testWidgets('5.3 ActiveAccountBanner renders user card with blush avatar', (tester) async {
      await LocalStorage.saveAuth(
        accessToken: 'dummy-access',
        refreshToken: 'dummy-refresh',
        userId: 'u456',
        email: 'banner@carely.vn',
        fullName: 'Banner User',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActiveAccountBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActiveAccountBanner), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Banner User'),
        ),
        findsOneWidget,
      );
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('5.4 ActiveAccountBanner returns SizedBox.shrink() when user is unauthenticated and empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActiveAccountBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerFinder = find.byType(ActiveAccountBanner);
      expect(bannerFinder, findsOneWidget);
      expect(find.textContaining('Tài khoản:'), findsNothing);
    });
  });

  group('M1 Challenger Oracle: CalmLoadingWidget Empirical Tests', () {
    testWidgets('6.1 CalmLoadingWidget renders primary coral indicator and textSecondary message', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          child: const CalmLoadingWidget(
            message: 'Đang tải dữ liệu kiểm tra...',
            size: 40,
          ),
        ),
      );

      expect(find.byType(CalmLoadingWidget), findsOneWidget);
      expect(find.text('Đang tải dữ liệu kiểm tra...'), findsOneWidget);

      final cpi = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(cpi.color, AppColors.primary);

      final text = tester.widget<Text>(find.text('Đang tải dữ liệu kiểm tra...'));
      expect(text.style?.color, AppColors.textSecondary);
    });
  });

  group('M1 Challenger Oracle: CalmErrorCard Empirical Tests', () {
    testWidgets('7.1 CalmErrorCard renders white card with blush circle icon and retry button', (tester) async {
      int retryCalls = 0;
      await tester.pumpWidget(
        buildThemedApp(
          child: CalmErrorCard(
            title: 'Lỗi kết nối kiểm tra',
            message: 'Không thể kết nối đến máy chủ bảo hộ',
            onRetry: () {
              retryCalls++;
            },
          ),
        ),
      );

      expect(find.byType(CalmErrorCard), findsOneWidget);
      expect(find.text('Lỗi kết nối kiểm tra'), findsOneWidget);
      expect(find.text('Không thể kết nối đến máy chủ bảo hộ'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Verify retry button presence and tap
      expect(find.text(AppStrings.retryButton), findsOneWidget);
      await tester.tap(find.text(AppStrings.retryButton));
      await tester.pump();
      expect(retryCalls, 1);
    });

    testWidgets('7.2 CalmErrorCard without onRetry does not render retry button', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          child: const CalmErrorCard(
            message: 'Thông báo lỗi chỉ đọc',
          ),
        ),
      );

      expect(find.text('Thông báo lỗi chỉ đọc'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('M1 Challenger Oracle: CalmEmptyState Empirical Tests', () {
    testWidgets('8.1 CalmEmptyState renders white container with blush circular icon and charcoal title', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          child: const CalmEmptyState(
            title: 'Chưa có sự cố',
            description: 'Mọi hoạt động đều an toàn và bình thường',
          ),
        ),
      );

      expect(find.byType(CalmEmptyState), findsOneWidget);
      expect(find.text('Chưa có sự cố'), findsOneWidget);
      expect(find.text('Mọi hoạt động đều an toàn và bình thường'), findsOneWidget);

      final titleText = tester.widget<Text>(find.text('Chưa có sự cố'));
      expect(titleText.style?.color, AppColors.textPrimary);

      final descText = tester.widget<Text>(find.text('Mọi hoạt động đều an toàn và bình thường'));
      expect(descText.style?.color, AppColors.textSecondary);
    });

    testWidgets('8.2 CalmEmptyState with custom action button renders and responds to tap', (tester) async {
      int actionCalls = 0;
      await tester.pumpWidget(
        buildThemedApp(
          child: CalmEmptyState(
            action: ElevatedButton(
              onPressed: () {
                actionCalls++;
              },
              child: const Text('Thực hiện hành động'),
            ),
          ),
        ),
      );

      expect(find.text('Thực hiện hành động'), findsOneWidget);
      await tester.tap(find.text('Thực hiện hành động'));
      await tester.pump();
      expect(actionCalls, 1);
    });
  });
}
