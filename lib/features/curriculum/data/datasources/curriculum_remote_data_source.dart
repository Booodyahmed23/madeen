import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated.dart';
import '../models/curriculum_tree_model.dart';
import '../models/program_model.dart';
import 'curriculum_data_source.dart';

/// Talks to the `/curriculum/*` endpoints (contract §A2). Students only ever
/// see published nodes, and browsing needs no entitlement.
class CurriculumRemoteDataSource implements CurriculumDataSource {
  CurriculumRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static const _pageSize = 100;

  /// Every published program — paged at the API's maximum page size, so in
  /// practice a single request.
  @override
  Future<List<ProgramModel>> getPrograms() async {
    final programs = <ProgramModel>[];
    var page = 1;
    while (true) {
      final result = await _apiClient.get(
        '/curriculum/programs',
        queryParameters: pageQuery(page: page, limit: _pageSize),
        parse: (data) => Paginated.fromJson(
          data as Map<String, dynamic>,
          ProgramModel.fromJson,
        ),
      );
      programs.addAll(result.items);
      if (!result.hasMore) break;
      page = result.nextPage;
    }
    return programs..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<CurriculumTreeModel> getProgramTree(String programId) {
    return _apiClient.get(
      '/curriculum/programs/$programId/tree',
      parse: (data) =>
          CurriculumTreeModel.fromJson(data as Map<String, dynamic>),
    );
  }
}
