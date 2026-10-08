import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/data/datasources/performance_local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../local_attempt_test_data.dart';

void main() {
  final dataSource = PerformanceLocalDataSource();

  test('load returns an empty list when nothing is stored', () async {
    expect(await dataSource.load('user-a'), isEmpty);
  });

  test('save then load round-trips, newest first', () async {
    final older = studyRecord(id: 'a', completedAt: DateTime(2026, 10, 1));
    final newer = examRecord(id: 'b', completedAt: DateTime(2026, 10, 2));

    await dataSource.save('user-a', [older, newer]);
    final loaded = await dataSource.load('user-a');

    expect(loaded.map((r) => r.attemptId), ['b', 'a']);
  });

  test('uses one key per user, and users never see each other', () async {
    await dataSource.save('user-a', [studyRecord(id: 'a-only')]);

    expect(await dataSource.load('user-b'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('performance.local_attempts.v1.user-a'),
      contains('a-only'),
    );
    expect(prefs.getString('performance.local_attempts.v1.user-b'), isNull);
  });

  test('caps the stored history at 500 records, keeping the newest', () async {
    final records = [
      for (var i = 0; i < 520; i++)
        studyRecord(
          id: 'r$i',
          completedAt: DateTime(2026, 10, 4).subtract(Duration(minutes: i)),
        ),
    ];

    await dataSource.save('user-a', records);
    final loaded = await dataSource.load('user-a');

    expect(loaded, hasLength(PerformanceLocalDataSource.maxRecords));
    expect(loaded.first.attemptId, 'r0');
    expect(loaded.last.attemptId, 'r499');
  });

  test('corrupt stored JSON fails safely to an empty list', () async {
    SharedPreferences.setMockInitialValues({
      'performance.local_attempts.v1.user-a': '{not json',
      'performance.local_attempts.v1.user-b': '[{"attemptId": 1}]',
    });

    expect(await dataSource.load('user-a'), isEmpty);
    expect(await dataSource.load('user-b'), isEmpty);
  });

  test('persists across instances (as across app launches)', () async {
    await dataSource.save('user-a', [studyRecord(id: 'kept')]);

    final relaunched = PerformanceLocalDataSource();

    expect((await relaunched.load('user-a')).single.attemptId, 'kept');
  });
}
