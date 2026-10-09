import 'attempt_summary.dart';

/// One page of Attempt History. A thin wrapper (rather than a bare
/// `List<AttemptSummary>`) so the repository/API abstraction is
/// pagination-ready from day one — `hasMore` is what the presentation layer
/// needs to decide whether to offer "load more", without loading the whole
/// history into memory at once (see docs/MOBILE_API_CONTRACT.md §A5
/// and the Pagination / Scalability section of this phase's brief).
class AttemptHistoryPage {
  const AttemptHistoryPage({required this.items, required this.hasMore});

  final List<AttemptSummary> items;
  final bool hasMore;
}
