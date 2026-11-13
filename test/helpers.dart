import 'dart:async';

import 'package:antre/core/notifications.dart';
import 'package:antre/core/theme.dart';
import 'package:antre/features/auth/data/auth_repository.dart';
import 'package:antre/features/queue/data/queue_repository.dart';
import 'package:antre/features/queue/domain/my_status.dart';
import 'package:antre/features/queue/domain/queue_session.dart';
import 'package:antre/features/queue/domain/queue_stats.dart';
import 'package:antre/features/queue/domain/ticket.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockQueueRepository extends Mock implements QueueRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCallNotifier extends Mock implements CallNotifier {}

Ticket ticket({
  int number = 5,
  TicketStatus status = TicketStatus.waiting,
  String name = 'Budi',
}) => Ticket(
  id: 'ticket-$number',
  sessionId: 'session-1',
  number: number,
  customerName: name,
  status: status,
  createdAt: DateTime(2026, 11, 12, 9, 30),
);

MyStatus myStatus({
  TicketStatus status = TicketStatus.waiting,
  int ahead = 2,
  int? current = 3,
  int? est = 20,
  bool sessionActive = true,
}) => MyStatus(
  ticket: ticket(status: status),
  aheadCount: ahead,
  currentNumber: current,
  lastCalledNumber: current,
  sessionActive: sessionActive,
  estWaitMinutes: status == TicketStatus.waiting ? est : null,
  avgServiceSeconds: 600,
);

const session = QueueSession(
  id: 'session-1',
  isActive: true,
  lastNumber: 3,
  waitingCount: 2,
  currentNumber: 1,
  lastCalledNumber: 1,
);

QueueStats stats({int waiting = 2, int total = 3}) => QueueStats(
  counts: {TicketStatus.waiting: waiting},
  total: total,
  estimateBasis: EstimateBasis.defaultValue,
);

Future<void> setUpIntl() => initializeDateFormatting('id_ID');

/// Pumps [child] inside the app theme with mocked providers.
/// Riverpod's automatic retry is off so error states settle immediately.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required List<Override> overrides,
}) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notifier(MockCallNotifier()), ...overrides],
      retry: (_, _) => null,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
    ),
  );
  await tester.pump();
}

/// 360x800dp, the smallest screen the PRD requires.
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// A stream the test controls to simulate realtime events.
StreamController<void> realtimeController() =>
    StreamController<void>.broadcast();

Override queueRepo(MockQueueRepository repo) =>
    queueRepositoryProvider.overrideWithValue(repo);

Override authRepo(MockAuthRepository repo) =>
    authRepositoryProvider.overrideWithValue(repo);

/// Defaults to a no-op mock so tests never touch the notification plugin.
Override notifier(MockCallNotifier mock) {
  when(mock.requestPermission).thenAnswer((_) async {});
  when(
    () => mock.show(
      title: any(named: 'title'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async {});
  return callNotifierProvider.overrideWithValue(mock);
}
