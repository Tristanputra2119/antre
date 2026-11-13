import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications.dart';
import '../../data/queue_repository.dart';
import '../../domain/my_status.dart';
import '../../domain/ticket_status.dart';
import '../status_copy.dart';

/// True when the same ticket moved from waiting to called between two fetches.
bool justCalled(MyStatus? previous, MyStatus next) =>
    previous?.isWaiting == true &&
    next.ticket?.status == TicketStatus.called &&
    next.ticket?.id == previous!.ticket!.id;

final myStatusProvider =
    AsyncNotifierProvider.autoDispose<MyStatusController, MyStatus>(
      MyStatusController.new,
    );

/// Customer ticket state. Refetches `get_my_status()` on realtime events,
/// channel (re)subscribe, app resume, and every 60s while waiting in foreground.
class MyStatusController extends AsyncNotifier<MyStatus> {
  static const refreshInterval = Duration(seconds: 60);

  Timer? _timer;
  bool _foreground = true;

  QueueRepository get _repo => ref.read(queueRepositoryProvider);

  @override
  Future<MyStatus> build() async {
    final sub = _repo.watchMyQueue().listen((_) => refresh());
    final lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        refresh();
      },
      onHide: () {
        _foreground = false;
        _syncTimer(null);
      },
    );
    ref.onDispose(() {
      sub.cancel();
      lifecycle.dispose();
      _timer?.cancel();
    });

    final status = await _repo.getMyStatus();
    _syncTimer(status);
    return status;
  }

  Future<void> refresh() async {
    final previous = state.value;
    final next = await AsyncValue.guard(_repo.getMyStatus);
    if (!ref.mounted) return;
    state = next; // on error Riverpod keeps the previous value alongside it
    _syncTimer(state.value);
    final status = next.value;
    // Also in the foreground: the sound/vibration matters while the phone sits idle.
    if (status != null && justCalled(previous, status)) {
      final message = statusMessage(status);
      await ref
          .read(callNotifierProvider)
          .show(
            title: '${message.title} Nomor ${status.ticket!.number}',
            body: message.body,
          );
    }
  }

  Future<void> takeTicket(String name) async {
    await _repo.takeTicket(name);
    await ref.read(callNotifierProvider).requestPermission();
    await refresh();
  }

  Future<void> cancelTicket() async {
    final ticket = state.value?.ticket;
    if (ticket == null) return;
    await _repo.cancelTicket(ticket.id);
    await refresh();
  }

  void _syncTimer(MyStatus? status) {
    final shouldRun =
        _foreground && (status?.isWaiting ?? false) && !status!.wasReset;
    if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(refreshInterval, (_) => refresh());
    }
  }
}
