import 'package:antre/features/queue/domain/my_status.dart';
import 'package:antre/features/queue/domain/ticket_status.dart';
import 'package:antre/features/queue/presentation/customer/my_status_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers.dart';

void main() {
  final waiting = myStatus();
  final called = myStatus(status: TicketStatus.called);

  test('waiting -> called on the same ticket notifies', () {
    expect(justCalled(waiting, called), isTrue);
  });

  test('first load, repeat refresh, or other transitions do not notify', () {
    expect(justCalled(null, called), isFalse);
    expect(justCalled(called, called), isFalse);
    expect(
      justCalled(waiting, myStatus(status: TicketStatus.skipped)),
      isFalse,
    );
    expect(justCalled(const MyStatus(), called), isFalse);
  });

  test('a different ticket being called does not notify', () {
    final other = MyStatus(
      ticket: ticket(number: 9, status: TicketStatus.called),
    );
    expect(justCalled(waiting, other), isFalse);
  });
}
