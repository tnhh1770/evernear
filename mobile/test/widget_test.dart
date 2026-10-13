import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';

void main() {
  testWidgets('Carely LoginScreen renders branding and form fields', (WidgetTester tester) async {
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

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
  });
}
