import '../network/dio_client.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi(this._client);
  final DioClient _client;

  Future<AuthResponse> login({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'username': username, 'password': password, 'rememberMe': rememberMe},
    );
    return AuthResponse.fromJson(data);
  }

  Future<AuthResponse> register({
    required String username,
    required String password,
    required String realName,
    required String email,
    required List<String> groupIds,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'username': username,
        'password': password,
        'realName': realName,
        'email': email,
        'groupIds': groupIds,
      },
    );
    return AuthResponse.fromJson(data);
  }

  Future<void> logout() async {
    try {
      await _client.post<dynamic>('/auth/logout');
    } catch (_) {}
  }

  Future<AppUser> me() async {
    final data = await _client.get<Map<String, dynamic>>('/users/me');
    return AppUser.fromJson(data);
  }
}
