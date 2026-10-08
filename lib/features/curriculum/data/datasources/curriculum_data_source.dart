import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/part_model.dart';
import '../models/program_model.dart';
import '../models/sub_unit_model.dart';
import '../models/topic_model.dart';
import '../models/unit_model.dart';
import 'curriculum_mock_data_source.dart';
import 'curriculum_remote_data_source.dart';

/// Shape both [CurriculumRemoteDataSource] (real backend, once it exists —
/// see CURRICULUM_API_REQUIREMENTS.md) and [CurriculumMockDataSource]
/// (local sample data, used until then) implement. CurriculumRepositoryImpl
/// depends on this interface, not on either concrete implementation.
abstract class CurriculumDataSource {
  Future<List<ProgramModel>> getPrograms();
  Future<List<PartModel>> getParts(String programId);
  Future<List<UnitModel>> getUnits(String partId);
  Future<List<SubUnitModel>> getSubUnits(String unitId);
  Future<List<TopicModel>> getTopics(String subUnitId);
}

/// The single switch between real and sample curriculum data. See
/// AppConfig.isCurriculumApiAvailable and CURRICULUM_API_REQUIREMENTS.md —
/// flipping the `CURRICULUM_API_AVAILABLE` dart-define is the only change
/// needed once the backend ships these endpoints.
final curriculumDataSourceProvider = Provider<CurriculumDataSource>((ref) {
  if (AppConfig.isCurriculumApiAvailable) {
    return CurriculumRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CurriculumMockDataSource();
});
