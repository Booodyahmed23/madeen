/// What an [AiAnalysis] explains — the same shape is reused for every scope
/// rather than one entity type per scope, so a new scope (e.g. a future
/// per-Program comparison) is a new enum value, not a redesign (see this
/// feature's README).
enum AiAnalysisScope {
  /// Every attempt the current [PerformanceFilter] selects.
  overall,

  /// One curriculum node from Topic Performance.
  topic,

  /// One attempt from Attempt History.
  attempt,

  /// Reserved for a future "how did I do lately vs. before" view that isn't
  /// just a slice of [overall] — not produced by any repository method yet,
  /// kept here so adding it later doesn't require a new enum value on an
  /// already-shipped model (see AI_ANALYSIS_API_REQUIREMENTS.md).
  recent;

  static AiAnalysisScope fromWire(String value) {
    switch (value) {
      case 'OVERALL':
        return AiAnalysisScope.overall;
      case 'TOPIC':
        return AiAnalysisScope.topic;
      case 'ATTEMPT':
        return AiAnalysisScope.attempt;
      case 'RECENT':
        return AiAnalysisScope.recent;
      default:
        throw FormatException('Unknown AI analysis scope: $value');
    }
  }

  String toWire() => switch (this) {
    AiAnalysisScope.overall => 'OVERALL',
    AiAnalysisScope.topic => 'TOPIC',
    AiAnalysisScope.attempt => 'ATTEMPT',
    AiAnalysisScope.recent => 'RECENT',
  };
}

/// Whether an [AiAnalysis] has enough underlying Performance data to say
/// anything — distinct from the presentation layer's loading/error states
/// (see presentation/providers), this is a *content* state the backend (or
/// mock) itself reports: a student with zero attempts gets a `200` with
/// [insufficientData], not a `404` or an error, mirroring
/// PerformanceOverview's own "0 attempts is valid" rule.
enum AiAnalysisStatus {
  ready,
  insufficientData;

  static AiAnalysisStatus fromWire(String value) {
    switch (value) {
      case 'READY':
        return AiAnalysisStatus.ready;
      case 'INSUFFICIENT_DATA':
        return AiAnalysisStatus.insufficientData;
      default:
        throw FormatException('Unknown AI analysis status: $value');
    }
  }

  String toWire() => switch (this) {
    AiAnalysisStatus.ready => 'READY',
    AiAnalysisStatus.insufficientData => 'INSUFFICIENT_DATA',
  };
}
