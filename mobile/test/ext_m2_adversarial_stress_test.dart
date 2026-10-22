import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/permission_service.dart';
import 'package:mobile/core/widgets/calm_error_card.dart';
import 'package:mobile/features/pairing/qr_code_parser.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. QR CODE PARSER ADVERSARIAL FUZZING & MALFORMED URIs
  // =========================================================================
  group('1. QrCodeParser Adversarial Fuzzing & Malformed URIs', () {
    test('Handles null, empty, and whitespace strings safely', () {
      expect(QrCodeParser.extractInviteCode(null), isNull);
      expect(QrCodeParser.extractInviteCode(''), isNull);
      expect(QrCodeParser.extractInviteCode('   \t\n\r   '), isNull);
    });

    test('Adversarial URI inputs: empty code query or missing query', () {
      expect(QrCodeParser.extractInviteCode('carely://invite?code='), isNull);
      expect(QrCodeParser.extractInviteCode('carely://invite'), isNull);
      expect(QrCodeParser.extractInviteCode('carely://invite?other=123'), isNull);
      expect(QrCodeParser.extractInviteCode('carely://'), isNull);
    });

    test('Extracts normalized code from varied valid schemas', () {
      // carely:// scheme with various hosts
      expect(QrCodeParser.extractInviteCode('carely://invalid?code=XYZ'), equals('XYZ'));
      expect(QrCodeParser.extractInviteCode('carely://pair?code=cr-alpha1'), equals('CR-ALPHA1'));
      // Web URLs with different domains
      expect(QrCodeParser.extractInviteCode('https://carely.vn/invite?code=CR-123456'), equals('CR-123456'));
      expect(QrCodeParser.extractInviteCode('http://subdomain.carely.app/path?code=CR-WEB789'), equals('CR-WEB789'));
    });

    test('Percent-encoding malformed attacks do NOT throw FormatException', () {
      // Malformed percent encodings often crash unshielded Uri.queryParameters
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=%ZZ'), returnsNormally);
      expect(QrCodeParser.extractInviteCode('carely://invite?code=%ZZ'), equals('%ZZ'));

      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=%'), returnsNormally);
      expect(QrCodeParser.extractInviteCode('carely://invite?code=%'), equals('%'));

      expect(() => QrCodeParser.extractInviteCode('https://carely.app/invite?code=%E0%A4%A'), returnsNormally);
    });

    test('SQL injection & script injection payloads do NOT throw and extract safely', () {
      const sqlPayload1 = "carely://invite?code=' OR 1=1; DROP TABLE users; --";
      expect(() => QrCodeParser.extractInviteCode(sqlPayload1), returnsNormally);
      final res1 = QrCodeParser.extractInviteCode(sqlPayload1);
      // Either extracts the uppercase code param or null, NEVER throws
      expect(res1, isA<String?>());

      const xssPayload = "<script>alert('xss')</script>";
      expect(QrCodeParser.extractInviteCode(xssPayload), isNull);

      const sqlRaw = "SELECT * FROM users WHERE code='CR-12345'";
      // Step 3 regex matches standard prefix
      expect(QrCodeParser.extractInviteCode(sqlRaw), equals('CR-12345'));
    });

    test('Unicode, emojis, RTL, and special characters do NOT crash regex/parser', () {
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=CR-🔥🚀🎉'), returnsNormally);
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=CR-日本語한국어'), returnsNormally);
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=CR-مرحبا'), returnsNormally);
      expect(() => QrCodeParser.extractInviteCode('CR-\u0000\u0001\u0002'), returnsNormally);
      expect(() => QrCodeParser.extractInviteCode('CR-👩‍👩‍👧‍👦-PAIR'), returnsNormally);
    });

    test('Long string payload (20,000 characters) does not cause ReDoS or stack overflow', () {
      final hugePayload = 'carely://invite?code=${'A' * 20000}';
      final stopwatch = Stopwatch()..start();
      final res = QrCodeParser.extractInviteCode(hugePayload);
      stopwatch.stop();

      expect(res, isNotNull);
      expect(res!.length, equals(20000));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000), reason: 'Must complete within 1 second');
    });

    test('Fuzzing harness: 200 randomized inputs never throw', () {
      final random = Random(42);
      final sampleChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789%/?&=:;-_#@!*~ \n\r\t';

      for (int i = 0; i < 200; i++) {
        final length = random.nextInt(120);
        final buffer = StringBuffer();
        for (int j = 0; j < length; j++) {
          buffer.write(sampleChars[random.nextInt(sampleChars.length)]);
        }
        final fuzzInput = buffer.toString();

        expect(
          () => QrCodeParser.extractInviteCode(fuzzInput),
          returnsNormally,
          reason: 'Fuzz input #$i failed: $fuzzInput',
        );
      }
    });

    test('buildInviteUri produces valid format and roundtrips through extractInviteCode', () {
      final uri = QrCodeParser.buildInviteUri('cr-testcode99');
      expect(uri, equals('evernear://invite?code=CR-TESTCODE99'));

      final extracted = QrCodeParser.extractInviteCode(uri);
      expect(extracted, equals('CR-TESTCODE99'));
    });
  });

  // =========================================================================
  // 2. UNWRAPPED WIDGET RESILIENCE
  // =========================================================================
  group('2. Unwrapped Widget Resilience', () {
    testWidgets('QrScannerScreen renders cleanly unwrapped without DashboardProvider', (tester) async {
      String? scannedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerScreen(
            isTestMode: true,
            onCodeScanned: (code) {
              scannedResult = code;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quét mã kết nối'), findsOneWidget);
      expect(find.byKey(const Key('simulated_qr_input')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Trigger simulated QR submit
      await tester.enterText(
        find.byKey(const Key('simulated_qr_input')),
        'carely://invite?code=CR-UNWRAPPED77',
      );
      await tester.tap(find.byKey(const Key('simulated_qr_submit')));
      await tester.pump();

      expect(scannedResult, equals('CR-UNWRAPPED77'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('QrInviteScreen with initialCode renders cleanly unwrapped without DashboardProvider', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrInviteScreen(initialCode: 'CR-PRESET99'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mã kết nối người thân'), findsOneWidget);
      expect(find.byKey(const Key('qr_image_view')), findsOneWidget);
      expect(find.text('CR-PRESET99'), findsOneWidget);
      expect(find.byKey(const Key('copy_invite_code_button')), findsOneWidget);
      expect(find.byKey(const Key('share_invite_code_button')), findsOneWidget);

      // Tap copy button and verify clipboard interaction
      await tester.tap(find.byKey(const Key('copy_invite_code_button')));
      await tester.pump();

      expect(find.text('Đã sao chép mã kết nối vào bộ nhớ tạm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QrInviteScreen tapping share button formats canonical deep link and shows snackbar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrInviteScreen(initialCode: 'CR-SHARE99'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_invite_code_button')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('share_invite_code_button')));
      await tester.tap(find.byKey(const Key('share_invite_code_button')));
      await tester.pump();

      expect(find.text('Đã sao chép liên kết chia sẻ lời mời'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 3. CAMERA PERMISSION DENIAL FALLBACK
  // =========================================================================
  group('3. Camera Permission Denial Fallback', () {
    test('PermissionService.requestCameraPermission returns false in headless test VM', () async {
      final res = await PermissionService().requestCameraPermission();
      expect(res, isFalse);
    });

    testWidgets('QrScannerScreen with isTestMode: false falls back to CalmErrorCard when camera is unavailable/denied', (tester) async {
      String? scannedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerScreen(
            isTestMode: false,
            onCodeScanned: (code) {
              scannedResult = code;
            },
          ),
        ),
      );

      // Allow asynchronous platform permission inquiry to settle
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Verify CalmErrorCard is displayed on camera denial
      expect(find.text('Quét mã QR'), findsOneWidget);
      expect(find.byType(CalmErrorCard), findsOneWidget);
      expect(
        find.textContaining('Evernear cần quyền sử dụng camera để quét mã QR kết nối.'),
        findsOneWidget,
      );
      expect(find.text('Nhập mã thủ công'), findsOneWidget);

      // Tap retry/manual entry button
      await tester.tap(find.text('Nhập mã thủ công'));
      await tester.pumpAndSettle();

      // Manual input dialog should open
      expect(find.text('Nhập mã kết nối'), findsWidgets);
      expect(find.byKey(const Key('manual_code_input_field')), findsOneWidget);

      // Enter manual code and submit
      await tester.enterText(
        find.byKey(const Key('manual_code_input_field')),
        'CR-FALLBACK123',
      );
      await tester.tap(find.byKey(const Key('manual_code_submit_button')));
      await tester.pump();

      expect(scannedResult, equals('CR-FALLBACK123'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('QrScannerScreen displays CalmErrorCard when camera permission is explicitly denied via platform channel', (tester) async {
      const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'checkPermissionStatus') {
          return 0; // PermissionStatus.denied
        }
        if (call.method == 'requestPermissions') {
          return {call.arguments[0]: 0}; // denied
        }
        return null;
      });

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: QrScannerScreen(
              isTestMode: false,
              onCodeScanned: (_) {},
            ),
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();

        expect(find.byType(CalmErrorCard), findsOneWidget);
        expect(find.text('Nhập mã thủ công'), findsOneWidget);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    });
  });

  // =========================================================================
  // 4. HEADLESS TEST SAFETY & ZERO MissingPluginException
  // =========================================================================
  group('4. Headless Test Safety (Zero MissingPluginException)', () {
    testWidgets('QrScannerScreen never throws MissingPluginException in automated test runner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerScreen(
            onCodeScanned: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Verifying zero MissingPluginException
      expect(tester.takeException(), isNull);
    });
  });
}
