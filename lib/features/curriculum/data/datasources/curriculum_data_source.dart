import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/curriculum_tree_model.dart';
import '../models/program_model.dart';
import 'curriculum_mock_data_source.dart';
import 'curriculum_remote_data_source.dart';

/// Shape both [CurriculumRemoteDataSource] (the real API) and
/// [CurriculumMockDataSource] (local sample data) implement.
/// CurriculumRepositoryImpl depends on this interface, not on either
/// concrete implementation.
///
/// One call per program (the tree) instead of one per level — the
/// recommended way to load curriculum (contract §A2).
abstract class CurriculumDataSource {
  Future<List<ProgramModel>> getPrograms();

  Future<CurriculumTreeModel> getProgramTree(String programId);
}

/// The single switch between real and sample curriculum data — the
/// `CURRICULUM_API_AVAILABLE` dart-define (see AppConfig).
final curriculumDataSourceProvider = Provider<CurriculumDataSource>((ref) {
  if (AppConfig.isCurriculumApiAvailable) {
    return CurriculumRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CurriculumMockDataSource();
});
