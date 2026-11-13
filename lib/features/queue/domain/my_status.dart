import 'ticket.dart';
import 'ticket_status.dart';

enum EstimateBasis {
  history,
  defaultValue;

  static EstimateBasis fromJson(String? value) =>
      value == 'history' ? history : defaultValue;
}

/// Result of the `get_my_status()` RPC.
class MyStatus {
  const MyStatus({
    this.ticket,
    this.aheadCount = 0,
    this.currentNumber,
    this.lastCalledNumber,
    this.sessionActive = true,
    this.estWaitMinutes,
    this.avgServiceSeconds,
    this.estimateBasis = EstimateBasis.defaultValue,
  });

  factory MyStatus.fromJson(Map<String, dynamic> json) {
    final ticket = json['ticket'] as Map<String, dynamic>?;
    return MyStatus(
      ticket: ticket == null ? null : Ticket.fromJson(ticket),
      aheadCount: json['ahead_count'] as int? ?? 0,
      currentNumber: json['current_number'] as int?,
      lastCalledNumber: json['last_called_number'] as int?,
      sessionActive: json['session_active'] as bool? ?? true,
      estWaitMinutes: json['est_wait_minutes'] as int?,
      avgServiceSeconds: json['avg_service_seconds'] as int?,
      estimateBasis: EstimateBasis.fromJson(json['estimate_basis'] as String?),
    );
  }

  final Ticket? ticket;
  final int aheadCount;
  final int? currentNumber;
  final int? lastCalledNumber;
  final bool sessionActive;
  final int? estWaitMinutes;
  final int? avgServiceSeconds;
  final EstimateBasis estimateBasis;

  bool get isWaiting => ticket?.status == TicketStatus.waiting;

  /// Ticket belongs to a session the admin has already reset.
  bool get wasReset => ticket != null && !sessionActive;

  bool get canTakeNewTicket =>
      ticket == null || wasReset || !ticket!.status.isActive;
}
