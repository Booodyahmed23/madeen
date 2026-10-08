import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/curriculum_tree.dart';
import '../../domain/entities/program.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../datasources/curriculum_data_source.dart';

class CurriculumRepositoryImpl implements CurriculumRepository {
  CurriculumRepositoryImpl(this._dataSource);

  final CurriculumDataSource _dataSource;

  @override
  Future<Result<List<Program>>> getPrograms() => _guard(
    () async =>
        (await _dataSource.getPrograms()).map((m) => m.toEntity()).toList(),
  );

  @override
  Future<Result<CurriculumTree>> getProgramTree(String programId) => _guard(
    () async => (await _dataSource.getProgramTree(programId)).toEntity(),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (error) {
      // Malformed/unexpected response shape (e.g. a field with the wrong
      // type) — never let a raw TypeError/FormatException reach the UI.
      return const Result.failure(UnknownFailure());
    }
  }
}

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepositoryImpl(ref.watch(curriculumDataSourceProvider));
});
