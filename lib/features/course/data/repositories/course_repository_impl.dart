import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/course_data_source.dart';

class CourseRepositoryImpl implements CourseRepository {
  CourseRepositoryImpl(this._dataSource);

  final CourseDataSource _dataSource;

  @override
  Future<Result<List<Course>>> getCourses({required String languageCode}) =>
      _guard(
        () async =>
            (await _dataSource.getCourses(languageCode))
                .map((m) => m.toEntity())
                .toList(),
      );

  @override
  Future<Result<CourseEnrollment>> getEnrollment(String courseId) => _guard(
    () async => (await _dataSource.getEnrollment(courseId)).toEntity(),
  );

  @override
  Future<Result<CourseEnrollment>> setLessonCompleted({
    required String courseId,
    required String lessonId,
    required bool completed,
  }) => _guard(
    () async => (await _dataSource.setLessonCompleted(
      courseId: courseId,
      lessonId: lessonId,
      completed: completed,
    )).toEntity(),
  );

  @override
  Future<Result<CourseEnrollment>> setLastAccessedLesson({
    required String courseId,
    required String lessonId,
  }) => _guard(
    () async => (await _dataSource.setLastAccessedLesson(
      courseId: courseId,
      lessonId: lessonId,
    )).toEntity(),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (error) {
      return const Result.failure(UnknownFailure());
    }
  }
}

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepositoryImpl(ref.watch(courseDataSourceProvider));
});
