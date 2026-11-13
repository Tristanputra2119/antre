import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';
import '../../domain/my_status.dart';
import '../status_copy.dart';

/// Where the customer stands: now serving, people ahead, and the wait estimate.
class PositionPanel extends StatelessWidget {
  const PositionPanel({super.key, required this.status});

  final MyStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final estimate = waitEstimate(status, DateTime.now());
    final (servingLabel, servingValue) = switch (status) {
      MyStatus(currentNumber: final n?) => ('Sedang dilayani', '$n'),
      MyStatus(lastCalledNumber: final n?) => ('Terakhir dipanggil', '$n'),
      _ => ('Sedang dilayani', '–'),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Figure(label: servingLabel, value: servingValue),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: VerticalDivider(width: 1, color: t.rule),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Di depan Anda',
                    value: '${status.aheadCount}',
                    unit: 'orang',
                  ),
                ),
              ],
            ),
          ),
          if (estimate != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.timer_outlined, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(estimate.title, style: context.text.titleMedium),
                        if (estimate.clock != null) ...[
                          const SizedBox(height: 2),
                          Text(estimate.clock!, style: context.text.bodyMedium),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          estimateBasisText(status.estimateBasis),
                          style: context.text.labelMedium!.copyWith(
                            color: t.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One line always, so both figures share a baseline.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: context.text.bodyMedium),
        ),
        const SizedBox(height: 8),
        // Scales down instead of overflowing with long numbers or large text.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: context.tokens.number(56)),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit!, style: context.text.bodyMedium),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
