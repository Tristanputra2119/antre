import 'ticket_status.dart';

class Ticket {
  const Ticket({
    required this.id,
    required this.sessionId,
    required this.number,
    required this.customerName,
    required this.status,
    required this.createdAt,
    this.calledAt,
    this.finishedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['id'] as String,
    sessionId: json['session_id'] as String,
    number: json['number'] as int,
    customerName: json['customer_name'] as String,
    status: TicketStatus.fromJson(json['status'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    calledAt: _parseDate(json['called_at']),
    finishedAt: _parseDate(json['finished_at']),
  );

  final String id;
  final String sessionId;
  final int number;
  final String customerName;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? calledAt;
  final DateTime? finishedAt;

  Ticket copyWith({
    TicketStatus? status,
    DateTime? calledAt,
    DateTime? finishedAt,
  }) => Ticket(
    id: id,
    sessionId: sessionId,
    number: number,
    customerName: customerName,
    status: status ?? this.status,
    createdAt: createdAt,
    calledAt: calledAt ?? this.calledAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
