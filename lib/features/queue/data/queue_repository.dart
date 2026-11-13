import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../domain/my_status.dart';
import '../domain/queue_session.dart';
import '../domain/queue_stats.dart';
import '../domain/ticket.dart';
import '../domain/ticket_status.dart';

final queueRepositoryProvider = Provider<QueueRepository>(
  (ref) => QueueRepository(ref.watch(supabaseClientProvider)),
);

/// Reads go straight to tables (guarded by RLS); every write is an RPC.
class QueueRepository {
  QueueRepository(this._client);

  final SupabaseClient _client;

  // ---- customer

  Future<Ticket> takeTicket(String name) async => Ticket.fromJson(
    await _client.rpc('take_ticket', params: {'p_name': name.trim()}),
  );

  Future<Ticket> cancelTicket(String ticketId) async => Ticket.fromJson(
    await _client.rpc('cancel_ticket', params: {'p_ticket_id': ticketId}),
  );

  Future<MyStatus> getMyStatus() async => MyStatus.fromJson(
    await _client.rpc('get_my_status') as Map<String, dynamic>,
  );

  // ---- admin

  Future<QueueSession?> getActiveSession() async {
    final row = await _client
        .from('queue_sessions')
        .select()
        .eq('is_active', true)
        .maybeSingle();
    return row == null ? null : QueueSession.fromJson(row);
  }

  Future<List<Ticket>> getSessionTickets(String sessionId) async {
    final rows = await _client
        .from('tickets')
        .select()
        .eq('session_id', sessionId)
        .order('number', ascending: true);
    return rows.map(Ticket.fromJson).toList();
  }

  Future<QueueStats> getQueueStats() async => QueueStats.fromJson(
    await _client.rpc('get_queue_stats') as Map<String, dynamic>,
  );

  Future<Ticket> callNext() async =>
      Ticket.fromJson(await _client.rpc('call_next'));

  Future<Ticket> setTicketStatus(String ticketId, TicketStatus status) async =>
      Ticket.fromJson(
        await _client.rpc(
          'set_ticket_status',
          params: {'p_ticket_id': ticketId, 'p_status': status.name},
        ),
      );

  Future<QueueSession> resetQueue() async =>
      QueueSession.fromJson(await _client.rpc('reset_queue'));

  // ---- realtime
  //
  // Each stream emits whenever something relevant changed *and* every time the
  // channel (re)subscribes, so listeners just refetch on every event.
  // Cancelling the subscription removes the channel.

  Stream<void> watchMyQueue() {
    final userId = _client.auth.currentUser!.id;
    return _watch(
      'customer:$userId',
      (channel, emit) => channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'queue_sessions',
            callback: (_) => emit(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tickets',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => emit(),
          ),
    );
  }

  // shortcut: listens to all tickets rather than filtering by the active
  // session_id, so a reset needs no resubscribe; filter if history gets busy.
  Stream<void> watchAdminQueue() => _watch(
    'admin',
    (channel, emit) => channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'queue_sessions',
          callback: (_) => emit(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tickets',
          callback: (_) => emit(),
        ),
  );

  Stream<void> _watch(
    String name,
    RealtimeChannel Function(RealtimeChannel channel, void Function() emit)
    configure,
  ) {
    RealtimeChannel? channel;
    late final StreamController<void> controller;
    void emit() {
      if (!controller.isClosed) controller.add(null);
    }

    controller = StreamController<void>(
      onListen: () {
        channel = configure(_client.channel(name), emit)
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) emit();
          });
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
        await controller.close();
      },
    );
    return controller.stream;
  }
}
