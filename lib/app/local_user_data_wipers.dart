import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_user_data.dart';
import '../features/notifications/data/services/mock_notification_scheduler.dart';
import '../features/performance/data/datasources/performance_local_data_source.dart';

/// Everything the app keeps on the device per user — wired into
/// [localUserDataWipersProvider] at the composition root (main.dart) and
/// run when the account is deleted.
List<LocalUserDataWiper> appLocalUserDataWipers(Ref ref) => [
  (userId) => ref.read(performanceLocalDataSourceProvider).clear(userId),
  (_) => ref.read(notificationSchedulerProvider).cancelAll(),
];
