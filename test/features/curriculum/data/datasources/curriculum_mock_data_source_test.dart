import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/curriculum/data/datasources/curriculum_mock_data_source.dart';

void main() {
  late CurriculumMockDataSource dataSource;

  setUp(() => dataSource = CurriculumMockDataSource());

  test('returns both CMA and FMAA programs', () async {
    final programs = await dataSource.getPrograms();

    expect(programs.map((p) => p.code), containsAll(['CMA', 'FMAA']));
  });

  test('CMA Part 1 has the five units named in the product brief', () async {
    final units = await dataSource.getUnits('cma-part-1');

    expect(units.map((u) => u.name), [
      'Financial Planning',
      'Performance Management',
      'Cost Management',
      'Internal Controls',
      'Technology & Analytics',
    ]);
  });

  test(
    'Budgeting sub-unit has the topics named in the product brief',
    () async {
      final topics = await dataSource.getTopics('subunit-budgeting');

      expect(topics.map((t) => t.name), [
        'Flexible Budget',
        'Master Budget',
        'Variance Analysis',
      ]);
    },
  );

  test('an id with no configured children returns an empty list (real empty state)', () async {
    final subUnits = await dataSource.getSubUnits('unit-technology-analytics');
    final units = await dataSource.getUnits('unknown-part-id');

    expect(subUnits, isEmpty);
    expect(units, isEmpty);
  });
}
