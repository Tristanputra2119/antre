import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/queue_repository.dart';
import '../../domain/queue_session.dart';
import '../../domain/queue_stats.dart';
import '../../domain/ticket.dart';
import '../../domain/ticket_status.dart';

class AdminQueueState {
  const AdminQueueState({
    required this.session,
    required this.tickets,
    required this.stats,
  });

  final QueueSession? session;
  final List<Ticket> tickets;
  final QueueStats stats;

  bool get hasCalled => tickets.any((t) => t.status == TicketStatus.called);
  int get waitingCount => stats.count(TicketStatus.waiting);
}

final adminQueueProvider =
    AsyncNotifierProvider.autoDispose<AdminQueueController, AdminQueueState>(
      AdminQueueController.new,
    );

/// Admin dashboard data, refetched on every realtime event and app resume.
/// Actions rethrow so the UI can show a snackbar.
class AdminQueueController extends AsyncNotifier<AdminQueueState> {
  QueueRepository get _repo => ref.read(queueRepositoryProvider);

  @override
  Future<AdminQueueState> build() {
    final sub = _repo.watchAdminQueue().listen((_) => refresh());
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      sub.cancel();
      lifecycle.dispose();
    });
    return _fetch();
  }

  Future<AdminQueueState> _fetch() async {
    final (session, stats) = await (
      _repo.getActiveSession(),
      _repo.getQueueStats(),
    ).wait;
    final tickets = session == null
        ? <Ticket>[]
        : await _repo.getSessionTickets(session.id);
    return AdminQueueState(session: session, tickets: tickets, stats: stats);
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(_fetch);
    if (ref.mounted) state = next;
  }

  Future<void> callNext() => _act(_repo.callNext);

  Future<void> setStatus(Ticket ticket, TicketStatus status) =>
      _act(() => _repo.setTicketStatus(ticket.id, status));

  Future<void> reset() => _act(_repo.resetQueue);

  Future<void> _act(Future<Object?> Function() action) async {
    await action();
    await refresh(); // don't wait on realtime for the actor's own feedback
  }
}
