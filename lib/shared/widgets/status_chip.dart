import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../features/queue/domain/ticket_status.dart';

extension TicketStatusUi on TicketStatus {
  String get label => switch (this) {
    TicketStatus.waiting => 'Menunggu',
    TicketStatus.called => 'Dipanggil',
    TicketStatus.done => 'Selesai',
    TicketStatus.skipped => 'Dilewati',
    TicketStatus.cancelled => 'Dibatalkan',
  };

  IconData get icon => switch (this) {
    TicketStatus.waiting => Icons.schedule,
    TicketStatus.called => Icons.campaign_outlined,
    TicketStatus.done => Icons.check_circle_outline,
    TicketStatus.skipped => Icons.redo,
    TicketStatus.cancelled => Icons.cancel_outlined,
  };
}

/// Status pill: always icon + text, never color alone.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.onSignalSurface = false});

  final TicketStatus status;

  /// On the yellow "called" ticket the chip inverts so it stays visible.
  final bool onSignalSurface;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (background, foreground) = switch (status) {
      TicketStatus.waiting => (t.chipWaiting, t.ink),
      TicketStatus.called when onSignalSurface => (t.onSignal, t.signal),
      TicketStatus.called => (t.signal, t.onSignal),
      TicketStatus.done => (t.doneTint, t.done),
      TicketStatus.skipped => (t.skippedTint, t.skipped),
      TicketStatus.cancelled => (t.cancelledTint, t.cancelled),
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: context.text.labelMedium!.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
