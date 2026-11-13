import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/ticket_card.dart';
import '../domain/ticket_status.dart';

/// Shown as the home headline; set per business with --dart-define.
const businessName = String.fromEnvironment(
  'BUSINESS_NAME',
  defaultValue: 'Antre',
);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                48,
                kScreenPadding,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(businessName, style: context.text.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    'Ambil nomor dan pantau giliran dari HP Anda.',
                    style: context.text.bodyLarge!.copyWith(
                      color: context.tokens.inkMuted,
                    ),
                  ),
                  const Expanded(child: _TicketIllustration()),
                ],
              ),
            ),
          ),
          BottomActions(
            children: [
              FilledButton(
                onPressed: () => context.push(Routes.queue),
                child: const Text('Ambil nomor'),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.tokens.inkMuted,
                ),
                onPressed: () => context.push(Routes.admin),
                child: const Text('Masuk sebagai kapster'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Decorative tilted sample ticket.
class _TicketIllustration extends StatelessWidget {
  const _TicketIllustration();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // A picture, not content: it must not reflow with the system font size.
    child: MediaQuery.withNoTextScaling(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Transform.rotate(
              angle: -0.105, // 6°
              child: const SizedBox(
                width: 200,
                child: TicketCard(
                  label: 'Nomor antrean',
                  number: '1',
                  numberSize: 112,
                  name: 'Nama Anda',
                  meta: '09.41',
                  status: TicketStatus.waiting,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
