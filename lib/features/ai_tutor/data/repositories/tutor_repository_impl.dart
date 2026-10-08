import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/tutor_message.dart';
import '../../domain/repositories/tutor_repository.dart';
import '../datasources/ai_provider.dart';
import '../datasources/mock_ai_provider.dart';
import '../models/tutor_message_model.dart';

class TutorRepositoryImpl implements TutorRepository {
  TutorRepositoryImpl(this._provider);

  final AiProvider _provider;

  @override
  Future<Result<TutorMessage>> sendMessage({
    required List<TutorMessage> history,
    required String content,
    required String languageCode,
  }) => _guard(() async {
    final reply = await _provider.generateReply(
      history: history
          .map(
            (m) => TutorMessageModel(
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: m.timestamp,
            ),
          )
          .toList(),
      userMessage: content,
      languageCode: languageCode,
    );
    return reply.toEntity();
  });

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

final tutorRepositoryProvider = Provider<TutorRepository>((ref) {
  return TutorRepositoryImpl(ref.watch(aiProviderProvider));
});
