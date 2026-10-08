import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/exam_simulation/data/datasources/exam_data_source.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../exam_fixtures.dart';

class MockExamDataSource extends Mock implements ExamDataSource {}

void main() {
  late MockExamDataSource dataSource;
  late ExamRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(testExamConfig));

  setUp(() {
    dataSource = MockExamDataSource();
    repository = ExamRepositoryImpl(dataSource);
  });

  test('parses the attempt the data source returns', () async {
    when(() => dataSource.startExam(any()))
        .thenAnswer((_) async => fakeAttemptJson());

    final result = await repository.startExam(testExamConfig);

    expect((result as Success).value.id, 'attempt-1');
  });

  test('a 403 on start becomes NoAccessFailure', () async {
    when(() => dataSource.startExam(any())).thenThrow(
      const ApiException(
        statusCode: 403,
        message: 'No active subscription covers one or more selected topics',
      ),
    );

    final result = await repository.startExam(testExamConfig);

    expect((result as Failure).failure, isA<NoAccessFailure>());
  });

  test('lists summaries from { data, meta }', () async {
    when(() => dataSource.listAttempts(page: 1, limit: 20)).thenAnswer(
      (_) async => {
        'data': [fakeAttemptJson()..remove('questions')],
        'meta': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
      },
    );

    final result = await repository.listAttempts();

    expect((result as Success).value.items.single.id, 'attempt-1');
  });

  test('an unexpected shape becomes UnknownFailure', () async {
    when(() => dataSource.getAttempt(any()))
        .thenAnswer((_) async => {'nope': 1});

    final result = await repository.getAttempt('x');

    expect((result as Failure).failure, isA<UnknownFailure>());
  });
}
