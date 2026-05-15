import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';
import '../storage/admin_mode_storage.dart';
import '../storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioClientProvider));
});

class AuthState {
  const AuthState({
    this.user,
    this.ready = false,
    this.adminMode = false,
  });

  final AppUser? user;
  final bool ready;
  final bool adminMode;

  bool get loggedIn => user != null;
  bool get isGuest => user?.isGuest ?? false;
  bool get canAdmin => user?.canAdmin ?? false;

  AuthState copyWith({AppUser? user, bool clearUser = false, bool? ready, bool? adminMode}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      ready: ready ?? this.ready,
      adminMode: adminMode ?? this.adminMode,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthApi get _api => ref.read(authApiProvider);

  Future<void> init() async {
    if (state.ready) return;
    final savedAdminMode = await adminModeStorage.read();
    try {
      final token = await tokenStorage.read();
      if (token == null || token.isEmpty) {
        state = state.copyWith(ready: true, adminMode: savedAdminMode, clearUser: true);
        return;
      }
      final user = await _api.me();
      var adminMode = savedAdminMode;
      if (user.isSuperAdmin) {
        final stored = await adminModeStorage.readNullable();
        if (stored == null) {
          adminMode = true;
          await adminModeStorage.write(true);
        }
      }
      state = AuthState(user: user, ready: true, adminMode: adminMode);
    } catch (_) {
      await tokenStorage.clear();
      state = AuthState(user: null, ready: true, adminMode: savedAdminMode);
    }
  }

  Future<void> login(String username, String password, {bool rememberMe = true}) async {
    final res = await _api.login(
      username: username,
      password: password,
      rememberMe: rememberMe,
    );
    if (res.accessToken != null) await tokenStorage.write(res.accessToken!);

    bool adminMode = state.adminMode;
    if (res.user.isSuperAdmin) {
      adminMode = true;
      await adminModeStorage.write(true);
    } else if (res.user.roleLevel < 5) {
      adminMode = false;
      await adminModeStorage.write(false);
    }
    state = AuthState(user: res.user, ready: true, adminMode: adminMode);
  }

  Future<void> register({
    required String username,
    required String password,
    required String realName,
    required String email,
    required List<String> groupIds,
  }) async {
    final res = await _api.register(
      username: username,
      password: password,
      realName: realName,
      email: email,
      groupIds: groupIds,
    );
    if (res.accessToken != null) await tokenStorage.write(res.accessToken!);
    state = state.copyWith(user: res.user, ready: true);
  }

  Future<void> logout() async {
    await _api.logout();
    await tokenStorage.clear();
    await adminModeStorage.write(false);
    state = state.copyWith(clearUser: true, adminMode: false);
  }

  Future<void> setAdminMode(bool v) async {
    await adminModeStorage.write(v);
    state = state.copyWith(adminMode: v);
  }

  /// Called when a 401 response invalidates our session.
  void forceLoggedOut() {
    state = state.copyWith(clearUser: true);
  }
}
