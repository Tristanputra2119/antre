import 'dart:async';

import 'package:antre/features/queue/domain/my_status.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:antre/features/queue/presentation/customer/customer_queue_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers.dart';

void main() {
  late MockQueueRepository repo;
  late StreamController<void> realtime;

  setUpAll(setUpIntl);

  setUp(() {
    repo = MockQueueRepository();
    realtime = realtimeController();
    when(() => repo.watchMyQueue()).thenAnswer((_) => realtime.stream);
    when(() => repo.getActiveSession()).thenAnswer((_) async => session);
  });

  tearDown(() => realtime.close());

  Future<void> pumpPage(WidgetTester tester) => pumpScreen(
    tester,
    const CustomerQueuePage(),
    overrides: [queueRepo(repo)],
  );

  void stubStatus(MyStatus status) =>
      when(() => repo.getMyStatus()).thenAnswer((_) async => status);

  group('renders every ticket status', () {
    final cases = <TicketStatus, String>{
      TicketStatus.waiting: 'Ada 2 orang di depan Anda.',
      TicketStatus.called: 'Giliran Anda!',
      TicketStatus.done: 'Potong rambut selesai.',
      TicketStatus.skipped: 'Nomor Anda dilewati.',
      TicketStatus.cancelled: 'Antrean dibatalkan.',
    };

    for (final MapEntry(key: status, value: message) in cases.entries) {
      testWidgets(status.name, (tester) async {
        stubStatus(myStatus(status: status));
        await pumpPage(tester);

        expect(find.text('5'), findsOneWidget);
        expect(find.text('Budi'), findsOneWidget);
        // The message sits below the ticket card and may start offscreen.
        await tester.scrollUntilVisible(
          find.text(message),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(message), findsOneWidget);

        final isWaiting = status == TicketStatus.waiting;
        expect(
          find.text('Batalkan antrean'),
          isWaiting ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Sekitar 20 menit lagi'),
          isWaiting ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Ambil nomor baru'),
          status.isActive ? findsNothing : findsOneWidget,
        );
      });
    }
  });

  testWidgets('reset session shows the reset message and a new-ticket button', (
    tester,
  ) async {
    stubStatus(myStatus(sessionActive: false));
    await pumpPage(tester);

    expect(find.text('Antrean telah direset.'), findsOneWidget);
    expect(find.text('Ambil nomor baru'), findsOneWidget);
    expect(find.text('Batalkan antrean'), findsNothing);
  });

  group('take ticket', () {
    setUp(() => stubStatus(const MyStatus()));

    testWidgets('shows the form when the user has no ticket', (tester) async {
      await pumpPage(tester);
      expect(find.text('Nama Anda'), findsOneWidget);
      await tester.pump();
      expect(find.text('Saat ini 2 orang menunggu'), findsOneWidget);
    });

    testWidgets('empty name is rejected without calling the server', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Ambil nomor'));
      await tester.pump();

      expect(find.text('Nama wajib diisi'), findsOneWidget);
      verifyNever(() => repo.takeTicket(any()));
    });

    testWidgets('submits the name then shows the status', (tester) async {
      await pumpPage(tester);
      when(() => repo.takeTicket('Budi')).thenAnswer((_) async => ticket());
      stubStatus(myStatus());

      await tester.enterText(find.byType(TextFormField), 'Budi');
      await tester.tap(find.widgetWithText(FilledButton, 'Ambil nomor'));
      await tester.pumpAndSettle();

      verify(() => repo.takeTicket('Budi')).called(1);
      expect(find.text('Batalkan antrean'), findsOneWidget);
    });

    testWidgets('server errors are shown in Indonesian', (tester) async {
      await pumpPage(tester);
      when(() => repo.takeTicket(any()))
          .thenThrow(const PostgrestException(message: 'already_has_ticket'));

      await tester.enterText(find.byType(TextFormField), 'Budi');
      await tester.tap(find.widgetWithText(FilledButton, 'Ambil nomor'));
      await tester.pump();

      expect(
        find.text('Anda sudah memiliki nomor antrean aktif.'),
        findsOneWidget,
      );
    });
  });

  group('cancel ticket', () {
    setUp(() => stubStatus(myStatus()));

    testWidgets('dismissing the dialog keeps the ticket', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Batalkan antrean'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap antre'));
      await tester.pumpAndSettle();

      verifyNever(() => repo.cancelTicket(any()));
    });

    testWidgets('confirming cancels the own ticket', (tester) async {
      await pumpPage(tester);
      when(() => repo.cancelTicket('ticket-5'))
          .thenAnswer((_) async => ticket(status: TicketStatus.cancelled));

      await tester.tap(find.text('Batalkan antrean'));
      await tester.pumpAndSettle();
      stubStatus(myStatus(status: TicketStatus.cancelled));
      await tester.tap(find.text('Batalkan nomor'));
      await tester.pumpAndSettle();

      verify(() => repo.cancelTicket('ticket-5')).called(1);
      expect(find.text('Antrean dibatalkan.'), findsOneWidget);
    });
  });

  group('live updates', () {
    testWidgets('a realtime event refetches and updates the page', (
      tester,
    ) async {
      stubStatus(myStatus());
      await pumpPage(tester);

      stubStatus(myStatus(status: TicketStatus.called));
      realtime.add(null);
      await tester.pumpAndSettle();

      expect(find.text('Giliran Anda!'), findsOneWidget);
    });

    testWidgets('refetches every 60 s while waiting', (tester) async {
      stubStatus(myStatus());
      await pumpPage(tester);
      verify(() => repo.getMyStatus()).called(1);

      await tester.pump(const Duration(seconds: 60));
      verify(() => repo.getMyStatus()).called(1);
    });

    testWidgets('no periodic refetch when the ticket is not waiting', (
      tester,
    ) async {
      stubStatus(myStatus(status: TicketStatus.called));
      await pumpPage(tester);
      verify(() => repo.getMyStatus()).called(1);

      await tester.pump(const Duration(seconds: 120));
      verifyNever(() => repo.getMyStatus());
    });

    testWidgets('keeps the last data and shows a banner when a refresh fails', (
      tester,
    ) async {
      stubStatus(myStatus());
      await pumpPage(tester);

      when(() => repo.getMyStatus()).thenThrow(Exception('offline'));
      realtime.add(null);
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.textContaining('Gagal memperbarui data'), findsOneWidget);
    });

    testWidgets('initial load failure shows a retry', (tester) async {
      when(() => repo.getMyStatus()).thenThrow(Exception('offline'));
      await pumpPage(tester);
      expect(find.text('Coba lagi'), findsOneWidget);

      stubStatus(myStatus());
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan antrean'), findsOneWidget);
    });
  });
}
