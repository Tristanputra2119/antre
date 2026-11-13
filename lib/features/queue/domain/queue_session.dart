class QueueSession {
  const QueueSession({
    required this.id,
    required this.isActive,
    required this.lastNumber,
    required this.waitingCount,
    this.currentNumber,
    this.lastCalledNumber,
  });

  factory QueueSession.fromJson(Map<String, dynamic> json) => QueueSession(
    id: json['id'] as String,
    isActive: json['is_active'] as bool,
    lastNumber: json['last_number'] as int,
    waitingCount: json['waiting_count'] as int,
    currentNumber: json['current_number'] as int?,
    lastCalledNumber: json['last_called_number'] as int?,
  );

  final String id;
  final bool isActive;
  final int lastNumber;
  final int waitingCount;
  final int? currentNumber;
  final int? lastCalledNumber;
}
