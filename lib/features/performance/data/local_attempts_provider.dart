import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_notifier.dart';
import '../../auth/presentation/providers/auth_state.dart';
import 'datasources/performance_local_data_source.dart';
import 'models/local_attempt_record.dart';

/// The signed-in user's id, or `null` — narrowed with `select` so local
/// attempts reload only when the *user* changes, not on every auth state
/// update (a token refresh, a profile edit).
final _currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authNotifierProvider.select(
      (state) => state is AuthAuthenticated ? state.user.id : null,
    ),
  );
});

/// The current user's locally recorded attempts, newest first — the
/// reactive source the mock Performance data source merges with its
/// fixtures (see performance_data_source.dart). Signed out → empty.
///
/// Recording only ever happens through the app-level practice recorder
/// (app/practice_attempt_recorder.dart), and only in mock mode;
/// PerformanceRepository itself stays read-only.
class LocalAttemptsNotifier extends Notifier<List<LocalAttemptRecord>> {
  late PerformanceLocalDataSource _dataSource;
  String? _userId;

  /// Every restore/append runs after the previous one, so a record made
  /// while the stored list is still loading can't be overwritten by it.
  Future<void> _pending = Future.value();

  @override
  List<LocalAttemptRecord> build() {
    _dataSource = ref.watch(performanceLocalDataSourceProvider);
    final userId = ref.watch(_currentUserIdProvider);
    _userId = userId;
    if (userId != null) {
      // Deferred: `state` can't be written while build() is running.
      _pending = Future.microtask(() => _restore(userId));
    }
    return const [];
  }

  Future<void> _restore(String userId) async {
    try {
      final records = await _dataSource.load(userId);
      if (_userId == userId) state = records;
    } catch (_) {
      // Storage unavailable — leave this session's history empty.
    }
  }

  /// Adds [record] for the signed-in user and persists it. A no-op when
  /// signed out, and for an [LocalAttemptRecord.attemptId] already present.
  Future<void> record(LocalAttemptRecord record) {
    final userId = _userId;
    if (userId == null) return Future.value();
    final operation = _pending.then((_) => _append(userId, record));
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _append(String userId, LocalAttemptRecord record) async {
    if (_userId != userId) return;
    if (state.any((r) => r.attemptId == record.attemptId)) return;

    final updated = [record, ...state]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final capped = updated.length > PerformanceLocalDataSource.maxRecords
        ? updated.sublist(0, PerformanceLocalDataSource.maxRecords)
        : updated;
    state = capped;
    await _dataSource.save(userId, capped);
  }
}

final localAttemptsProvider =
    NotifierProvider<LocalAttemptsNotifier, List<LocalAttemptRecord>>(
      LocalAttemptsNotifier.new,
    );
