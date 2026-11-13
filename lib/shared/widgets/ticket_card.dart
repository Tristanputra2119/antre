import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../features/queue/domain/ticket_status.dart';
import 'status_chip.dart';

/// The paper-ticket card: big number, perforation with side notches, and a
/// stub with the customer's name and status.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.number,
    required this.name,
    required this.meta,
    required this.status,
    this.label = 'Nomor antrean Anda',
    this.called = false,
    this.used = false,
    this.numberSize = 128,
  });

  final String number;
  final String name;
  final String meta;
  final TicketStatus status;
  final String label;

  /// Yellow "your turn" treatment.
  final bool called;

  /// Finished/voided ticket: muted number with a diagonal strike.
  final bool used;
  final double numberSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;
    final foreground = called ? t.onSignal : t.ink;
    final muted = called ? t.onSignal : t.inkMuted;
    final radius = BorderRadius.circular(AppRadius.ticket);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: called
                ? t.signal.withValues(alpha: 0.35)
                : AppTokens.shadow.withValues(alpha: used ? 0.04 : 0.08),
            offset: Offset(0, used ? 4 : 8),
            blurRadius: used ? 12 : 24,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: called ? t.signal : t.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomPaint(
                foregroundPainter: used ? _StrikePainter(t.rule) : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: text.bodyMedium!.copyWith(color: muted),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          number,
                          semanticsLabel: 'Nomor antrean $number',
                          style: t.number(
                            numberSize,
                            color: used ? t.inkMuted : foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 24,
                child: CustomPaint(
                  painter: _PerforationPainter(
                    dash: called ? t.onSignal.withValues(alpha: 0.3) : t.rule,
                    notch: t.paper,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium!.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 8),
                    // Wrap so the chip drops below the time at large font sizes.
                    SizedBox(
                      width: double
                          .infinity, // lets spaceBetween push the chip right
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4, // spaceBetween already separates them on one line
                        runSpacing: 8,
                        children: [
                          Text(
                            meta,
                            style: text.bodyMedium!.copyWith(color: muted),
                          ),
                          StatusChip(status, onSignalSurface: called),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed tear line with a half-circle notch cut into each side.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter({required this.dash, required this.notch});

  final Color dash;
  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..color = dash
      ..strokeWidth = 1;
    for (var x = 20.0; x < size.width - 20; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 6, y), line);
    }
    final hole = Paint()..color = notch;
    canvas
      ..drawCircle(Offset(0, y), 12, hole)
      ..drawCircle(Offset(size.width, y), 12, hole);
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.dash != dash || old.notch != notch;
}

class _StrikePainter extends CustomPainter {
  const _StrikePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawLine(
    Offset(0, size.height),
    Offset(size.width, 0),
    Paint()
      ..color = color
      ..strokeWidth = 1,
  );

  @override
  bool shouldRepaint(_StrikePainter old) => old.color != color;
}
