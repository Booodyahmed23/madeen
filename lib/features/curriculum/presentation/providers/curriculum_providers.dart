import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../data/repositories/curriculum_repository_impl.dart';
import '../../domain/entities/curriculum_tree.dart';
import '../../domain/entities/part.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/sub_unit.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/unit.dart';

/// Riverpod's `FutureProvider` gives each level loading/error/data states
/// (`AsyncValue`) for free, and caches per key automatically — re-visiting
/// a program already fetched this session doesn't re-hit the network.
final programsProvider = FutureProvider<List<Program>>((ref) async {
  final result = await ref.watch(curriculumRepositoryProvider).getPrograms();
  return _unwrap(result);
});

/// One program's whole curriculum, fetched in a single call. Every level
/// below the program is derived from it in memory — invalidate this to
/// reload any of them.
final programTreeProvider = FutureProvider.family<CurriculumTree, String>((
  ref,
  programId,
) async {
  final result = await ref
      .watch(curriculumRepositoryProvider)
      .getProgramTree(programId);
  return _unwrap(result);
});

final partsProvider = FutureProvider.family<List<Part>, String>((
  ref,
  programId,
) async {
  final tree = await ref.watch(programTreeProvider(programId).future);
  return tree.parts;
});

/// Keyed by `(programId, partId)`: the program says which tree to read.
final unitsProvider =
    FutureProvider.family<List<Unit>, ({String programId, String partId})>((
      ref,
      key,
    ) async {
      final tree = await ref.watch(programTreeProvider(key.programId).future);
      return tree.unitsOf(key.partId);
    });

final subUnitsProvider =
    FutureProvider.family<List<SubUnit>, ({String programId, String unitId})>((
      ref,
      key,
    ) async {
      final tree = await ref.watch(programTreeProvider(key.programId).future);
      return tree.subUnitsOf(key.unitId);
    });

final topicsProvider =
    FutureProvider.family<List<Topic>, ({String programId, String subUnitId})>((
      ref,
      key,
    ) async {
      final tree = await ref.watch(programTreeProvider(key.programId).future);
      return tree.topicsOf(key.subUnitId);
    });

/// A topic's name, looked up in the trees of the published programs, or
/// `null` when no program has it. Used to label sessions and attempts,
/// which carry topic ids only.
final topicNameProvider = FutureProvider.family<String?, String>((
  ref,
  topicId,
) async {
  for (final program in await ref.watch(programsProvider.future)) {
    final tree = await ref.watch(programTreeProvider(program.id).future);
    final topic = tree.topicById(topicId);
    if (topic != null) return topic.name;
  }
  return null;
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
