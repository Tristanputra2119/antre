// End-to-end check against the real Supabase project, using the app's own
// repositories. Skipped unless run with live config, e.g.:
//
//   flutter test test/e2e --dart-define-from-file=env.json \
//     --dart-define=ADMIN_EMAIL=... --dart-define=ADMIN_PASSWORD=...
//
// It resets the queue at start and end, so don't run it while a real queue is open.

import 'dart:async';

import 'package:antre/core/errors.dart';
import 'package:antre/features/auth/data/auth_repository.dart';
import 'package:antre/features/queue/data/queue_repository.dart';
import 'package:antre/features/queue/domain/ticket.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
const _adminEmail = String.fromEnvironment('ADMIN_EMAIL');
const _adminPassword = String.fromEnvironment('ADMIN_PASSWORD');
const _skip = _url == '' || _adminEmail == ''
    ? 'needs --dart-define-from-file=env.json and ADMIN_EMAIL/ADMIN_PASSWORD'
    : null;

/// Realtime must deliver within PRD's ~2 s; allow headroom for CI networks.
const _realtimeTimeout = Duration(seconds: 6);

SupabaseClient _newClient() => SupabaseClient(
  _url,
  _key,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

/// Completes when [check] holds after a realtime event (not by polling).
Future<void> _untilEvent(Stream<void> events, Future<bool> Function() check) {
  final done = Completer<void>();
  late final StreamSubscription<void> sub;
  sub = events.listen((_) async {
    // Events arrive in bursts; re-check after the await so we complete once.
    if (!done.isCompleted && await check() && !done.isCompleted) {
      done.complete();
    }
  });
  return done.future.timeout(_realtimeTimeout).whenComplete(sub.cancel);
}

Matcher _rpcError(String code) =>
    isA<PostgrestException>().having((e) => e.message, 'message', code);

void main() {
  group('live Supabase', skip: _skip, () {
    late SupabaseClient adminClient, aliceClient, bobClient;
    late QueueRepository admin, alice, bob;
    late StreamController<void> aliceEvents, adminEvents;
    final subs = <StreamSubscription<void>>[];
    late Ticket aliceTicket, bobTicket;

    setUpAll(() async {
      adminClient = _newClient();
      aliceClient = _newClient();
      bobClient = _newClient();

      await AuthRepository(adminClient)
          .signInAdmin(email: _adminEmail, password: _adminPassword);
      await AuthRepository(aliceClient).ensureSession();
      await AuthRepository(bobClient).ensureSession();

      admin = QueueRepository(adminClient);
      alice = QueueRepository(aliceClient);
      bob = QueueRepository(bobClient);

      await admin.resetQueue();

      // Rebroadcast so several waits can listen; wait for the "subscribed" ping.
      aliceEvents = StreamController<void>.broadcast();
      adminEvents = StreamController<void>.broadcast();
      final aliceReady = aliceEvents.stream.first.timeout(_realtimeTimeout);
      final adminReady = adminEvents.stream.first.timeout(_realtimeTimeout);
      subs
        ..add(alice.watchMyQueue().listen(aliceEvents.add))
        ..add(admin.watchAdminQueue().listen(adminEvents.add));
      await (aliceReady, adminReady).wait;
    });

    tearDownAll(() async {
      for (final s in subs) {
        await s.cancel();
      }
      await admin.resetQueue();
      for (final c in [adminClient, aliceClient, bobClient]) {
        await c.dispose();
      }
    });

    test('two customers taking a number at once get 1 and 2', () async {
      final (a, b) = await (
        alice.takeTicket('Alice E2E'),
        bob.takeTicket('  Bob E2E '),
      ).wait;
      expect({a.number, b.number}, {1, 2});
      expect(b.customerName, 'Bob E2E');
      (aliceTicket, bobTicket) = (a, b);
    });

    test('a second active ticket for the same device is rejected', () async {
      await expectLater(
        alice.takeTicket('Alice lagi'),
        throwsA(_rpcError('already_has_ticket')),
      );
      expect(
        friendlyError(const PostgrestException(message: 'already_has_ticket')),
        contains('sudah'),
      );
    });

    test('customers only see their own ticket (RLS)', () async {
      final rows = await aliceClient.from('tickets').select('id');
      expect(rows.map((r) => r['id']), [aliceTicket.id]);
    });

    test('customers cannot call admin RPCs', () async {
      await expectLater(alice.callNext(), throwsA(_rpcError('not_admin')));
      await expectLater(alice.resetQueue(), throwsA(_rpcError('not_admin')));
    });

    test('status before anyone is called uses the default estimate', () async {
      final later = aliceTicket.number < bobTicket.number ? bob : alice;
      final status = await later.getMyStatus();
      expect(status.aheadCount, 1);
      expect(status.currentNumber, isNull);
      expect(status.estWaitMinutes, 10);
      expect(status.estimateBasis.name, 'defaultValue');
    });

    test('admin call_next reaches the customer via realtime', () async {
      final aliceSeesCall = _untilEvent(
        aliceEvents.stream,
        () async => (await alice.getMyStatus()).currentNumber == 1,
      );
      expect((await admin.callNext()).number, 1);
      await aliceSeesCall;

      final first = aliceTicket.number == 1 ? alice : bob;
      final second = identical(first, alice) ? bob : alice;
      expect((await first.getMyStatus()).ticket!.status, TicketStatus.called);
      expect((await second.getMyStatus()).aheadCount, 0);
      await expectLater(
        admin.callNext(),
        throwsA(_rpcError('call_in_progress')),
      );
    });

    test('admin sees the session tickets and stats', () async {
      final session = (await admin.getActiveSession())!;
      final tickets = await admin.getSessionTickets(session.id);
      expect(tickets.map((t) => t.number), [1, 2]);
      final stats = await admin.getQueueStats();
      expect(stats.total, 2);
      expect(stats.count(TicketStatus.called), 1);
    });

    test('done -> skip -> recall transitions', () async {
      final session = (await admin.getActiveSession())!;
      final tickets = await admin.getSessionTickets(session.id);
      final one = tickets.firstWhere((t) => t.number == 1);
      final two = tickets.firstWhere((t) => t.number == 2);

      expect(
        (await admin.setTicketStatus(one.id, TicketStatus.done)).status,
        TicketStatus.done,
      );
      await expectLater(
        admin.setTicketStatus(one.id, TicketStatus.called),
        throwsA(_rpcError('invalid_transition')),
      );
      expect(
        (await admin.setTicketStatus(two.id, TicketStatus.skipped)).status,
        TicketStatus.skipped,
      );
      expect(
        (await admin.setTicketStatus(two.id, TicketStatus.called)).status,
        TicketStatus.called,
      );
      await admin.setTicketStatus(two.id, TicketStatus.done);

      final stats = await admin.getQueueStats();
      expect(stats.estimateBasis.name, 'history');
      expect(stats.avgServiceSeconds, 60); // instant service clamps to 1 minute
    });

    test('customer cancels; admin sees it via realtime', () async {
      final ticket = await alice.takeTicket('Alice batal');
      final adminSeesCancel = _untilEvent(adminEvents.stream, () async {
        final session = (await admin.getActiveSession())!;
        final tickets = await admin.getSessionTickets(session.id);
        return tickets.any(
          (t) => t.id == ticket.id && t.status == TicketStatus.cancelled,
        );
      });
      await alice.cancelTicket(ticket.id);
      await adminSeesCancel;
    });

    test('reset restarts numbering and flags old tickets', () async {
      final waiting = await bob.takeTicket('Bob sebelum reset');
      final aliceSeesReset = _untilEvent(
        aliceEvents.stream,
        () async => (await alice.getMyStatus()).wasReset,
      );
      await admin.resetQueue();
      await aliceSeesReset;
      final bobStatus = await bob.getMyStatus();
      expect(bobStatus.ticket!.id, waiting.id);
      expect(bobStatus.ticket!.status, TicketStatus.cancelled);
      expect(bobStatus.wasReset, isTrue);

      expect((await alice.takeTicket('Alice setelah reset')).number, 1);
    });
  });
}
