import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../storage/token_storage.dart';

typedef UnauthorizedHandler = FutureOr<void> Function();

class DioClient {
  DioClient({UnauthorizedHandler? onUnauthorized}) {
    _onUnauthorized = onUnauthorized;
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        if (kDebugMode) {
          debugPrint(
              '[dio] ${err.requestOptions.method} ${err.requestOptions.path} '
              '→ ${err.response?.statusCode} ${err.type} '
              'data=${err.response?.data} msg=${err.message}');
        }
        if (err.response?.statusCode == 401) {
          await tokenStorage.clear();
          if (_onUnauthorized != null) {
            await _onUnauthorized!.call();
          }
        }
        handler.next(err);
      },
    ));
  }

  late final Dio _dio;
  UnauthorizedHandler? _onUnauthorized;

  Dio get raw => _dio;

  void setUnauthorizedHandler(UnauthorizedHandler handler) {
    _onUnauthorized = handler;
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get<dynamic>(path, queryParameters: query);
    return res.data as T;
  }

  /// Variant of [get] that returns null when the body is empty or literal null
  /// (e.g. `GET /attendance/active` when the user has no active session).
  Future<T?> getOrNull<T>(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get<dynamic>(path, queryParameters: query);
    final raw = res.data;
    if (raw == null) return null;
    if (raw is String && raw.isEmpty) return null;
    return raw as T;
  }

  Future<T> post<T>(String path, {Object? body}) async {
    final res = await _dio.post<dynamic>(path, data: body);
    return res.data as T;
  }

  Future<T> patch<T>(String path, {Object? body}) async {
    final res = await _dio.patch<dynamic>(path, data: body);
    return res.data as T;
  }

  Future<T> delete<T>(String path, {Object? body}) async {
    final res = await _dio.delete<dynamic>(path, data: body);
    return res.data as T;
  }
}

/// Converts a [DioException] into a user-facing Chinese message, falling back
/// to whatever the server returned in `err.response.data.message`.
String dioErrorMessage(Object err, [String fallback = '请求失败，请重试']) {
  if (err is DioException) {
    final data = err.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (data is Map && data['message'] is List && (data['message'] as List).isNotEmpty) {
      return (data['message'] as List).first.toString();
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络超时，请检查网络';
      case DioExceptionType.connectionError:
        return '无法连接服务器';
      default:
        return err.message ?? fallback;
    }
  }
  return fallback;
}
