import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artlore/core/services/auth_service.dart';
import 'package:artlore/core/services/user_data_repository.dart';
import 'package:artlore/core/theme/app_theme.dart';
import 'package:artlore/core/widgets/app_shell.dart';
import 'package:artlore/main.dart';

void main() {
  // Widget tests never touch a real backend: swap in pure-Dart fakes instead
  // of the real FirebaseAuth/Firestore singletons, which need a live app.
  setUpAll(() {
    AuthService.debugAuth = MockFirebaseAuth();
    UserDataRepository.debugFirestore = FakeFirebaseFirestore();
  });

  testWidgets('App launches into the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ArtfulApp());

    expect(find.text('Artlore'), findsOneWidget);
    expect(find.text('Look closer. Discover more.'), findsOneWidget);
  });

  testWidgets('Bottom-nav shell renders Home, Collection, Ask and Profile without layout errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AppShell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Good morning! 👋'), findsOneWidget);

    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Saved artworks'), findsOneWidget);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ask about this painting'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
  });
}
