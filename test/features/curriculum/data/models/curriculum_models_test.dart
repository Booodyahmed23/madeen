import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/curriculum/data/models/curriculum_tree_model.dart';
import 'package:mobile/features/curriculum/data/models/part_model.dart';
import 'package:mobile/features/curriculum/data/models/program_model.dart';
import 'package:mobile/features/curriculum/data/models/sub_unit_model.dart';
import 'package:mobile/features/curriculum/data/models/topic_model.dart';
import 'package:mobile/features/curriculum/data/models/unit_model.dart';

void main() {
  group('ProgramModel.fromJson', () {
    test('parses an API program node (no code or imageUrl)', () {
      final model = ProgramModel.fromJson({
        'id': '72ff5583-483d-4fd2-ade8-02dce9fd321b',
        'name': 'CMA (Demo)',
        'description': 'Sample curriculum for development.',
        'order': 1,
        'isPublished': true,
        'createdAt': '2026-09-27T08:18:13.573Z',
        'updatedAt': '2026-09-29T11:45:05.570Z',
      });

      expect(model.name, 'CMA (Demo)');
      expect(model.description, 'Sample curriculum for development.');
      expect(model.order, 1);
      expect(model.isPublished, isTrue);
    });

    test('a null description is fine', () {
      final model = ProgramModel.fromJson({
        'id': 'p',
        'name': 'FMAA',
        'description': null,
        'order': 0,
        'isPublished': true,
      });

      expect(model.description, isNull);
      expect(model.toEntity().name, 'FMAA');
    });
  });

  group('CurriculumTreeModel.fromJson', () {
    final json = {
      'id': 'program-cma',
      'name': 'CMA',
      'description': null,
      'order': 0,
      'isPublished': true,
      'parts': [
        {
          'id': 'part-2',
          'programId': 'program-cma',
          'name': 'Part 2',
          'order': 1,
          'units': <Object>[],
        },
        {
          'id': 'part-1',
          'programId': 'program-cma',
          'name': 'Part 1',
          'order': 0,
          'units': [
            {
              'id': 'unit-1',
              'partId': 'part-1',
              'name': 'Cost Management',
              'order': 0,
              'subUnits': [
                {
                  'id': 'sub-1',
                  'unitId': 'unit-1',
                  'name': 'Variance Analysis',
                  'order': 0,
                  'topics': [
                    {
                      'id': 'topic-b',
                      'subUnitId': 'sub-1',
                      'name': 'Labor Variances',
                      'order': 1,
                      'questionCounts': {
                        'DRAFT': 1,
                        'PUBLISHED': 0,
                        'ARCHIVED': 0,
                      },
                    },
                    {
                      'id': 'topic-a',
                      'subUnitId': 'sub-1',
                      'name': 'Material Variances',
                      'order': 0,
                      'questionCounts': {
                        'DRAFT': 0,
                        'PUBLISHED': 42,
                        'ARCHIVED': 0,
                      },
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };

    test('builds every level, sorted by order', () {
      final tree = CurriculumTreeModel.fromJson(json).toEntity();

      expect(tree.parts.map((p) => p.id), ['part-1', 'part-2']);
      expect(tree.unitsOf('part-1').single.name, 'Cost Management');
      expect(tree.subUnitsOf('unit-1').single.name, 'Variance Analysis');
      expect(tree.topicsOf('sub-1').map((t) => t.id), ['topic-a', 'topic-b']);
      expect(tree.unitsOf('part-2'), isEmpty);
    });

    test('reads questionCounts.PUBLISHED and flags empty topics', () {
      final tree = CurriculumTreeModel.fromJson(json).toEntity();

      expect(tree.topicById('topic-a')!.publishedQuestionCount, 42);
      expect(tree.topicById('topic-a')!.hasQuestions, isTrue);
      expect(tree.topicById('topic-b')!.hasQuestions, isFalse);
    });

    test('topicIdsUnder resolves any node to its topics with questions', () {
      final tree = CurriculumTreeModel.fromJson(json).toEntity();

      for (final node in ['program-cma', 'part-1', 'unit-1', 'sub-1']) {
        expect(tree.topicIdsUnder(node), ['topic-a'], reason: node);
      }
      expect(tree.topicIdsUnder('topic-a'), ['topic-a']);
      expect(tree.topicIdsUnder('part-2'), isEmpty);
      expect(tree.topicIdsUnder('unknown'), isEmpty);
    });
  });

  group('PartModel.fromJson', () {
    test('parses required and optional fields', () {
      final model = PartModel.fromJson({
        'id': 'cma-part-1',
        'programId': 'program-cma',
        'name': 'Part 1',
        'order': 0,
      });

      expect(model.id, 'cma-part-1');
      expect(model.programId, 'program-cma');
      expect(model.name, 'Part 1');
      expect(model.description, isNull);
    });
  });

  group('UnitModel.fromJson', () {
    test('parses required and optional fields', () {
      final model = UnitModel.fromJson({
        'id': 'unit-1',
        'partId': 'cma-part-1',
        'name': 'Financial Planning',
      });

      expect(model.partId, 'cma-part-1');
      expect(model.name, 'Financial Planning');
    });
  });

  group('SubUnitModel.fromJson', () {
    test('parses required and optional fields', () {
      final model = SubUnitModel.fromJson({
        'id': 'subunit-1',
        'unitId': 'unit-1',
        'name': 'Budgeting',
        'description': 'Budgeting techniques',
      });

      expect(model.unitId, 'unit-1');
      expect(model.description, 'Budgeting techniques');
    });
  });

  group('TopicModel.fromJson', () {
    test('a topic from a level endpoint has no question count', () {
      final model = TopicModel.fromJson({
        'id': 'topic-1',
        'subUnitId': 'subunit-1',
        'name': 'Flexible Budget',
      });

      expect(model.publishedQuestionCount, isNull);
      expect(model.toEntity().hasQuestions, isTrue);
    });

    test('parses required and optional fields', () {
      final model = TopicModel.fromJson({
        'id': 'topic-1',
        'subUnitId': 'subunit-1',
        'name': 'Flexible Budget',
        'order': 3,
      });

      expect(model.subUnitId, 'subunit-1');
      expect(model.name, 'Flexible Budget');
      expect(model.order, 3);
    });
  });
}
