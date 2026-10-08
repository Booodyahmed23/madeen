import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/curriculum/data/datasources/curriculum_data_source.dart';
import 'package:mobile/features/curriculum/data/models/curriculum_tree_model.dart';
import 'package:mobile/features/curriculum/data/models/program_model.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/entities/curriculum_tree.dart';
import 'package:mocktail/mocktail.dart';

class MockCurriculumDataSource extends Mock implements CurriculumDataSource {}

void main() {
  late MockCurriculumDataSource dataSource;
  late CurriculumRepositoryImpl repository;

  setUp(() {
    dataSource = MockCurriculumDataSource();
    repository = CurriculumRepositoryImpl(dataSource);
  });

  group('getPrograms — success', () {
    test('maps data-source models onto domain entities', () async {
      when(() => dataSource.getPrograms()).thenAnswer(
        (_) async => const [ProgramModel(id: 'program-cma', name: 'CMA')],
      );

      final result = await repository.getPrograms();

      expect(result, isA<Success<dynamic>>());
      final programs = (result as Success).value;
      expect(programs, hasLength(1));
      expect(programs.first.id, 'program-cma');
    });

    test('an empty list is a normal success, not a failure', () async {
      when(() => dataSource.getPrograms()).thenAnswer((_) async => const []);

      final result = await repository.getPrograms();

      expect(result, isA<Success<dynamic>>());
      expect((result as Success).value, isEmpty);
    });
  });

  group('getPrograms — error mapping', () {
    test('maps a network failure (no response) onto NetworkFailure', () async {
      when(() => dataSource.getPrograms())
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.getPrograms();

      expect(result, isA<Failure<dynamic>>());
      expect((result as Failure).failure, isA<NetworkFailure>());
    });

    test('maps 401 onto UnauthorizedFailure', () async {
      when(() => dataSource.getPrograms()).thenThrow(
        const ApiException(statusCode: 401, message: 'Authentication required'),
      );

      final result = await repository.getPrograms();

      expect((result as Failure).failure, isA<UnauthorizedFailure>());
    });

    test('maps 403 onto ForbiddenFailure', () async {
      when(() => dataSource.getPrograms()).thenThrow(
        const ApiException(
          statusCode: 403,
          message: 'Insufficient permissions',
        ),
      );

      final result = await repository.getPrograms();

      expect((result as Failure).failure, isA<ForbiddenFailure>());
    });

    test('maps 500 onto ServerFailure', () async {
      when(() => dataSource.getPrograms()).thenThrow(
        const ApiException(statusCode: 500, message: 'Internal error'),
      );

      final result = await repository.getPrograms();

      expect((result as Failure).failure, isA<ServerFailure>());
    });

    test('maps an unexpected parse-time error onto UnknownFailure without leaking it', () async {
      when(() => dataSource.getPrograms()).thenThrow(TypeError());

      final result = await repository.getPrograms();

      expect((result as Failure).failure, isA<UnknownFailure>());
    });
  });

  group('getProgramTree', () {
    test('maps the tree model onto the domain tree', () async {
      when(() => dataSource.getProgramTree('program-cma')).thenAnswer(
        (_) async => CurriculumTreeModel.fromJson({
          'id': 'program-cma',
          'name': 'CMA',
          'parts': [
            {
              'id': 'part-1',
              'programId': 'program-cma',
              'name': 'Part 1',
              'units': <Object>[],
            },
          ],
        }),
      );

      final result = await repository.getProgramTree('program-cma');

      final tree = (result as Success).value as CurriculumTree;
      expect(tree.program.name, 'CMA');
      expect(tree.parts.single.id, 'part-1');
    });

    test('maps a 404 (unpublished program) onto NotFoundFailure', () async {
      when(() => dataSource.getProgramTree(any()))
          .thenThrow(const ApiException(statusCode: 404, message: 'Not found'));

      final result = await repository.getProgramTree('gone');

      expect((result as Failure).failure, isA<NotFoundFailure>());
    });
  });
}
