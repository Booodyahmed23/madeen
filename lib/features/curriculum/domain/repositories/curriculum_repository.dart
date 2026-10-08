import '../../../../core/error/result.dart';
import '../entities/curriculum_tree.dart';
import '../entities/program.dart';

/// The mobile app's only window onto curriculum data — presentation code
/// depends on this interface, never on a concrete data source.
abstract class CurriculumRepository {
  Future<Result<List<Program>>> getPrograms();

  /// The whole published curriculum of one program (one API call).
  Future<Result<CurriculumTree>> getProgramTree(String programId);
}
