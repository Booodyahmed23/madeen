import '../../../../core/network/api_client.dart';
import '../models/part_model.dart';
import '../models/program_model.dart';
import '../models/sub_unit_model.dart';
import '../models/topic_model.dart';
import '../models/unit_model.dart';
import 'curriculum_data_source.dart';

/// Talks to the Curriculum endpoints proposed in
/// CURRICULUM_API_REQUIREMENTS.md (mobile/ root).
///
/// ⚠️ NOT YET INTEGRATION-TESTED AGAINST A REAL BACKEND — as of Phase 3,
/// backend/ has no Curriculum module (verified by inspection: only
/// `identity` and `notification` exist under backend/src/modules/). This
/// class exists so the mobile app's abstraction is ready the day those
/// endpoints ship; until then it is wired up but not selected by default —
/// see AppConfig.isCurriculumApiAvailable and curriculum_providers.dart.
class CurriculumRemoteDataSource implements CurriculumDataSource {
  CurriculumRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ProgramModel>> getPrograms() {
    return _apiClient.get(
      '/programs',
      parse: (data) => (data as List)
          .map((json) => ProgramModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<PartModel>> getParts(String programId) {
    return _apiClient.get(
      '/programs/$programId/parts',
      parse: (data) => (data as List)
          .map((json) => PartModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<UnitModel>> getUnits(String partId) {
    return _apiClient.get(
      '/parts/$partId/units',
      parse: (data) => (data as List)
          .map((json) => UnitModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<SubUnitModel>> getSubUnits(String unitId) {
    return _apiClient.get(
      '/units/$unitId/sub-units',
      parse: (data) => (data as List)
          .map((json) => SubUnitModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<TopicModel>> getTopics(String subUnitId) {
    return _apiClient.get(
      '/sub-units/$subUnitId/topics',
      parse: (data) => (data as List)
          .map((json) => TopicModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }
}
