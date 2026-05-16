import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/org/users_api.dart';
import '../../objectives/data/objective_models.dart';
import '../../tasks/data/task_models.dart';

class SpaceCard {
  const SpaceCard({
    required this.id,
    required this.name,
    required this.leaderIds,
    required this.memberCount,
  });

  final String id;
  final String name;
  final List<String> leaderIds;
  final int memberCount;

  factory SpaceCard.fromJson(Map<String, dynamic> j) {
    return SpaceCard(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      leaderIds: ((j['leaderIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      memberCount: (j['memberCount'] ?? 0) as int,
    );
  }
}

class MySpaces {
  const MySpaces({required this.groups, required this.divisions});
  final List<SpaceCard> groups;
  final List<SpaceCard> divisions;
}

class SpaceInfo {
  const SpaceInfo({
    required this.id,
    required this.name,
    required this.leaderIds,
    this.divisionId,
    this.description,
  });

  final String id;
  final String name;
  final List<String> leaderIds;
  final String? divisionId;
  final String? description;

  factory SpaceInfo.fromJson(Map<String, dynamic> j) {
    return SpaceInfo(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      leaderIds: ((j['leaderIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      divisionId: j['divisionId'] as String?,
      description: j['description'] as String?,
    );
  }
}

class SpaceDetail {
  const SpaceDetail({
    required this.info,
    required this.members,
    required this.objectives,
    required this.tasks,
  });

  final SpaceInfo info;
  final List<UserInfo> members;
  final List<ObjectiveSummary> objectives;
  final List<TaskItem> tasks;

  factory SpaceDetail.fromJson(Map<String, dynamic> j) {
    return SpaceDetail(
      info: SpaceInfo.fromJson(j['info'] as Map<String, dynamic>),
      members: ((j['members'] as List?) ?? const [])
          .map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      objectives: ((j['objectives'] as List?) ?? const [])
          .map((e) => ObjectiveSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: ((j['tasks'] as List?) ?? const [])
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpacesApi {
  SpacesApi(this._client);
  final DioClient _client;

  Future<MySpaces> getMy() async {
    final data = await _client.get<Map<String, dynamic>>('/spaces/my');
    final groups = ((data['groups'] as List?) ?? const [])
        .map((e) => SpaceCard.fromJson(e as Map<String, dynamic>))
        .toList();
    final divisions = ((data['divisions'] as List?) ?? const [])
        .map((e) => SpaceCard.fromJson(e as Map<String, dynamic>))
        .toList();
    return MySpaces(groups: groups, divisions: divisions);
  }

  Future<SpaceDetail> getGroup(String id) async {
    final data =
        await _client.get<Map<String, dynamic>>('/spaces/group/$id');
    return SpaceDetail.fromJson(data);
  }

  Future<SpaceDetail> getDivision(String id) async {
    final data =
        await _client.get<Map<String, dynamic>>('/spaces/division/$id');
    return SpaceDetail.fromJson(data);
  }
}

final spacesApiProvider = Provider<SpacesApi>((ref) {
  return SpacesApi(ref.watch(dioClientProvider));
});

final mySpacesProvider = FutureProvider.autoDispose<MySpaces>((ref) async {
  return ref.watch(spacesApiProvider).getMy();
});

class SpaceDetailKey {
  const SpaceDetailKey({required this.scope, required this.id});
  final String scope; // 'group' | 'division'
  final String id;

  @override
  bool operator ==(Object other) =>
      other is SpaceDetailKey && other.scope == scope && other.id == id;
  @override
  int get hashCode => Object.hash(scope, id);
}

final spaceDetailProvider = FutureProvider.autoDispose
    .family<SpaceDetail, SpaceDetailKey>((ref, key) async {
  final api = ref.watch(spacesApiProvider);
  return key.scope == 'group'
      ? api.getGroup(key.id)
      : api.getDivision(key.id);
});
