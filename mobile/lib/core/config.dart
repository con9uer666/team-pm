/// App-wide constants.
class AppConfig {
  AppConfig._();

  /// Injected via `--dart-define=API_BASE=...`. Defaults to public server.
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://49.233.180.22:8080/api',
  );

  /// Host without the `/api` suffix, derived from [apiBase]. Used to build
  /// absolute URLs for assets the backend returns as `/api/uploads/...`.
  static String get host {
    if (apiBase.endsWith('/api')) {
      return apiBase.substring(0, apiBase.length - 4);
    }
    return apiBase;
  }

  /// Convert a backend-relative path like `/api/uploads/abc.jpg` to an
  /// absolute URL the mobile client can hit directly. No-op when already
  /// absolute.
  static String absoluteUrl(String path) {
    if (path.isEmpty) return path;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return path.startsWith('/') ? '$host$path' : '$host/$path';
  }
}
