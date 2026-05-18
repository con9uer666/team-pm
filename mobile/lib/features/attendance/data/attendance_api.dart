import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';

enum AttendanceSessionStatus { active, closed, autoClosed, unknown }

AttendanceSessionStatus parseSessionStatus(String? raw) {
  switch (raw) {
    case 'active':
      return AttendanceSessionStatus.active;
    case 'closed':
      return AttendanceSessionStatus.closed;
    case 'auto_closed':
      return AttendanceSessionStatus.autoClosed;
    default:
      return AttendanceSessionStatus.unknown;
  }
}

class AttendanceFence {
  const AttendanceFence({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radius,
    required this.enabled,
  });
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radius;
  final bool enabled;

  factory AttendanceFence.fromJson(Map<String, dynamic> j) {
    return AttendanceFence(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      centerLat: (j['centerLat'] as num).toDouble(),
      centerLng: (j['centerLng'] as num).toDouble(),
      radius: (j['radius'] as num).toDouble(),
      enabled: (j['enabled'] ?? true) as bool,
    );
  }
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.userId,
    required this.clockInAt,
    required this.clockInLat,
    required this.clockInLng,
    required this.clockInAddress,
    required this.clockInFenceId,
    required this.clockOutAt,
    required this.clockOutAddress,
    required this.status,
    required this.durationMinutes,
  });

  final String id;
  final String userId;
  final DateTime clockInAt;
  final double clockInLat;
  final double clockInLng;
  final String? clockInAddress;
  final String? clockInFenceId;
  final DateTime? clockOutAt;
  final String? clockOutAddress;
  final AttendanceSessionStatus status;
  final int durationMinutes;

  factory AttendanceSession.fromJson(Map<String, dynamic> j) {
    return AttendanceSession(
      id: j['id'] as String,
      userId: (j['userId'] ?? '') as String,
      clockInAt: DateTime.parse(j['clockInAt'] as String),
      clockInLat: (j['clockInLat'] as num).toDouble(),
      clockInLng: (j['clockInLng'] as num).toDouble(),
      clockInAddress: j['clockInAddress'] as String?,
      clockInFenceId: j['clockInFenceId'] as String?,
      clockOutAt: j['clockOutAt'] == null ? null : DateTime.parse(j['clockOutAt'] as String),
      clockOutAddress: j['clockOutAddress'] as String?,
      status: parseSessionStatus(j['status'] as String?),
      durationMinutes: (j['durationMinutes'] ?? 0) as int,
    );
  }
}

class AttendanceStatRow {
  const AttendanceStatRow({
    required this.userId,
    required this.realName,
    required this.username,
    required this.totalMinutes,
    required this.sessionCount,
  });

  final String userId;
  final String realName;
  final String username;
  final int totalMinutes;
  final int sessionCount;

  factory AttendanceStatRow.fromJson(Map<String, dynamic> j) {
    return AttendanceStatRow(
      userId: (j['userId'] ?? '') as String,
      realName: (j['realName'] ?? '') as String,
      username: (j['username'] ?? '') as String,
      totalMinutes: (j['totalMinutes'] ?? 0) as int,
      sessionCount: (j['sessionCount'] ?? 0) as int,
    );
  }
}

class AttendanceApi {
  AttendanceApi(this._client);
  final DioClient _client;

  Future<AttendanceSession> clockIn({
    required double lat,
    required double lng,
    double? accuracy,
    String? address,
  }) async {
    final data = await _client.post<Map<String, dynamic>>('/attendance/clock-in', body: {
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      if (address != null) 'address': address,
    });
    return AttendanceSession.fromJson(data);
  }

  Future<AttendanceSession> clockOut({
    required double lat,
    required double lng,
    double? accuracy,
    String? address,
  }) async {
    final data = await _client.post<Map<String, dynamic>>('/attendance/clock-out', body: {
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      if (address != null) 'address': address,
    });
    return AttendanceSession.fromJson(data);
  }

  Future<AttendanceSession?> getActive() async {
    final data = await _client.getOrNull<Map<String, dynamic>>('/attendance/active');
    if (data == null) return null;
    return AttendanceSession.fromJson(data);
  }

  Future<List<AttendanceSession>> getMy({int? limit}) async {
    final q = <String, dynamic>{};
    if (limit != null) q['limit'] = limit;
    final data = await _client.get<List<dynamic>>('/attendance/my', query: q.isEmpty ? null : q);
    return data.map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AttendanceStatRow>> getStats({String scope = 'week'}) async {
    final data = await _client.get<List<dynamic>>('/attendance/stats', query: {'scope': scope});
    return data.map((e) => AttendanceStatRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AttendanceFence>> listFences() async {
    final data = await _client.get<List<dynamic>>('/attendance/fences');
    return data.map((e) => AttendanceFence.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AttendanceFence> createFence({
    required String name,
    required double centerLat,
    required double centerLng,
    required double radius,
    bool enabled = true,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/attendance/fences',
      body: {
        'name': name,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radius': radius,
        'enabled': enabled,
      },
    );
    return AttendanceFence.fromJson(data);
  }

  Future<AttendanceFence> updateFence({
    required String id,
    String? name,
    double? centerLat,
    double? centerLng,
    double? radius,
    bool? enabled,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (centerLat != null) body['centerLat'] = centerLat;
    if (centerLng != null) body['centerLng'] = centerLng;
    if (radius != null) body['radius'] = radius;
    if (enabled != null) body['enabled'] = enabled;
    final data = await _client.patch<Map<String, dynamic>>(
      '/attendance/fences/$id',
      body: body,
    );
    return AttendanceFence.fromJson(data);
  }

  Future<void> removeFence(String id) async {
    await _client.delete<dynamic>('/attendance/fences/$id');
  }
}

final attendanceApiProvider = Provider<AttendanceApi>((ref) {
  return AttendanceApi(ref.watch(dioClientProvider));
});
