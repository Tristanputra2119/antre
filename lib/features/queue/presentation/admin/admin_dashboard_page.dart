import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/async_views.dart';
import '../../../../shared/widgets/bottom_actions.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/ticket.dart';
import '../../domain/ticket_status.dart';
import '../status_copy.dart';
import 'admin_queue_controller.dart';
import 'queue_row.dart';
import 'ticket_action_sheet.dart';

/// List filters; null means "Semua".
const _filters = <TicketStatus?>[null, ...TicketStatus.values];

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  TicketStatus? _filter;

  AdminQueueController get _controller => ref.read(adminQueueProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _reset(int waiting) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reset antrean?',
      message:
          '${waiting > 0 ? 'Masih ada $waiting orang menunggu. ' : ''}'
          'Semua nomor aktif akan dibatalkan dan penomoran mulai lagi dari 1.',
      dismissLabel: 'Batal',
      confirmLabel: 'Reset',
    );
    if (ok) await _run(_controller.reset);
  }

  Future<void> _openTicket(Ticket ticket, {required bool canRecall}) async {
    final target = await showTicketActionSheet(
      context,
      ticket: ticket,
      canRecall: canRecall,
    );
    if (target != null) await _run(() => _controller.setStatus(ticket, target));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminQueueProvider);
    final data = async.value;

    return Scaffold(
      appBar: AppBar(
        // Per design: no back arrow here; system back still works.
        automaticallyImplyLeading: false,
        titleSpacing: kScreenPadding,
        title: const Text('Antrean hari ini'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => switch (value) {
              'reset' => _reset(data?.waitingCount ?? 0),
              _ => _run(ref.read(authRepositoryProvider).signOut),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                enabled: data != null,
                child: const Text('Reset antrean'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: data == null
          ? (async.hasError
                ? ErrorView(
                    error: async.error!,
                    onRetry: () => ref.invalidate(adminQueueProvider),
                  )
                : const LoadingView())
          : Column(
              children: [
                if (async.hasError) const OfflineBanner(),
                Expanded(child: _buildList(data)),
                _CallNextBar(
                  state: data,
                  onPressed: () => _run(_controller.callNext),
                ),
              ],
            ),
    );
  }

  Widget _buildList(AdminQueueState data) {
    final called = data.tickets
        .where((t) => t.status == TicketStatus.called)
        .firstOrNull;
    final tickets = _filter == null
        ? data.tickets
        : data.tickets.where((t) => t.status == _filter).toList();
    const side = EdgeInsets.symmetric(horizontal: kScreenPadding);

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        if (called != null) ...[
          Padding(
            padding: side,
            child: _CurrentCard(
              ticket: called,
              onDone: () =>
                  _run(() => _controller.setStatus(called, TicketStatus.done)),
              onSkip: () => _run(
                () => _controller.setStatus(called, TicketStatus.skipped),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: side,
          child: Text(
            '${data.waitingCount} menunggu  ·  ${data.stats.total} total\n'
            'Rata-rata layanan '
            '${avgServiceText(data.stats.avgServiceSeconds, data.stats.estimateBasis)}',
            style: context.text.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: side,
          child: Row(
            children: [
              for (final filter in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label:
                        '${filter?.label ?? 'Semua'} '
                        '${filter == null ? data.stats.total : data.stats.count(filter)}',
                    selected: filter == _filter,
                    onTap: () => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(padding: side, child: Divider()),
        if (tickets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Belum ada tiket',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ),
        for (final ticket in tickets)
          Padding(
            padding: side,
            child: QueueRow(
              ticket: ticket,
              onTap: () => _openTicket(ticket, canRecall: !data.hasCalled),
            ),
          ),
      ],
    );
  }
}

/// The ticket being served, with its two primary actions.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.ticket,
    required this.onDone,
    required this.onSkip,
  });

  final Ticket ticket;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
    );
    final calledAt = ticket.calledAt;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.signal,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sedang dipanggil',
            style: text.labelMedium!.copyWith(color: t.onSignal),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${ticket.number}', style: t.number(80, color: t.onSignal)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium!.copyWith(color: t.onSignal),
                    ),
                    if (calledAt != null)
                      Text(
                        'Dipanggil ${formatClock(calledAt)}',
                        style: text.bodyMedium!.copyWith(color: t.onSignal),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.done,
                    foregroundColor: t.onDone,
                    minimumSize: const Size.fromHeight(48),
                    shape: shape,
                  ),
                  onPressed: onDone,
                  child: const Text('Selesai'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.onSignal,
                    side: BorderSide(color: t.onSignal),
                    minimumSize: const Size.fromHeight(48),
                    shape: shape,
                  ),
                  onPressed: onSkip,
                  child: const Text('Lewati'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final foreground = selected ? t.onPrimary : t.ink;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        // 32dp chip inside a 48dp touch target.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? t.ink : null,
              border: selected ? null : Border.all(color: t.rule),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: context.text.labelMedium!.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallNextBar extends StatelessWidget {
  const _CallNextBar({required this.state, required this.onPressed});

  final AdminQueueState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hint = switch (state) {
      _ when state.hasCalled =>
        'Selesaikan atau lewati nomor ${state.session?.currentNumber} dulu.',
      _ when state.waitingCount == 0 => 'Tidak ada antrean yang menunggu.',
      _ => null,
    };

    return BottomActions(
      divided: true,
      children: [
        if (hint != null) ...[
          Text(
            hint,
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: hint == null ? onPressed : null,
          child: const Text('Panggil berikutnya'),
        ),
      ],
    );
  }
}
