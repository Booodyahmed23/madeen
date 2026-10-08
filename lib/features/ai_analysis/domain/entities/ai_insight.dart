/// Which section of the AI Analysis screen an [AiInsight] belongs in —
/// rendering (icon/color) and grouping both key off this rather than three
/// parallel list types, so a new kind is one enum value, not a new class.
enum AiInsightKind {
  strength,
  weakness,

  /// A cross-attempt observation (e.g. "recent accuracy is trending up") —
  /// used for the Recurring Patterns section. Distinct from [weakness]
  /// because a pattern isn't necessarily bad (an improving trend is a
  /// pattern too) and isn't tied to one topic.
  pattern;

  static AiInsightKind fromWire(String value) {
    switch (value) {
      case 'STRENGTH':
        return AiInsightKind.strength;
      case 'WEAKNESS':
        return AiInsightKind.weakness;
      case 'PATTERN':
        return AiInsightKind.pattern;
      default:
        throw FormatException('Unknown AI insight kind: $value');
    }
  }

  String toWire() => switch (this) {
    AiInsightKind.strength => 'STRENGTH',
    AiInsightKind.weakness => 'WEAKNESS',
    AiInsightKind.pattern => 'PATTERN',
  };
}

/// One phrased observation — a strength, a weakness, or a recurring
/// pattern. [text] is the only thing ever shown; [topicId]/[topicName] and
/// [supportingMetricPercent] are the "supporting evidence" ARCHITECTURE.md
/// §17.2 requires every claim to carry (the exact accuracy number backing
/// the claim, present at generation time), never re-derived or trusted
/// blindly by the client — a student can always cross-check [text] against
/// [supportingMetricPercent] and the same topic's row on Topic Performance.
class AiInsight {
  const AiInsight({
    required this.kind,
    required this.text,
    this.topicId,
    this.topicName,
    this.supportingMetricPercent,
  });

  final AiInsightKind kind;
  final String text;

  /// Present when this insight is about one specific topic — absent for a
  /// cross-topic pattern (e.g. "your recent attempts include unanswered
  /// questions").
  final String? topicId;
  final String? topicName;

  /// The accuracy percentage [text] is making a claim about, when there is
  /// one single number that grounds it — never invented, always the same
  /// value Topic Performance/Attempt History would show for the same data.
  final double? supportingMetricPercent;
}
