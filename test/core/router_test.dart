import 'dart:async';

import 'package:antre/core/router.dart';
import 'package:antre/core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers.dart';

User user({required bool anonymous}) => User(
  id: anonymous ? 'anon-1' : 'staff-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-12T00:00:00Z',
  isAnonymous: anonymous,
);

void main() {
  late MockAuthRepository auth;
  late MockQueueRepository queue;

  setUpAll(setUpIntl);

  setUp(() {
    auth = MockAuthRepository();
    queue = MockQueueRepository();
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => auth.ensureSession()).thenAnswer((_) async {});
    when(() => queue.watchAdminQueue()).thenAnswer((_) => const Stream.empty());
    when(() => queue.getActiveSession()).thenAnswer((_) async => null);
    when(() => queue.getQueueStats())
        .thenAnswer((_) async => stats(waiting: 0, total: 0));
  });

  Future<GoRouterForTest> pumpRouter(WidgetTester tester) async {
    usePhoneViewport(tester);
    final container = ProviderContainer(
      overrides: [authRepo(auth), queueRepo(queue)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    // Not pumpAndSettle: the splash spinner never settles.
    await tester.pump();
    await tester.pump();
    return GoRouterForTest(tester, router);
  }

  testWidgets('no session stays on splash and bootstraps one', (tester) async {
    when(() => auth.currentUser).thenReturn(null);
    final r = await pumpRouter(tester);

    expect(r.location, Routes.splash);
    verify(() => auth.ensureSession()).called(1);
  });

  testWidgets('with a session the splash moves to home', (tester) async {
    when(() => auth.currentUser).thenReturn(user(anonymous: true));
    final r = await pumpRouter(tester);
    expect(r.location, Routes.home);
  });

  testWidgets('anonymous user is sent from /admin to the login page', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(user(anonymous: true));
    final r = await pumpRouter(tester);

    await r.go(Routes.admin);
    expect(r.location, Routes.adminLogin);
    verifyNever(() => auth.isAdmin());
  });

  testWidgets('signed-in non-admin is sent to the login page', (tester) async {
    when(() => auth.currentUser).thenReturn(user(anonymous: false));
    when(() => auth.isAdmin()).thenAnswer((_) async => false);
    final r = await pumpRouter(tester);

    await r.go(Routes.admin);
    expect(r.location, Routes.adminLogin);
  });

  testWidgets('admin can open the dashboard', (tester) async {
    when(() => auth.currentUser).thenReturn(user(anonymous: false));
    when(() => auth.isAdmin()).thenAnswer((_) async => true);
    final r = await pumpRouter(tester);

    await r.go(Routes.admin);
    expect(r.location, Routes.admin);
    expect(find.text('Antrean hari ini'), findsOneWidget);
  });

  testWidgets('a failing role check counts as not admin', (tester) async {
    when(() => auth.currentUser).thenReturn(user(anonymous: false));
    when(() => auth.isAdmin()).thenThrow(Exception('offline'));
    final r = await pumpRouter(tester);

    await r.go(Routes.admin);
    expect(r.location, Routes.adminLogin);
  });
}

class GoRouterForTest {
  GoRouterForTest(this._tester, this._router);

  final WidgetTester _tester;
  final GoRouter _router;

  String get location => _router.routerDelegate.currentConfiguration.uri.path;

  Future<void> go(String path) async {
    _router.go(path);
    await _tester.pumpAndSettle();
  }
}
