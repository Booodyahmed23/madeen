import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/curriculum/data/models/part_model.dart';
import 'package:mobile/features/curriculum/data/models/program_model.dart';
import 'package:mobile/features/curriculum/data/models/sub_unit_model.dart';
import 'package:mobile/features/curriculum/data/models/topic_model.dart';
import 'package:mobile/features/curriculum/data/models/unit_model.dart';

void main() {
  group('ProgramModel.fromJson', () {
    test('parses a fully-populated program', () {
      final model = ProgramModel.fromJson({
        'id': 'program-cma',
        'name': 'CMA',
        'code': 'CMA',
        'description': 'Certified Management Accountant',
        'imageUrl': 'https://example.com/cma.png',
        'order': 1,
        'isActive': true,
      });

      expect(model.id, 'program-cma');
      expect(model.name, 'CMA');
      expect(model.code, 'CMA');
      expect(model.description, 'Certified Management Accountant');
      expect(model.imageUrl, 'https://example.com/cma.png');
      expect(model.order, 1);
      expect(model.isActive, true);
    });

    test('treats optional fields as absent without failing', () {
      final model = ProgramModel.fromJson({
        'id': 'program-fmaa',
        'name': 'FMAA',
        'code': 'FMAA',
      });

      expect(model.description, isNull);
      expect(model.imageUrl, isNull);
      expect(model.order, 0);
      expect(model.isActive, isNull);
    });

    test('toEntity maps every field onto the domain entity unchanged', () {
      final model = ProgramModel.fromJson({
        'id': 'program-cma',
        'name': 'CMA',
        'code': 'CMA',
        'order': 2,
      });
      final entity = model.toEntity();

      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity.code, model.code);
      expect(entity.order, 2);
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
