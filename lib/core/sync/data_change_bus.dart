import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which part of the data changed.
enum DataScope { tasks, settings }

/// Connects the features to the sync engine without them depending on it:
///
/// * features report local edits (`localChanged`) so they get pushed,
/// * the sync engine reports pulled data (`remoteChanged`) so the screens
///   reload,
/// * anyone can ask for a sync right now (`syncNow`, e.g. pull-to-refresh).
class DataChangeBus {
  final _local = StreamController<DataScope>.broadcast();
  final _remote = StreamController<DataScope>.broadcast();
  Future<void> Function()? _syncHandler;

  Stream<DataScope> get localChanges => _local.stream;
  Stream<DataScope> get remoteChanges => _remote.stream;

  void localChanged(DataScope scope) => _local.add(scope);
  void remoteChanged(DataScope scope) => _remote.add(scope);

  /// Registered by the sync controller while someone is signed in.
  void attachSync(Future<void> Function()? handler) => _syncHandler = handler;

  /// Runs a sync and completes when it is done (immediately when signed out).
  Future<void> syncNow() => _syncHandler?.call() ?? Future<void>.value();

  void dispose() {
    _local.close();
    _remote.close();
  }
}

final dataChangeBusProvider = Provider<DataChangeBus>((ref) {
  final bus = DataChangeBus();
  ref.onDispose(bus.dispose);
  return bus;
});
