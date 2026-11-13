import 'package:intl/intl.dart';

import '../domain/my_status.dart';
import '../domain/ticket.dart';
import '../domain/ticket_status.dart';

/// Pure UI text helpers (kept out of widgets for tests).

final _clock = DateFormat('HH.mm', 'id_ID');

String formatClock(DateTime time) => _clock.format(time.toLocal());

/// Headline + supporting line under the ticket.
({String title, String body}) statusMessage(MyStatus status) {
  if (status.wasReset) {
    return (title: 'Antrean telah direset.', body: 'Silakan ambil nomor baru.');
  }
  return switch (status.ticket!.status) {
    TicketStatus.waiting => (
      title: status.aheadCount == 0
          ? 'Anda berikutnya.'
          : 'Ada ${status.aheadCount} orang di depan Anda.',
      body:
          'Kami akan menampilkan pemberitahuan di sini saat giliran Anda tiba.',
    ),
    TicketStatus.called => (
      title: 'Giliran Anda!',
      body: 'Silakan menuju kursi cukur.',
    ),
    TicketStatus.done => (
      title: 'Potong rambut selesai.',
      body: 'Terima kasih sudah datang.',
    ),
    TicketStatus.skipped => (
      title: 'Nomor Anda dilewati.',
      body: 'Silakan hubungi kapster.',
    ),
    TicketStatus.cancelled => (
      title: 'Antrean dibatalkan.',
      body: 'Anda bisa mengambil nomor baru kapan saja.',
    ),
  };
}

/// "Diambil 09.42", or when it ended: "Selesai 10.07".
String ticketMetaText(Ticket ticket) {
  final finished = ticket.finishedAt;
  if (finished != null && !ticket.status.isActive) {
    final verb = switch (ticket.status) {
      TicketStatus.done => 'Selesai',
      TicketStatus.skipped => 'Dilewati',
      _ => 'Dibatalkan',
    };
    return '$verb ${formatClock(finished)}';
  }
  return 'Diambil ${formatClock(ticket.createdAt)}';
}

/// Null when no estimate should be shown (ticket not waiting).
/// [clock] is absent for the "soon" cases where a time would be noise.
({String title, String? clock})? waitEstimate(MyStatus status, DateTime now) {
  final minutes = status.estWaitMinutes;
  if (!status.isWaiting || status.wasReset || minutes == null) return null;

  if (status.aheadCount == 0 && status.currentNumber == null) {
    return (title: 'Sebentar lagi giliran Anda', clock: null);
  }
  if (minutes < 5) return (title: 'Kurang dari 5 menit lagi', clock: null);

  final at = _clock.format(now.add(Duration(minutes: minutes)));
  return (title: 'Sekitar $minutes menit lagi', clock: 'sekitar pukul $at');
}

String estimateBasisText(EstimateBasis basis) => switch (basis) {
  EstimateBasis.history => 'Berdasarkan rata-rata layanan hari ini',
  EstimateBasis.defaultValue => 'Perkiraan awal, belum ada data hari ini',
};

/// Admin summary: "–" until there is real service history.
String avgServiceText(int? seconds, EstimateBasis basis) {
  if (seconds == null || basis == EstimateBasis.defaultValue) return '–';
  return '${(seconds / 60).round()} menit';
}
