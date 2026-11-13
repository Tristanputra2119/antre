import 'package:antre/features/queue/domain/my_status.dart';
import 'package:antre/features/queue/domain/ticket.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:antre/features/queue/presentation/status_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

MyStatus statusWith({
  TicketStatus ticketStatus = TicketStatus.waiting,
  int ahead = 0,
  int? current,
  int? lastCalled,
  int? est,
  bool sessionActive = true,
}) => MyStatus(
  ticket: Ticket(
    id: 't1',
    sessionId: 's1',
    number: 9,
    customerName: 'Sari',
    status: ticketStatus,
    createdAt: DateTime(2026, 11, 12, 9),
  ),
  aheadCount: ahead,
  currentNumber: current,
  lastCalledNumber: lastCalled,
  estWaitMinutes: est,
  sessionActive: sessionActive,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('statusMessage', () {
    test('waiting shows people ahead', () {
      expect(
        statusMessage(statusWith(ahead: 3)).title,
        'Ada 3 orang di depan Anda.',
      );
      expect(statusMessage(statusWith()).title, 'Anda berikutnya.');
    });

    test('each status has its headline', () {
      String title(TicketStatus s) =>
          statusMessage(statusWith(ticketStatus: s)).title;
      expect(title(TicketStatus.called), 'Giliran Anda!');
      expect(title(TicketStatus.done), 'Potong rambut selesai.');
      expect(title(TicketStatus.skipped), 'Nomor Anda dilewati.');
      expect(title(TicketStatus.cancelled), 'Antrean dibatalkan.');
    });

    test('reset session overrides the ticket status', () {
      expect(
        statusMessage(statusWith(sessionActive: false)).title,
        'Antrean telah direset.',
      );
    });
  });

  group('waitEstimate', () {
    final now = DateTime(2026, 11, 12, 9, 50);

    test('formats minutes and clock time', () {
      final estimate = waitEstimate(
        statusWith(ahead: 2, current: 5, est: 25),
        now,
      )!;
      expect(estimate.title, 'Sekitar 25 menit lagi');
      expect(estimate.clock, 'sekitar pukul 10.15');
    });

    test('under 5 minutes', () {
      final estimate = waitEstimate(statusWith(current: 5, est: 3), now)!;
      expect(estimate.title, 'Kurang dari 5 menit lagi');
      expect(estimate.clock, isNull);
    });

    test('nobody ahead and nobody called', () {
      expect(
        waitEstimate(statusWith(est: 0), now)!.title,
        'Sebentar lagi giliran Anda',
      );
    });

    test('hidden when not waiting or session reset', () {
      expect(
        waitEstimate(
          statusWith(ticketStatus: TicketStatus.called, est: 10),
          now,
        ),
        isNull,
      );
      expect(
        waitEstimate(statusWith(est: 10, sessionActive: false), now),
        isNull,
      );
    });
  });

  test('ticket meta shows when it was taken or ended', () {
    final taken = statusWith().ticket!;
    expect(ticketMetaText(taken), 'Diambil 09.00');
    final done = Ticket(
      id: 't',
      sessionId: 's',
      number: 1,
      customerName: 'A',
      status: TicketStatus.done,
      createdAt: DateTime(2026, 11, 12, 9),
      finishedAt: DateTime(2026, 11, 12, 10, 7),
    );
    expect(ticketMetaText(done), 'Selesai 10.07');
  });

  test('estimate basis and admin average texts', () {
    expect(
      estimateBasisText(EstimateBasis.history),
      'Berdasarkan rata-rata layanan hari ini',
    );
    expect(
      estimateBasisText(EstimateBasis.defaultValue),
      'Perkiraan awal, belum ada data hari ini',
    );
    expect(avgServiceText(null, EstimateBasis.defaultValue), '–');
    expect(avgServiceText(450, EstimateBasis.history), '8 menit');
  });
}
