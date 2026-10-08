import '../../domain/entities/curriculum_tree.dart';
import '../../domain/entities/sub_unit.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/unit.dart';
import 'part_model.dart';
import 'program_model.dart';
import 'sub_unit_model.dart';
import 'topic_model.dart';
import 'unit_model.dart';

/// `GET /curriculum/programs/:id/tree`: the program node with nested
/// `parts[].units[].subUnits[].topics[]` (contract §A2). Children are
/// sorted by `order` here so screens can show them as-is.
class CurriculumTreeModel {
  const CurriculumTreeModel({
    required this.program,
    required this.parts,
    required this.units,
    required this.subUnits,
    required this.topics,
  });

  factory CurriculumTreeModel.fromJson(Map<String, dynamic> json) {
    final parts = <PartModel>[];
    final units = <UnitModel>[];
    final subUnits = <SubUnitModel>[];
    final topics = <TopicModel>[];
    for (final part in _children(json, 'parts')) {
      parts.add(PartModel.fromJson(part));
      for (final unit in _children(part, 'units')) {
        units.add(UnitModel.fromJson(unit));
        for (final subUnit in _children(unit, 'subUnits')) {
          subUnits.add(SubUnitModel.fromJson(subUnit));
          for (final topic in _children(subUnit, 'topics')) {
            topics.add(TopicModel.fromJson(topic));
          }
        }
      }
    }
    return CurriculumTreeModel(
      program: ProgramModel.fromJson(json),
      parts: parts,
      units: units,
      subUnits: subUnits,
      topics: topics,
    );
  }

  static Iterable<Map<String, dynamic>> _children(
    Map<String, dynamic> node,
    String key,
  ) => ((node[key] as List?) ?? const []).cast<Map<String, dynamic>>();

  final ProgramModel program;
  final List<PartModel> parts;
  final List<UnitModel> units;
  final List<SubUnitModel> subUnits;
  final List<TopicModel> topics;

  CurriculumTree toEntity() {
    final unitsByPart = <String, List<Unit>>{};
    for (final unit in units) {
      (unitsByPart[unit.partId] ??= []).add(unit.toEntity());
    }
    final subUnitsByUnit = <String, List<SubUnit>>{};
    for (final subUnit in subUnits) {
      (subUnitsByUnit[subUnit.unitId] ??= []).add(subUnit.toEntity());
    }
    final topicsBySubUnit = <String, List<Topic>>{};
    for (final topic in topics) {
      (topicsBySubUnit[topic.subUnitId] ??= []).add(topic.toEntity());
    }
    for (final list in unitsByPart.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    for (final list in subUnitsByUnit.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    for (final list in topicsBySubUnit.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    return CurriculumTree(
      program: program.toEntity(),
      parts: [for (final part in parts) part.toEntity()]
        ..sort((a, b) => a.order.compareTo(b.order)),
      unitsByPart: unitsByPart,
      subUnitsByUnit: subUnitsByUnit,
      topicsBySubUnit: topicsBySubUnit,
    );
  }
}
