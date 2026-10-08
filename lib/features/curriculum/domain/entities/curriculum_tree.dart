import 'part.dart';
import 'program.dart';
import 'sub_unit.dart';
import 'topic.dart';
import 'unit.dart';

/// One program's whole published curriculum, from a single
/// `GET /curriculum/programs/:id/tree` call (contract §A2). The Part → Unit
/// → Sub-unit → Topic screens are built from it in memory, and other
/// features use it to resolve a node to its topic ids or a topic id to its
/// name.
class CurriculumTree {
  CurriculumTree({
    required this.program,
    required this.parts,
    required this._unitsByPart,
    required this._subUnitsByUnit,
    required this._topicsBySubUnit,
  });

  final Program program;
  final List<Part> parts;
  final Map<String, List<Unit>> _unitsByPart;
  final Map<String, List<SubUnit>> _subUnitsByUnit;
  final Map<String, List<Topic>> _topicsBySubUnit;

  List<Unit> unitsOf(String partId) => _unitsByPart[partId] ?? const [];

  List<SubUnit> subUnitsOf(String unitId) =>
      _subUnitsByUnit[unitId] ?? const [];

  List<Topic> topicsOf(String subUnitId) =>
      _topicsBySubUnit[subUnitId] ?? const [];

  Iterable<Topic> get allTopics => _topicsBySubUnit.values.expand((t) => t);

  late final Map<String, Topic> _topicsById = {
    for (final topic in allTopics) topic.id: topic,
  };

  late final Map<String, Unit> _unitsById = {
    for (final unit in _unitsByPart.values.expand((u) => u)) unit.id: unit,
  };

  Topic? topicById(String topicId) => _topicsById[topicId];

  /// The ids of every topic under [nodeId] — the program, a part, a unit, a
  /// sub-unit or a topic itself. Topics known to have no questions are
  /// left out. Empty when the node isn't in this tree.
  List<String> topicIdsUnder(String nodeId) {
    Iterable<Topic> topics;
    if (nodeId == program.id) {
      topics = allTopics;
    } else if (parts.any((p) => p.id == nodeId)) {
      topics = unitsOf(nodeId).expand(_topicsOfUnit);
    } else if (_unitsById[nodeId] case final unit?) {
      topics = _topicsOfUnit(unit);
    } else if (_topicsBySubUnit.containsKey(nodeId)) {
      topics = topicsOf(nodeId);
    } else {
      final topic = topicById(nodeId);
      topics = topic == null ? const [] : [topic];
    }
    return [
      for (final topic in topics)
        if (topic.hasQuestions) topic.id,
    ];
  }

  Iterable<Topic> _topicsOfUnit(Unit unit) =>
      subUnitsOf(unit.id).expand((s) => topicsOf(s.id));
}
