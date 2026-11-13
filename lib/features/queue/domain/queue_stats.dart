import 'my_status.dart';
import 'ticket_status.dart';

/// Result of the admin-only `get_queue_stats()` RPC.
class QueueStats {
  const QueueStats({
    required this.counts,
    required this.total,
    required this.estimateBasis,
    this.avgServiceSeconds,
  });

  factory QueueStats.fromJson(Map<String, dynamic> json) {
    final raw = (json['counts'] as Map<String, dynamic>?) ?? const {};
    return QueueStats(
      counts: {
        for (final e in raw.entries)
          TicketStatus.fromJson(e.key): e.value as int,
      },
      total: json['total'] as int? ?? 0,
      avgServiceSeconds: json['avg_service_seconds'] as int?,
      estimateBasis: EstimateBasis.fromJson(json['estimate_basis'] as String?),
    );
  }

  final Map<TicketStatus, int> counts;
  final int total;
  final int? avgServiceSeconds;
  final EstimateBasis estimateBasis;

  int count(TicketStatus status) => counts[status] ?? 0;
}
