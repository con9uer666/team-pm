import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kTokenKey = 'auth_token';

class TokenStorage {
  const TokenStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read() => _storage.read(key: _kTokenKey);
  Future<void> write(String token) => _storage.write(key: _kTokenKey, value: token);
  Future<void> clear() => _storage.delete(key: _kTokenKey);
}

const tokenStorage = TokenStorage();
