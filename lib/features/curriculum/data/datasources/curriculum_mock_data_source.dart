import '../models/part_model.dart';
import '../models/program_model.dart';
import '../models/sub_unit_model.dart';
import '../models/topic_model.dart';
import '../models/unit_model.dart';
import 'curriculum_data_source.dart';

/// Local sample data — used only because the real Curriculum API does not
/// exist yet (see CURRICULUM_API_REQUIREMENTS.md). This is a UI-development
/// aid, **not** production content: the data is small, hand-written, and
/// intentionally leaves some nodes childless so the empty state has
/// something real to render against. Selected automatically when
/// `AppConfig.isCurriculumApiAvailable` is `false` (the default) — see
/// curriculum_providers.dart.
class CurriculumMockDataSource implements CurriculumDataSource {
  static const _artificialDelay = Duration(milliseconds: 400);

  @override
  Future<List<ProgramModel>> getPrograms() async {
    await Future<void>.delayed(_artificialDelay);
    return const [
      ProgramModel(
        id: 'program-cma',
        name: 'CMA',
        code: 'CMA',
        description: 'Certified Management Accountant',
        order: 0,
        isActive: true,
      ),
      ProgramModel(
        id: 'program-fmaa',
        name: 'FMAA',
        code: 'FMAA',
        description: 'Financial Management & Accounting Association',
        order: 1,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<PartModel>> getParts(String programId) async {
    await Future<void>.delayed(_artificialDelay);
    switch (programId) {
      case 'program-cma':
        return const [
          PartModel(
            id: 'cma-part-1',
            programId: 'program-cma',
            name: 'Part 1',
            description: 'Financial Planning, Performance, and Analytics',
            order: 0,
          ),
          PartModel(
            id: 'cma-part-2',
            programId: 'program-cma',
            name: 'Part 2',
            description: 'Strategic Financial Management',
            order: 1,
          ),
        ];
      case 'program-fmaa':
        return const [
          PartModel(
            id: 'fmaa-part-1',
            programId: 'program-fmaa',
            name: 'Part 1',
            order: 0,
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Future<List<UnitModel>> getUnits(String partId) async {
    await Future<void>.delayed(_artificialDelay);
    switch (partId) {
      case 'cma-part-1':
        return const [
          UnitModel(
            id: 'unit-financial-planning',
            partId: 'cma-part-1',
            name: 'Financial Planning',
            order: 0,
          ),
          UnitModel(
            id: 'unit-performance-management',
            partId: 'cma-part-1',
            name: 'Performance Management',
            order: 1,
          ),
          UnitModel(
            id: 'unit-cost-management',
            partId: 'cma-part-1',
            name: 'Cost Management',
            order: 2,
          ),
          UnitModel(
            id: 'unit-internal-controls',
            partId: 'cma-part-1',
            name: 'Internal Controls',
            order: 3,
          ),
          UnitModel(
            id: 'unit-technology-analytics',
            partId: 'cma-part-1',
            name: 'Technology & Analytics',
            order: 4,
          ),
        ];
      case 'cma-part-2':
        return const [
          UnitModel(
            id: 'unit-financial-statement-analysis',
            partId: 'cma-part-2',
            name: 'Financial Statement Analysis',
            order: 0,
          ),
          UnitModel(
            id: 'unit-corporate-finance',
            partId: 'cma-part-2',
            name: 'Corporate Finance',
            order: 1,
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Future<List<SubUnitModel>> getSubUnits(String unitId) async {
    await Future<void>.delayed(_artificialDelay);
    switch (unitId) {
      case 'unit-financial-planning':
        return const [
          SubUnitModel(
            id: 'subunit-budgeting',
            unitId: 'unit-financial-planning',
            name: 'Budgeting',
            order: 0,
          ),
          SubUnitModel(
            id: 'subunit-forecasting',
            unitId: 'unit-financial-planning',
            name: 'Forecasting Techniques',
            order: 1,
          ),
        ];
      case 'unit-cost-management':
        return const [
          SubUnitModel(
            id: 'subunit-cost-concepts',
            unitId: 'unit-cost-management',
            name: 'Costing Concepts',
            order: 0,
          ),
        ];
      default:
        // Deliberately empty for other units in this sample — a real
        // empty state, not every node needs manufactured children.
        return const [];
    }
  }

  @override
  Future<List<TopicModel>> getTopics(String subUnitId) async {
    await Future<void>.delayed(_artificialDelay);
    switch (subUnitId) {
      case 'subunit-budgeting':
        return const [
          TopicModel(
            id: 'topic-flexible-budget',
            subUnitId: 'subunit-budgeting',
            name: 'Flexible Budget',
            order: 0,
          ),
          TopicModel(
            id: 'topic-master-budget',
            subUnitId: 'subunit-budgeting',
            name: 'Master Budget',
            order: 1,
          ),
          TopicModel(
            id: 'topic-variance-analysis',
            subUnitId: 'subunit-budgeting',
            name: 'Variance Analysis',
            order: 2,
          ),
        ];
      case 'subunit-cost-concepts':
        return const [
          TopicModel(
            id: 'topic-cost-behavior',
            subUnitId: 'subunit-cost-concepts',
            name: 'Cost Behavior',
            order: 0,
          ),
        ];
      default:
        return const [];
    }
  }
}
