import 'package:antre/features/queue/domain/my_status.dart';
import 'package:antre/features/queue/domain/queue_stats.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> ticketJson({String status = 'waiting'}) => {
  'id': 't1',
  'session_id': 's1',
  'number': 7,
  'customer_name': 'Budi',
  'user_id': 'u1',
  'status': status,
  'created_at': '2026-11-12T02:00:00+00:00',
  'called_at': null,
  'finished_at': null,
};

void main() {
  test('TicketStatus mirrors the Postgres enum', () {
    expect(TicketStatus.values.map((s) => s.name), [
      'waiting',
      'called',
      'done',
      'skipped',
      'cancelled',
    ]);
  });

  test('MyStatus parses get_my_status() payload', () {
    final status = MyStatus.fromJson({
      'ticket': ticketJson(),
      'ahead_count': 3,
      'current_number': 4,
      'last_called_number': 4,
      'session_active': true,
      'est_wait_minutes': 35,
      'avg_service_seconds': 600,
      'estimate_basis': 'history',
    });

    expect(status.ticket!.number, 7);
    expect(status.ticket!.createdAt.isUtc, isTrue);
    expect(status.aheadCount, 3);
    expect(status.estimateBasis, EstimateBasis.history);
    expect(status.isWaiting, isTrue);
    expect(status.canTakeNewTicket, isFalse);
  });

  test('MyStatus without a ticket allows taking one', () {
    final status = MyStatus.fromJson({'ticket': null});
    expect(status.ticket, isNull);
    expect(status.canTakeNewTicket, isTrue);
  });

  test('a reset session allows a new ticket even if the old one is active', () {
    final status = MyStatus.fromJson({
      'ticket': ticketJson(),
      'session_active': false,
    });
    expect(status.wasReset, isTrue);
    expect(status.canTakeNewTicket, isTrue);
  });

  test('QueueStats parses counts per status', () {
    final stats = QueueStats.fromJson({
      'counts': {'waiting': 2, 'done': 5},
      'total': 7,
      'avg_service_seconds': null,
      'estimate_basis': 'default',
    });
    expect(stats.count(TicketStatus.waiting), 2);
    expect(stats.count(TicketStatus.called), 0);
    expect(stats.estimateBasis, EstimateBasis.defaultValue);
  });
}
