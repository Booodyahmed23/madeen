import 'package:mobile/features/curriculum/domain/entities/curriculum_tree.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/entities/sub_unit.dart';
import 'package:mobile/features/curriculum/domain/entities/topic.dart';
import 'package:mobile/features/curriculum/domain/entities/unit.dart';

/// A [CurriculumTree] from flat node lists, grouped by each node's parent id.
CurriculumTree testCurriculumTree({
  required Program program,
  List<Part> parts = const [],
  List<Unit> units = const [],
  List<SubUnit> subUnits = const [],
  List<Topic> topics = const [],
}) {
  Map<String, List<T>> group<T>(List<T> nodes, String Function(T) parentOf) {
    final map = <String, List<T>>{};
    for (final node in nodes) {
      (map[parentOf(node)] ??= []).add(node);
    }
    return map;
  }

  return CurriculumTree(
    program: program,
    parts: parts,
    unitsByPart: group(units, (u) => u.partId),
    subUnitsByUnit: group(subUnits, (s) => s.unitId),
    topicsBySubUnit: group(topics, (t) => t.subUnitId),
  );
}
