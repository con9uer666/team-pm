import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role.dart';
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
    this.position,
    this.email,
    this.wechatWorkId,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String realName;
  final int roleLevel;
  final List<String> groupIds;
  final List<String> divisionIds;
  final bool isSuperAdmin;
  final String approvalStatus;
  final Position? position;
  final String? email;
  final String? wechatWorkId;
  final String? avatarUrl;

  bool get isApproved => approvalStatus == 'approved';
  bool get isLeader => isLeaderLevel(roleLevel);

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
      position: Position.fromJson(j['position']),
      email: j['email'] as String?,
      wechatWorkId: j['wechatWorkId'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
    );
  }
}

class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.name,
    required this.leaderIds,
    required this.divisionId,
    this.memberIds = const [],
  });

  final String id;
  final String name;
  final List<String> leaderIds;
  final String? divisionId;
  final List<String> memberIds;

  factory GroupInfo.fromJson(Map<String, dynamic> j) {
    return GroupInfo(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      leaderIds: ((j['leaderIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      divisionId: j['divisionId'] as String?,
      memberIds: ((j['memberIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class DivisionInfo {
  const DivisionInfo({
    required this.id,
    required this.name,
    required this.leaderIds,
    this.description,
    this.memberIds = const [],
  });

  final String id;
  final String name;
  final List<String> leaderIds;
  final String? description;
  final List<String> memberIds;

  factory DivisionInfo.fromJson(Map<String, dynamic> j) {
    return DivisionInfo(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      leaderIds: ((j['leaderIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      description: j['description'] as String?,
      memberIds: ((j['memberIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
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

  UserInfo? findUser(String? id) {
    if (id == null) return null;
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  GroupInfo? findGroup(String? id) {
    if (id == null) return null;
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  DivisionInfo? findDivision(String? id) {
    if (id == null) return null;
    for (final d in divisions) {
      if (d.id == id) return d;
    }
    return null;
  }

  String userName(String? id) {
    final u = findUser(id);
    return u?.realName.isNotEmpty == true ? u!.realName : (u?.username ?? '');
  }

  String groupName(String? id) => findGroup(id)?.name ?? '';
  String divisionName(String? id) => findDivision(id)?.name ?? '';

  List<UserInfo> usersInGroup(String groupId) =>
      users.where((u) => u.groupIds.contains(groupId)).toList();

  List<UserInfo> usersInDivision(String divisionId) =>
      users.where((u) => u.divisionIds.contains(divisionId)).toList();
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
