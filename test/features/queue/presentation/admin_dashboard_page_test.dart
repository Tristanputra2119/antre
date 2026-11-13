import 'dart:async';

import 'package:antre/features/queue/domain/my_status.dart';
import 'package:antre/features/queue/domain/queue_stats.dart';
import 'package:antre/features/queue/domain/ticket.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:antre/features/queue/presentation/admin/admin_dashboard_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers.dart';

void main() {
  late MockQueueRepository repo;
  late StreamController<void> realtime;

  setUpAll(() {
    registerFallbackValue(TicketStatus.waiting);
    return setUpIntl();
  });

  setUp(() {
    repo = MockQueueRepository();
    realtime = realtimeController();
    when(() => repo.watchAdminQueue()).thenAnswer((_) => realtime.stream);
    when(() => repo.getActiveSession()).thenAnswer((_) async => session);
  });

  tearDown(() => realtime.close());

  void stubTickets(List<Ticket> tickets) {
    when(() => repo.getSessionTickets('session-1'))
        .thenAnswer((_) async => tickets);
    final counts = <TicketStatus, int>{};
    for (final t in tickets) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }
    when(() => repo.getQueueStats()).thenAnswer(
      (_) async => QueueStats(
        counts: counts,
        total: tickets.length,
        estimateBasis: EstimateBasis.defaultValue,
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpScreen(
      tester,
      const AdminDashboardPage(),
      overrides: [queueRepo(repo)],
    );
    await tester.pumpAndSettle();
  }

  bool callNextEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Panggil berikutnya'),
      )
      .enabled;

  Future<void> openSheet(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the called ticket, stats and the list', (tester) async {
    stubTickets([
      ticket(number: 1, status: TicketStatus.called, name: 'Andi'),
      ticket(number: 2, name: 'Budi'),
    ]);
    await pumpPage(tester);

    expect(find.text('Sedang dipanggil'), findsOneWidget);
    expect(find.text('Andi'), findsNWidgets(2)); // current card + row
    expect(find.text('Budi'), findsOneWidget);
    expect(find.textContaining('1 menunggu  ·  2 total'), findsOneWidget);
    expect(find.textContaining('Rata-rata layanan –'), findsOneWidget);
    expect(find.text('Semua 2'), findsOneWidget);
    expect(find.text('Menunggu 1'), findsOneWidget);
  });

  group('Panggil berikutnya', () {
    testWidgets('disabled while a ticket is being called', (tester) async {
      stubTickets([
        ticket(number: 1, status: TicketStatus.called),
        ticket(number: 2),
      ]);
      await pumpPage(tester);

      expect(find.text('Selesaikan atau lewati nomor 1 dulu.'), findsOneWidget);
      expect(callNextEnabled(tester), isFalse);
    });

    testWidgets('disabled when nobody waits', (tester) async {
      stubTickets([ticket(number: 1, status: TicketStatus.done)]);
      await pumpPage(tester);

      expect(find.text('Tidak ada antrean yang menunggu.'), findsOneWidget);
      expect(callNextEnabled(tester), isFalse);
    });

    testWidgets('calls the next ticket', (tester) async {
      stubTickets([ticket(number: 1), ticket(number: 2)]);
      await pumpPage(tester);
      expect(callNextEnabled(tester), isTrue);
      when(
        () => repo.callNext(),
      ).thenAnswer((_) async => ticket(number: 1, status: TicketStatus.called));

      await tester.tap(find.text('Panggil berikutnya'));
      await tester.pumpAndSettle();

      verify(() => repo.callNext()).called(1);
    });

    testWidgets('server rejection is shown as a snackbar', (tester) async {
      stubTickets([ticket(number: 1)]);
      await pumpPage(tester);
      when(() => repo.callNext())
          .thenThrow(const PostgrestException(message: 'call_in_progress'));

      await tester.tap(find.text('Panggil berikutnya'));
      await tester.pump();

      expect(
        find.text('Masih ada nomor yang sedang dipanggil. Selesaikan dulu.'),
        findsOneWidget,
      );
    });
  });

  group('ticket actions', () {
    setUp(() {
      when(
        () => repo.setTicketStatus(any(), any()),
      ).thenAnswer((_) async => ticket(number: 1, status: TicketStatus.done));
    });

    testWidgets('current card finishes or skips the called ticket', (
      tester,
    ) async {
      stubTickets([ticket(number: 1, status: TicketStatus.called)]);
      await pumpPage(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Selesai'));
      await tester.pumpAndSettle();
      verify(() => repo.setTicketStatus('ticket-1', TicketStatus.done))
          .called(1);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Lewati'));
      await tester.pumpAndSettle();
      verify(() => repo.setTicketStatus('ticket-1', TicketStatus.skipped))
          .called(1);
    });

    testWidgets('waiting ticket sheet only offers skip', (tester) async {
      stubTickets([ticket(number: 2, name: 'Budi')]);
      await pumpPage(tester);
      await openSheet(tester, 'Budi');

      expect(find.text('Diambil'), findsOneWidget);
      expect(find.text('Panggil ulang'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      verify(() => repo.setTicketStatus('ticket-2', TicketStatus.skipped))
          .called(1);
    });

    testWidgets('skipped ticket can be recalled when nobody is called', (
      tester,
    ) async {
      stubTickets([ticket(number: 1, status: TicketStatus.skipped, name: 'A')]);
      await pumpPage(tester);
      await openSheet(tester, 'A');

      await tester.tap(find.text('Panggil ulang'));
      await tester.pumpAndSettle();
      verify(() => repo.setTicketStatus('ticket-1', TicketStatus.called))
          .called(1);
    });

    testWidgets('no recall while another ticket is called', (tester) async {
      stubTickets([
        ticket(number: 1, status: TicketStatus.skipped, name: 'A'),
        ticket(number: 2, status: TicketStatus.called, name: 'B'),
      ]);
      await pumpPage(tester);
      await openSheet(tester, 'A');

      expect(find.text('Panggil ulang'), findsNothing);
      expect(find.text('Tidak ada aksi untuk tiket ini.'), findsOneWidget);
    });
  });

  testWidgets('filter chip shows only matching tickets', (tester) async {
    stubTickets([
      ticket(number: 1, status: TicketStatus.done, name: 'Andi'),
      ticket(number: 2, name: 'Budi'),
    ]);
    await pumpPage(tester);

    await tester.ensureVisible(find.text('Selesai 1'));
    await tester.tap(find.text('Selesai 1'));
    await tester.pumpAndSettle();

    expect(find.text('Andi'), findsOneWidget);
    expect(find.text('Budi'), findsNothing);
  });

  testWidgets('reset asks for confirmation with the waiting count', (
    tester,
  ) async {
    stubTickets([ticket(number: 1), ticket(number: 2)]);
    await pumpPage(tester);
    when(() => repo.resetQueue()).thenAnswer((_) async => session);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset antrean'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Masih ada 2 orang menunggu'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    verify(() => repo.resetQueue()).called(1);
  });
}
