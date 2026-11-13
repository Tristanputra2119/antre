import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/router.dart';
import '../../../../core/theme.dart';
import '../../../../shared/widgets/async_views.dart';
import '../../../../shared/widgets/bottom_actions.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/ticket_card.dart';
import '../../domain/my_status.dart';
import '../../domain/ticket_status.dart';
import '../status_copy.dart';
import 'my_status_controller.dart';
import 'position_panel.dart';
import 'take_ticket_view.dart';

/// `/queue`: the ticket status, or the take-ticket screen if there is none.
class CustomerQueuePage extends ConsumerWidget {
  const CustomerQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myStatusProvider);
    final status = async.value;

    if (status == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Antrean Anda')),
        body: async.hasError
            ? ErrorView(
                error: async.error!,
                onRetry: () => ref.invalidate(myStatusProvider),
              )
            : const LoadingView(),
      );
    }
    if (status.ticket == null) return const TakeTicketView();
    return _TicketStatusScreen(status: status, stale: async.hasError);
  }
}

/// `/queue/take`: take a new ticket after the previous one ended.
class TakeTicketPage extends StatelessWidget {
  const TakeTicketPage({super.key});

  @override
  Widget build(BuildContext context) =>
      TakeTicketView(onTaken: () => context.pop());
}

class _TicketStatusScreen extends ConsumerWidget {
  const _TicketStatusScreen({required this.status, required this.stale});

  final MyStatus status;

  /// The last refresh failed; [status] is the previous good value.
  final bool stale;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Batalkan nomor ${status.ticket!.number}?',
      message: 'Nomor ini tidak bisa dipakai lagi.',
      dismissLabel: 'Tetap antre',
      confirmLabel: 'Batalkan nomor',
    );
    if (!ok) return;
    try {
      await ref.read(myStatusProvider.notifier).cancelTicket();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final ticket = status.ticket!;
    final called = ticket.status == TicketStatus.called && !status.wasReset;
    final waiting = status.isWaiting && !status.wasReset;
    final message = statusMessage(status);

    return Scaffold(
      appBar: AppBar(
        // Per design: no back arrow here; system back still works.
        automaticallyImplyLeading: false,
        titleSpacing: kScreenPadding,
        title: const Text('Antrean Anda'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: ref.read(myStatusProvider.notifier).refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Keeps the last lines clear of the system navigation bar.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (stale) const OfflineBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: ref.read(myStatusProvider.notifier).refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    kScreenPadding,
                    8,
                    kScreenPadding,
                    16,
                  ),
                  children: [
                    TicketCard(
                      number: '${ticket.number}',
                      name: ticket.customerName,
                      meta: ticketMetaText(ticket),
                      status: ticket.status,
                      called: called,
                      used: !called && !waiting,
                    ),
                    const SizedBox(height: 16),
                    if (waiting) ...[
                      PositionPanel(status: status),
                      const SizedBox(height: 16),
                    ],
                    Semantics(
                      liveRegion: true,
                      child: called
                          ? _CalledMessage(message: message)
                          : _StatusMessage(message: message),
                    ),
                  ],
                ),
              ),
            ),
            if (waiting)
              BottomActions(
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.cancelledTint,
                      foregroundColor: t.cancelled,
                    ),
                    onPressed: () => _cancel(context, ref),
                    child: const Text('Batalkan antrean'),
                  ),
                ],
              )
            else if (status.canTakeNewTicket)
              BottomActions(
                children: [
                  OutlinedButton(
                    onPressed: () => context.push(Routes.takeTicket),
                    child: const Text('Ambil nomor baru'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final ({String title, String body}) message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message.title, style: context.text.titleMedium),
        const SizedBox(height: 4),
        Text(
          message.body,
          style: context.text.bodyLarge!.copyWith(
            color: context.tokens.inkMuted,
          ),
        ),
      ],
    ),
  );
}

class _CalledMessage extends StatelessWidget {
  const _CalledMessage({required this.message});

  final ({String title, String body}) message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.campaign_outlined, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.title, style: context.text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                message.body,
                style: context.text.bodyLarge!.copyWith(
                  color: context.tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
