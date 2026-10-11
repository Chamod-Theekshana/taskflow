enum SyncPhase { idle, syncing, offline, error }

/// What the sync engine is doing, for the small status line in Profile and
/// the offline hint in the header.
class SyncStatus {
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? message;

  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.message,
  });

  bool get isOffline => phase == SyncPhase.offline;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? message,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: message,
  );
}
