import '../../domain/entities/attempt_history_page.dart';
import 'attempt_summary_model.dart';

class AttemptHistoryPageModel {
  const AttemptHistoryPageModel({required this.items, required this.hasMore});

  factory AttemptHistoryPageModel.fromJson(Map<String, dynamic> json) {
    return AttemptHistoryPageModel(
      items: (json['items'] as List)
          .map((i) => AttemptSummaryModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] as bool,
    );
  }

  final List<AttemptSummaryModel> items;
  final bool hasMore;

  AttemptHistoryPage toEntity() => AttemptHistoryPage(
    items: items.map((i) => i.toEntity()).toList(),
    hasMore: hasMore,
  );
}
