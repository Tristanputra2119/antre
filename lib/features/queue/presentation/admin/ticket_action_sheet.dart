import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/ticket.dart';
import '../../domain/ticket_status.dart';
import '../status_copy.dart';

/// Shows a ticket's timeline and the transitions allowed for its status
/// (PRD 8.4). Resolves to the chosen target status, or null if dismissed.
Future<TicketStatus?> showTicketActionSheet(
  BuildContext context, {
  required Ticket ticket,
  required bool canRecall,
}) => showModalBottomSheet<TicketStatus>(
  context: context,
  isScrollControlled: true,
  builder: (context) =>
      _TicketActionSheet(ticket: ticket, canRecall: canRecall),
);

class _TicketActionSheet extends StatelessWidget {
  const _TicketActionSheet({required this.ticket, required this.canRecall});

  final Ticket ticket;

  /// False while another ticket is being called.
  final bool canRecall;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final actions = switch (ticket.status) {
      TicketStatus.called => [
        (TicketStatus.done, 'Selesai', Icons.check_circle_outline, t.done),
        (TicketStatus.skipped, 'Lewati', Icons.redo, t.skipped),
      ],
      TicketStatus.waiting => [
        (TicketStatus.skipped, 'Lewati', Icons.redo, t.skipped),
      ],
      TicketStatus.skipped when canRecall => [
        (TicketStatus.called, 'Panggil ulang', Icons.campaign_outlined, t.ink),
      ],
      _ => const <(TicketStatus, String, IconData, Color)>[],
    };
    final endLabel = switch (ticket.status) {
      TicketStatus.skipped => 'Dilewati',
      TicketStatus.cancelled => 'Dibatalkan',
      _ => 'Selesai',
    };
    String clock(DateTime? time) => time == null ? '–' : formatClock(time);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Text('${ticket.number}', style: t.number(56)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.customerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      StatusChip(ticket.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _TimeColumn('Diambil', clock(ticket.createdAt)),
                _TimeColumn('Dipanggil', clock(ticket.calledAt)),
                _TimeColumn(endLabel, clock(ticket.finishedAt)),
              ],
            ),
          ),
          const Divider(),
          if (actions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Tidak ada aksi untuk tiket ini.',
                style: context.text.bodyMedium,
              ),
            ),
          for (final (target, label, icon, color) in actions)
            InkWell(
              onTap: () => Navigator.pop(context, target),
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 16),
                      Text(label, style: context.text.labelLarge),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: context.text.labelMedium!.copyWith(
          color: context.tokens.inkMuted,
        ),
      ),
      const SizedBox(height: 2),
      Text(value, style: context.text.bodyLarge),
    ],
  );
}
