import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_attempt_record.dart';

/// Persists [LocalAttemptRecord]s on this device, one list per
/// authenticated user (`performance.local_attempts.v1.<userId>`), in the
/// same SharedPreferences store the app already uses for theme/locale.
///
/// Logging out never deletes a list — it simply stops being read; logging
/// back in as the same user reads it again, and another user only ever
/// reads their own key. Only *completed* attempts are ever written here;
/// in-progress sessions are never persisted.
class PerformanceLocalDataSource {
  PerformanceLocalDataSource([
    Future<SharedPreferences> Function()? preferences,
  ]) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  /// Newest-first records beyond this are dropped on save — keeps the
  /// stored JSON (and every aggregation over it) bounded.
  static const maxRecords = 500;

  static String keyFor(String userId) =>
      'performance.local_attempts.v1.$userId';

  /// Newest first. Missing, unreadable, or corrupt data yields an empty
  /// list rather than an error — local practice history is a convenience,
  /// never a reason to break the Performance screens.
  Future<List<LocalAttemptRecord>> load(String userId) async {
    final raw = (await _preferences()).getString(keyFor(userId));
    if (raw == null) return const [];
    try {
      final records = [
        for (final item in jsonDecode(raw) as List)
          LocalAttemptRecord.fromJson(item as Map<String, dynamic>),
      ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return records;
    } catch (_) {
      return const [];
    }
  }

  /// Replaces the user's stored list with [records] (newest first), capped
  /// at [maxRecords].
  Future<void> save(String userId, List<LocalAttemptRecord> records) async {
    final capped = records.length > maxRecords
        ? records.sublist(0, maxRecords)
        : records;
    await (await _preferences()).setString(
      keyFor(userId),
      jsonEncode([for (final record in capped) record.toJson()]),
    );
  }

  /// Erases everything stored for [userId] (account deletion).
  Future<void> clear(String userId) async {
    await (await _preferences()).remove(keyFor(userId));
  }
}

final performanceLocalDataSourceProvider = Provider<PerformanceLocalDataSource>(
  (ref) => PerformanceLocalDataSource(),
);
