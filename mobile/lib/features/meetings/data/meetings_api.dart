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
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // scheduled | in_progress | ended | cancelled

  factory MeetingInfo.fromJson(Map<String, dynamic> j) {
    return MeetingInfo(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      description: j['description'] as String?,
      organizerId: (j['organizerId'] ?? '') as String,
      scope: (j['scope'] ?? 'team') as String,
      location: j['location'] as String?,
      startTime: DateTime.parse(j['startTime'] as String),
      endTime: DateTime.parse(j['endTime'] as String),
      status: (j['status'] ?? 'scheduled') as String,
    );
  }
}

class MeetingsApi {
  MeetingsApi(this._client);
  final DioClient _client;

  Future<List<MeetingInfo>> getMy() async {
    final data = await _client.get<List<dynamic>>('/meetings/my');
    return data.map((e) => MeetingInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final meetingsApiProvider = Provider<MeetingsApi>((ref) {
  return MeetingsApi(ref.watch(dioClientProvider));
});
