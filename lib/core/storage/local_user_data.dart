import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Erases one kind of data the app keeps on the device for [userId] (a
/// cache, scheduled local notifications, …).
typedef LocalUserDataWiper = Future<void> Function(String userId);

/// Every [LocalUserDataWiper] the app has — run when the account is deleted,
/// so nothing of a deleted account stays on the device (contract §A1).
///
/// Empty here so `core/` and the auth feature never import the features
/// that own the data; the composition root (main.dart) overrides it with
/// the app's list (app/local_user_data_wipers.dart).
final localUserDataWipersProvider = Provider<List<LocalUserDataWiper>>(
  (ref) => const [],
);
