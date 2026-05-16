import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/data/task_models.dart';
import 'objective_models.dart';

class ObjectivesApi {
  ObjectivesApi(this._client);
  final DioClient _client;

  /// Mirrors `frontend/src/api/objectives.ts` :: `list`.
  /// scope is 'group' | 'division' (omit for all).
  Future<List<ObjectiveSummary>> list({
    String? scope,
    String? groupId,
    String? divisionId,
  }) async {
    final q = <String, dynamic>{};
    if (scope != null) q['scope'] = scope;
    if (groupId != null) q['groupId'] = groupId;
    if (divisionId != null) q['divisionId'] = divisionId;
    final data = await _client.get<List<dynamic>>(
      '/objectives',
      query: q.isEmpty ? null : q,
    );
    return data
        .map((e) => ObjectiveSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ObjectiveSummary> getById(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/objectives/$id');
    return ObjectiveSummary.fromJson(data);
  }

  Future<List<TaskItem>> getTasks(String id) async {
    final data =
        await _client.get<List<dynamic>>('/objectives/$id/tasks');
    return data
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ObjectiveSummary> create({
    required String title,
    required String scope, // 'group' | 'division'
    required DateTime dueDate,
    String? description,
    String? groupId,
    String? divisionId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'scope': scope,
      'dueDate': dueDate.toUtc().toIso8601String(),
      if (description != null) 'description': description,
      if (groupId != null) 'groupId': groupId,
      if (divisionId != null) 'divisionId': divisionId,
    };
    final data =
        await _client.post<Map<String, dynamic>>('/objectives', body: body);
    return ObjectiveSummary.fromJson(data);
  }

  Future<void> markComplete(String id) async {
    await _client.patch<dynamic>('/objectives/$id/complete');
  }

  Future<void> remove(String id) async {
    await _client.delete<dynamic>('/objectives/$id');
  }
}

final objectivesApiProvider = Provider<ObjectivesApi>((ref) {
  return ObjectivesApi(ref.watch(dioClientProvider));
});

/// Key for [objectivesByScopeProvider] — equality based on scope+groupId+divisionId.
class ObjectiveScopeKey {
  const ObjectiveScopeKey({this.scope, this.groupId, this.divisionId});
  final String? scope;
  final String? groupId;
  final String? divisionId;

  @override
  bool operator ==(Object other) =>
      other is ObjectiveScopeKey &&
      other.scope == scope &&
      other.groupId == groupId &&
      other.divisionId == divisionId;

  @override
  int get hashCode => Object.hash(scope, groupId, divisionId);
}

/// Cached, auto-disposed list of objectives matching the given scope key.
/// Used by task create + detail sheets to populate the objective picker.
final objectivesByScopeProvider = FutureProvider.autoDispose
    .family<List<ObjectiveSummary>, ObjectiveScopeKey>((ref, key) async {
  final api = ref.watch(objectivesApiProvider);
  return api.list(
    scope: key.scope,
    groupId: key.groupId,
    divisionId: key.divisionId,
  );
});
