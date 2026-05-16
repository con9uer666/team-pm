import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role.dart';
import '../network/dio_client.dart';
import '../network/dio_provider.dart';
import 'users_api.dart';

/// Mirrors `frontend/src/api/users.ts` — full CRUD for users + groups +
/// divisions. Backed by the same shared dio client so the bearer token /
/// 401 handling apply uniformly. Used by admin pages (batches 10–11).
class OrgApi {
  OrgApi(this._client);
  final DioClient _client;

  // ---- Users ----

  Future<List<UserInfo>> getAllUsers() async {
    final data = await _client.get<List<dynamic>>('/users');
    return data.map((e) => UserInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserInfo> createUser({
    required String username,
    required String password,
    required String realName,
    int? roleLevel,
    Position? position,
    List<String>? groupIds,
    List<String>? divisionIds,
    String? email,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/users',
      body: {
        'username': username,
        'password': password,
        'realName': realName,
        if (roleLevel != null) 'roleLevel': roleLevel,
        if (position != null) 'position': position.value,
        if (groupIds != null) 'groupIds': groupIds,
        if (divisionIds != null) 'divisionIds': divisionIds,
        if (email != null) 'email': email,
      },
    );
    return UserInfo.fromJson(data);
  }

  Future<UserInfo> updateRole({
    required String id,
    required int roleLevel,
    Position? position,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/users/$id/role',
      body: {
        'roleLevel': roleLevel,
        'position': position?.value,
      },
    );
    return UserInfo.fromJson(data);
  }

  Future<UserInfo> updatePosition({
    required String id,
    Position? position,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/users/$id/position',
      body: {'position': position?.value},
    );
    return UserInfo.fromJson(data);
  }

  Future<void> resetPassword({required String id, required String password}) async {
    await _client.patch<Map<String, dynamic>>(
      '/users/$id/password',
      body: {'password': password},
    );
  }

  Future<UserInfo> assignGroups({required String id, required List<String> groupIds}) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/users/$id/group',
      body: {'groupIds': groupIds},
    );
    return UserInfo.fromJson(data);
  }

  Future<UserInfo> assignDivisions({required String id, required List<String> divisionIds}) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/users/$id/division',
      body: {'divisionIds': divisionIds},
    );
    return UserInfo.fromJson(data);
  }

  Future<void> deleteUser(String id) async {
    await _client.delete<dynamic>('/users/$id');
  }

  // ---- Groups ----

  Future<List<GroupInfo>> getGroups() async {
    final data = await _client.get<List<dynamic>>('/organization/groups');
    return data.map((e) => GroupInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<GroupInfo>> getPublicGroups() async {
    final data = await _client.get<List<dynamic>>('/public/groups');
    return data.map((e) => GroupInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GroupInfo> createGroup({
    required String name,
    List<String>? leaderIds,
    String? divisionId,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/organization/groups',
      body: {
        'name': name,
        if (leaderIds != null) 'leaderIds': leaderIds,
        if (divisionId != null) 'divisionId': divisionId,
      },
    );
    return GroupInfo.fromJson(data);
  }

  Future<GroupInfo> setGroupLeaders({
    required String id,
    required List<String> leaderIds,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/organization/groups/$id/leaders',
      body: {'leaderIds': leaderIds},
    );
    return GroupInfo.fromJson(data);
  }

  // ---- Divisions ----

  Future<List<DivisionInfo>> getDivisions() async {
    final data = await _client.get<List<dynamic>>('/organization/divisions');
    return data.map((e) => DivisionInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DivisionInfo> createDivision({
    required String name,
    List<String>? leaderIds,
    String? description,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/organization/divisions',
      body: {
        'name': name,
        if (leaderIds != null) 'leaderIds': leaderIds,
        if (description != null) 'description': description,
      },
    );
    return DivisionInfo.fromJson(data);
  }

  Future<DivisionInfo> setDivisionLeaders({
    required String id,
    required List<String> leaderIds,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/organization/divisions/$id/leaders',
      body: {'leaderIds': leaderIds},
    );
    return DivisionInfo.fromJson(data);
  }
}

final orgApiProvider = Provider<OrgApi>((ref) {
  return OrgApi(ref.watch(dioClientProvider));
});
