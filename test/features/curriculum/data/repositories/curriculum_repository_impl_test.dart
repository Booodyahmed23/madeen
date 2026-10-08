import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/curriculum/data/datasources/curriculum_data_source.dart';
import 'package:mobile/features/curriculum/data/models/program_model.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
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
        (_) async => const [
          ProgramModel(id: 'program-cma', name: 'CMA', code: 'CMA'),
        ],
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

  group('getParts / getUnits / getSubUnits / getTopics', () {
    test('forward the parent id to the data source unchanged', () async {
      when(() => dataSource.getParts('program-cma'))
          .thenAnswer((_) async => const []);
      when(() => dataSource.getUnits('cma-part-1'))
          .thenAnswer((_) async => const []);
      when(() => dataSource.getSubUnits('unit-1'))
          .thenAnswer((_) async => const []);
      when(() => dataSource.getTopics('subunit-1'))
          .thenAnswer((_) async => const []);

      await repository.getParts('program-cma');
      await repository.getUnits('cma-part-1');
      await repository.getSubUnits('unit-1');
      await repository.getTopics('subunit-1');

      verify(() => dataSource.getParts('program-cma')).called(1);
      verify(() => dataSource.getUnits('cma-part-1')).called(1);
      verify(() => dataSource.getSubUnits('unit-1')).called(1);
      verify(() => dataSource.getTopics('subunit-1')).called(1);
    });
  });
}
