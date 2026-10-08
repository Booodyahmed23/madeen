import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../data/repositories/curriculum_repository_impl.dart';
import '../../domain/entities/part.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/sub_unit.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/unit.dart';

/// Riverpod's `FutureProvider.family` gives each level loading/error/data
/// states (`AsyncValue`) for free, and caches per parent id automatically —
/// re-visiting a level already fetched this session doesn't re-hit the
/// network, which is all the caching this phase needs (ARCHITECTURE.md
/// explicitly says not to build a full offline-first cache yet).
final programsProvider = FutureProvider<List<Program>>((ref) async {
  final result = await ref.watch(curriculumRepositoryProvider).getPrograms();
  return _unwrap(result);
});

final partsProvider = FutureProvider.family<List<Part>, String>((
  ref,
  programId,
) async {
  final result = await ref
      .watch(curriculumRepositoryProvider)
      .getParts(programId);
  return _unwrap(result);
});

final unitsProvider = FutureProvider.family<List<Unit>, String>((
  ref,
  partId,
) async {
  final result = await ref.watch(curriculumRepositoryProvider).getUnits(partId);
  return _unwrap(result);
});

final subUnitsProvider = FutureProvider.family<List<SubUnit>, String>((
  ref,
  unitId,
) async {
  final result = await ref
      .watch(curriculumRepositoryProvider)
      .getSubUnits(unitId);
  return _unwrap(result);
});

final topicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  subUnitId,
) async {
  final result = await ref
      .watch(curriculumRepositoryProvider)
      .getTopics(subUnitId);
  return _unwrap(result);
});

/// `FutureProvider` wants a thrown error for its `AsyncError` state, not a
/// `Result.failure` — this is the one seam where the two error-handling
/// styles meet. The thrown [AppFailure] is what screens pattern-match on in
/// `AsyncValue.when(error: ...)`.
T _unwrap<T>(Result<T> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
}
