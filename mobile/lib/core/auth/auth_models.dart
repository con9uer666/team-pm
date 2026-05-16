import '../models/role.dart';

enum ApprovalStatus { pending, approved, rejected }

ApprovalStatus _parseApproval(String? v) {
  switch (v) {
    case 'approved':
      return ApprovalStatus.approved;
    case 'rejected':
      return ApprovalStatus.rejected;
    default:
      return ApprovalStatus.pending;
  }
}

List<String> _parseIdList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.realName,
    required this.roleLevel,
    required this.isSuperAdmin,
    required this.approvalStatus,
    this.position,
    this.groupIds = const [],
    this.divisionIds = const [],
    this.wechatWorkId,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String realName;
  final int roleLevel;
  final bool isSuperAdmin;
  final ApprovalStatus approvalStatus;
  final Position? position;
  final List<String> groupIds;
  final List<String> divisionIds;
  final String? wechatWorkId;
  final String? email;
  final String? avatarUrl;

  bool get isGuest => approvalStatus != ApprovalStatus.approved;
  bool get canAdmin => isSuperAdmin || roleLevel >= RoleLevel.projectManager;
  bool get isLeader => isLeaderLevel(roleLevel);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      realName: (json['realName'] ?? '') as String,
      roleLevel: (json['roleLevel'] ?? 1) as int,
      isSuperAdmin: (json['isSuperAdmin'] ?? false) as bool,
      approvalStatus: _parseApproval(json['approvalStatus'] as String?),
      position: Position.fromJson(json['position']),
      groupIds: _parseIdList(json['groupIds']),
      divisionIds: _parseIdList(json['divisionIds']),
      wechatWorkId: json['wechatWorkId'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class AuthResponse {
  const AuthResponse({required this.user, this.accessToken});

  final AppUser user;
  final String? accessToken;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String?,
    );
  }
}
