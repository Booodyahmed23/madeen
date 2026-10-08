import 'package:mobile/core/network/paginated.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';

/// [items] as a single API page.
Paginated<NotificationItem> pageOf(
  List<NotificationItem> items, {
  int page = 1,
  bool hasMore = false,
}) => Paginated(
  items: items,
  page: page,
  limit: 20,
  total: items.length,
  totalPages: hasMore ? page + 1 : page,
);
