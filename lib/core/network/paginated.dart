/// The API's paginated list envelope: `{ data: T[], meta: { page, limit,
/// total, totalPages } }` (docs/MOBILE_API_CONTRACT.md §G3). Lists are
/// requested with `page` (≥1) and `limit` (1–100); there is no `offset`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) parseItem,
  ) {
    final meta = json['meta'] as Map<String, dynamic>;
    return Paginated(
      items: (json['data'] as List)
          .map((item) => parseItem(item as Map<String, dynamic>))
          .toList(),
      page: (meta['page'] as num).toInt(),
      limit: (meta['limit'] as num).toInt(),
      total: (meta['total'] as num).toInt(),
      totalPages: (meta['totalPages'] as num).toInt(),
    );
  }

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  int get nextPage => page + 1;

  Paginated<R> map<R>(R Function(T item) convert) => Paginated(
    items: items.map(convert).toList(),
    page: page,
    limit: limit,
    total: total,
    totalPages: totalPages,
  );
}

/// Query parameters for one page — only `page` and `limit`, since the API
/// rejects unknown query fields with `400` (§G4).
Map<String, dynamic> pageQuery({int page = 1, int limit = 20}) => {
  'page': page,
  'limit': limit,
};
