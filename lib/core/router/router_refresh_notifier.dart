import 'package:flutter/foundation.dart';

/// Bridges a Riverpod state change into go_router's `refreshListenable` —
/// go_router only knows how to listen to a plain [Listenable]. Callers wire
/// this up with `ref.listen(someProvider, (_, __) => notifier.notify())`
/// rather than this class taking the provider itself, which sidesteps
/// needing to name Riverpod's internal `ProviderListenable<T>` type (not
/// part of flutter_riverpod's public API surface in this version).
class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
