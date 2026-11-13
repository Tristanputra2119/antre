/// Mirrors the Postgres enum `ticket_status`; names must match exactly.
enum TicketStatus {
  waiting,
  called,
  done,
  skipped,
  cancelled;

  static TicketStatus fromJson(String value) =>
      TicketStatus.values.byName(value);

  bool get isActive => this == waiting || this == called;
}
