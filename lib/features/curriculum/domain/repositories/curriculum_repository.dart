import '../../../../core/error/result.dart';
import '../entities/part.dart';
import '../entities/program.dart';
import '../entities/sub_unit.dart';
import '../entities/topic.dart';
import '../entities/unit.dart';

/// The mobile app's only window onto curriculum data — presentation code
/// depends on this interface, never on a concrete data source, so swapping
/// mock data for the real API (see CURRICULUM_API_REQUIREMENTS.md at the
/// repo root of mobile/) is a one-line change in curriculum_providers.dart.
abstract class CurriculumRepository {
  Future<Result<List<Program>>> getPrograms();
  Future<Result<List<Part>>> getParts(String programId);
  Future<Result<List<Unit>>> getUnits(String partId);
  Future<Result<List<SubUnit>>> getSubUnits(String unitId);
  Future<Result<List<Topic>>> getTopics(String subUnitId);
}
