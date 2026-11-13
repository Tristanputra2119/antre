import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/ticket.dart';
import '../../domain/ticket_status.dart';
import '../status_copy.dart';

/// One ticket in the admin list; tapping opens its action sheet.
class QueueRow extends StatelessWidget {
  const QueueRow({super.key, required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final called = ticket.status == TicketStatus.called;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.rule)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: called ? t.signal : null,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${ticket.number}',
                textAlign: TextAlign.right,
                style: t.number(28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  Text(
                    formatClock(ticket.createdAt),
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(ticket.status),
          ],
        ),
      ),
    );
  }
}
