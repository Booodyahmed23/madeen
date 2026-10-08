import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Applied by `flutter test` to every test file in this directory tree.
///
/// Every test starts from an empty, in-memory SharedPreferences store —
/// theme/locale and (since Phase 13) locally recorded practice attempts all
/// live there, so without this one test's persisted state could leak into
/// the next.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  await testMain();
}
