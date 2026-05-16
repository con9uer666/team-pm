import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';

class MeetingInfo {
  const MeetingInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.scope,
    required this.groupId,
    required this.divisionId,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final String id;
  final String title;
  final String? description;
  final String organizerId;
  final String scope; // group | division | team
  final String? groupId;
  final String? divisionId;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  /// scheduled | in_progress | ended | cancelled
  final String status;

  bool get isScheduled => status == 'scheduled';
  bool get isInProgress => status == 'in_progress';
  bool get isEnded => status == 'ended';
  bool get isCancelled => status == 'cancelled';

  factory MeetingInfo.fromJson(Map<String, dynamic> j) {
    return MeetingInfo(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      description: j['description'] as String?,
      organizerId: (j['organizerId'] ?? '') as String,
      scope: (j['scope'] ?? 'team') as String,
      groupId: j['groupId'] as String?,
      divisionId: j['divisionId'] as String?,
      location: j['location'] as String?,
      startTime: DateTime.parse(j['startTime'] as String).toLocal(),
      endTime: DateTime.parse(j['endTime'] as String).toLocal(),
      status: (j['status'] ?? 'scheduled') as String,
    );
  }
}

class MeetingParticipant {
  const MeetingParticipant({
    required this.userId,
    required this.attendanceStatus,
    this.checkInTime,
  });

  final String userId;
  final String attendanceStatus; // pending | present | late | absent
  final DateTime? checkInTime;

  factory MeetingParticipant.fromJson(Map<String, dynamic> j) {
    final raw = j['checkInTime'];
    return MeetingParticipant(
      userId: (j['userId'] ?? '') as String,
      attendanceStatus: (j['attendanceStatus'] ?? 'pending') as String,
      checkInTime: raw is String ? DateTime.tryParse(raw)?.toLocal() : null,
    );
  }
}

class MeetingMinutes {
  const MeetingMinutes({required this.content, this.updatedAt});
  final String content;
  final DateTime? updatedAt;

  factory MeetingMinutes.fromJson(Map<String, dynamic> j) {
    final ua = j['updatedAt'];
    return MeetingMinutes(
      content: (j['content'] ?? '') as String,
      updatedAt: ua is String ? DateTime.tryParse(ua)?.toLocal() : null,
    );
  }
}

class MeetingsApi {
  MeetingsApi(this._client);
  final DioClient _client;

  Future<List<MeetingInfo>> getMy() async {
    final data = await _client.get<List<dynamic>>('/meetings/my');
    return data
        .map((e) => MeetingInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MeetingInfo> getById(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/meetings/$id');
    return MeetingInfo.fromJson(data);
  }

  Future<MeetingInfo> create({
    required String title,
    required String scope, // 'group' | 'division' | 'team'
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? groupId,
    String? divisionId,
    String? location,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'scope': scope,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      if (description != null) 'description': description,
      if (groupId != null) 'groupId': groupId,
      if (divisionId != null) 'divisionId': divisionId,
      if (location != null) 'location': location,
    };
    final data =
        await _client.post<Map<String, dynamic>>('/meetings', body: body);
    return MeetingInfo.fromJson(data);
  }

  Future<MeetingInfo> start(String id) async {
    final data =
        await _client.patch<Map<String, dynamic>>('/meetings/$id/start');
    return MeetingInfo.fromJson(data);
  }

  Future<MeetingInfo> end(String id) async {
    final data =
        await _client.patch<Map<String, dynamic>>('/meetings/$id/end');
    return MeetingInfo.fromJson(data);
  }

  Future<MeetingInfo> cancel(String id) async {
    final data =
        await _client.patch<Map<String, dynamic>>('/meetings/$id/cancel');
    return MeetingInfo.fromJson(data);
  }

  Future<MeetingParticipant> checkIn(String id) async {
    final data =
        await _client.post<Map<String, dynamic>>('/meetings/$id/check-in');
    return MeetingParticipant.fromJson(data);
  }

  Future<List<MeetingParticipant>> getParticipants(String id) async {
    final data =
        await _client.get<List<dynamic>>('/meetings/$id/participants');
    return data
        .map((e) => MeetingParticipant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MeetingMinutes> saveMinutes(String id, String content) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/meetings/$id/minutes',
      body: {'content': content},
    );
    return MeetingMinutes.fromJson(data);
  }

  Future<MeetingMinutes?> getMinutes(String id) async {
    final raw = await _client.getOrNull<dynamic>('/meetings/$id/minutes');
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return MeetingMinutes.fromJson(raw);
    if (raw is Map) {
      return MeetingMinutes.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

final meetingsApiProvider = Provider<MeetingsApi>((ref) {
  return MeetingsApi(ref.watch(dioClientProvider));
});

final myMeetingsProvider =
    FutureProvider.autoDispose<List<MeetingInfo>>((ref) async {
  return ref.watch(meetingsApiProvider).getMy();
});
