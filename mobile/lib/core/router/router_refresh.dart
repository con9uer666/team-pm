import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adapts a Riverpod [NotifierProvider] into a [Listenable] so go_router can
/// react to auth state changes via its `refreshListenable` hook.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref, ProviderListenable<Object?> provider) {
    _sub = ref.listen<Object?>(provider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
