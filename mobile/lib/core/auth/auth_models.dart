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

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.realName,
    required this.roleLevel,
    required this.isSuperAdmin,
    required this.approvalStatus,
    this.wechatWorkId,
    this.email,
  });

  final String id;
  final String username;
  final String realName;
  final int roleLevel;
  final bool isSuperAdmin;
  final ApprovalStatus approvalStatus;
  final String? wechatWorkId;
  final String? email;

  bool get isGuest => approvalStatus != ApprovalStatus.approved;
  bool get canAdmin => isSuperAdmin || roleLevel >= 5;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      realName: (json['realName'] ?? '') as String,
      roleLevel: (json['roleLevel'] ?? 1) as int,
      isSuperAdmin: (json['isSuperAdmin'] ?? false) as bool,
      approvalStatus: _parseApproval(json['approvalStatus'] as String?),
      wechatWorkId: json['wechatWorkId'] as String?,
      email: json['email'] as String?,
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
