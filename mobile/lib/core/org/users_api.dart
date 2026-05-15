import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../network/dio_provider.dart';

class UserInfo {
  const UserInfo({
    required this.id,
    required this.username,
    required this.realName,
    required this.roleLevel,
    required this.groupIds,
    required this.divisionIds,
    required this.isSuperAdmin,
    required this.approvalStatus,
  });

  final String id;
  final String username;
  final String realName;
  final int roleLevel;
  final List<String> groupIds;
  final List<String> divisionIds;
  final bool isSuperAdmin;
  final String approvalStatus;

  factory UserInfo.fromJson(Map<String, dynamic> j) {
    return UserInfo(
      id: j['id'] as String,
      username: (j['username'] ?? '') as String,
      realName: (j['realName'] ?? '') as String,
      roleLevel: (j['roleLevel'] ?? 1) as int,
      groupIds: ((j['groupIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      divisionIds: ((j['divisionIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      isSuperAdmin: (j['isSuperAdmin'] ?? false) as bool,
      approvalStatus: (j['approvalStatus'] ?? 'pending') as String,
    );
  }
}

class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.name,
    required this.leaderIds,
    required this.divisionId,
  });

  final String id;
  final String name;
  final List<String> leaderIds;
  final String? divisionId;

  factory GroupInfo.fromJson(Map<String, dynamic> j) {
    return GroupInfo(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      leaderIds: ((j['leaderIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      divisionId: j['divisionId'] as String?,
    );
  }
}

class DivisionInfo {
  const DivisionInfo({
    required this.id,
    required this.name,
    required this.leaderIds,
  });

  final String id;
  final String name;
  final List<String> leaderIds;

  factory DivisionInfo.fromJson(Map<String, dynamic> j) {
    return DivisionInfo(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      leaderIds: ((j['leaderIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class OrgStructure {
  const OrgStructure({
    required this.users,
    required this.groups,
    required this.divisions,
  });

  final List<UserInfo> users;
  final List<GroupInfo> groups;
  final List<DivisionInfo> divisions;
}

class UsersApi {
  UsersApi(this._client);
  final DioClient _client;

  Future<OrgStructure> getStructure() async {
    final data = await _client.get<Map<String, dynamic>>('/organization/structure');
    return OrgStructure(
      users: ((data['users'] as List?) ?? const [])
          .map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      groups: ((data['groups'] as List?) ?? const [])
          .map((e) => GroupInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      divisions: ((data['divisions'] as List?) ?? const [])
          .map((e) => DivisionInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final usersApiProvider = Provider<UsersApi>((ref) {
  return UsersApi(ref.watch(dioClientProvider));
});

final orgStructureProvider = FutureProvider<OrgStructure>((ref) async {
  final api = ref.watch(usersApiProvider);
  return api.getStructure();
});
