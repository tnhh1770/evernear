import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/pairing/qr_code_parser.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 43 & 44: QrCodeParser Unit Tests', () {
    test('Extracts invite code from canonical carely:// scheme', () {
      final code = QrCodeParser.extractInviteCode('carely://invite?code=CR-ABC12345');
      expect(code, equals('CR-ABC12345'));
    });

    test('Extracts invite code from web universal link', () {
      final code = QrCodeParser.extractInviteCode('https://carely.app/invite?code=CR-XYZ98765');
      expect(code, equals('CR-XYZ98765'));
    });

    test('Extracts invite code from raw alphanumeric code', () {
      final code = QrCodeParser.extractInviteCode('CR-FEDCBA98');
      expect(code, equals('CR-FEDCBA98'));
    });

    test('Auto-uppercases lowercase invite codes in raw format and URI query params', () {
      expect(QrCodeParser.extractInviteCode('cr-abc12345'), equals('CR-ABC12345'));
      expect(QrCodeParser.extractInviteCode('carely://invite?code=cr-lower123'), equals('CR-LOWER123'));
    });

    test('Trims outer whitespace gracefully', () {
      expect(QrCodeParser.extractInviteCode('   CR-TRIMMED1   '), equals('CR-TRIMMED1'));
      expect(QrCodeParser.extractInviteCode('  carely://invite?code=CR-PADDED12  '), equals('CR-PADDED12'));
    });

    test('Returns null for invalid, empty, or unsupported patterns', () {
      expect(QrCodeParser.extractInviteCode(''), isNull);
      expect(QrCodeParser.extractInviteCode('   '), isNull);
      expect(QrCodeParser.extractInviteCode('random_invalid_string'), isNull);
      expect(QrCodeParser.extractInviteCode('carely://invite'), isNull);
      expect(QrCodeParser.extractInviteCode('https://example.com/path'), isNull);
      expect(QrCodeParser.extractInviteCode('CR-'), isNull);
    });

    test('buildInviteUri constructs canonical carely:// URI', () {
      final uri = QrCodeParser.buildInviteUri('CR-ABC12345');
      expect(uri, equals('carely://invite?code=CR-ABC12345'));
    });
  });

  group('Feature 43: QrInviteScreen Widget Tests', () {
    testWidgets('Renders QR image and formatted code with initialCode', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: QrInviteScreen(initialCode: 'CR-MOCK1234'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mã kết nối người thân'), findsOneWidget);
      expect(find.byKey(const Key('qr_image_view')), findsOneWidget);
      expect(find.byKey(const Key('invite_code_text')), findsOneWidget);
      expect(find.text('CR-MOCK1234'), findsOneWidget);
      expect(find.byKey(const Key('copy_invite_code_button')), findsOneWidget);
      expect(find.byKey(const Key('share_invite_code_button')), findsOneWidget);
    });

    testWidgets('Tapping copy button copies code and displays feedback snackbar', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: QrInviteScreen(initialCode: 'CR-COPYTEST'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('copy_invite_code_button')));
      await tester.pump();

      expect(find.text('Đã sao chép mã kết nối vào bộ nhớ tạm'), findsOneWidget);
    });
  });

  group('Feature 44: QrScannerScreen Widget & Headless Test Safety', () {
    testWidgets('Renders simulated input in headless test mode without camera crash', (tester) async {
      String? scannedResult;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: MaterialApp(
            home: QrScannerScreen(
              isTestMode: true,
              onCodeScanned: (code) {
                scannedResult = code;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quét mã kết nối'), findsOneWidget);
      expect(find.byKey(const Key('simulated_qr_input')), findsOneWidget);
      expect(find.byKey(const Key('simulated_qr_submit')), findsOneWidget);
      expect(find.byKey(const Key('open_manual_input_button')), findsOneWidget);

      // Enter simulated QR URL scheme
      await tester.enterText(
        find.byKey(const Key('simulated_qr_input')),
        'carely://invite?code=CR-SCANNED1',
      );
      await tester.tap(find.byKey(const Key('simulated_qr_submit')));
      await tester.pump();

      expect(scannedResult, equals('CR-SCANNED1'));
    });

    testWidgets('Manual entry dialog works cleanly inside scanner screen', (tester) async {
      String? scannedResult;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: MaterialApp(
            home: QrScannerScreen(
              isTestMode: true,
              onCodeScanned: (code) {
                scannedResult = code;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_manual_input_button')));
      await tester.pumpAndSettle();

      expect(find.text('Nhập mã kết nối'), findsOneWidget);
      expect(find.byKey(const Key('manual_code_input_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('manual_code_input_field')),
        'CR-MANUAL99',
      );
      await tester.tap(find.byKey(const Key('manual_code_submit_button')));
      await tester.pump();

      expect(scannedResult, equals('CR-MANUAL99'));
    });
  });

  group('LoginScreen & RegisterScreen Integration & Finder Preservation', () {
    testWidgets('LoginScreen renders all baseline form fields and buttons without social auth', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => IncidentsProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Baseline finders preservation
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đăng ký ngay'), findsOneWidget);

      // No social sign-in buttons present
      expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
      expect(find.byKey(const Key('apple_sign_in_button')), findsNothing);
    });

    testWidgets('RegisterScreen renders all baseline registration fields and submit button without social auth', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => IncidentsProvider()),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Số điện thoại (dùng nhận tin nhắn khẩn cấp)'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);

      // No social sign-in buttons present
      expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
      expect(find.byKey(const Key('apple_sign_in_button')), findsNothing);
    });
  });
}
