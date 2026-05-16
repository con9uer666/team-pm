/// Mirrors backend RoleLevel + Position + roleLabel from
/// `backend/src/entities/user.entity.ts` and `frontend/src/utils/role.ts`.
///
/// Backend treats `roleLevel = 5` as both PROJECT_MANAGER and TEAM_CAPTAIN —
/// the distinguishing field is `position`. Level 4 (VICE_CAPTAIN) was migrated
/// up to 5 with `position = vice_captain` in `app.module.ts` `migrateRoles()`,
/// so any future code should treat 4 as legacy.
class RoleLevel {
  const RoleLevel._();
  static const int reserveMember = 1;
  static const int officialMember = 2;
  static const int groupLeader = 3;
  static const int viceCaptain = 4; // legacy, migrated to 5 + position
  static const int projectManager = 5;
  static const int teamCaptain = 5;
  static const int instructor = 6;
}

enum Position {
  projectManager('project_manager', '项目管理'),
  teamCaptain('team_captain', '队长'),
  viceCaptain('vice_captain', '副队长');

  const Position(this.value, this.label);
  final String value;
  final String label;

  static Position? fromJson(Object? v) {
    if (v is! String) return null;
    for (final p in Position.values) {
      if (p.value == v) return p;
    }
    return null;
  }
}

/// Map a role level (1-6) to its Chinese label. Reused across user lists,
/// approval flow, profile page, and admin pages.
String roleLabel(int level, {Position? position}) {
  if (position != null) return position.label;
  switch (level) {
    case 1:
      return '梯队员';
    case 2:
      return '正式队员';
    case 3:
      return '组长';
    case 4:
      return '副队长'; // legacy
    case 5:
      return '管理层';
    case 6:
      return '指导老师';
    default:
      return '未知';
  }
}

/// True if a role level can create tasks for / review others.
bool isLeaderLevel(int level) => level >= RoleLevel.groupLeader;

/// True if a role can see all admin pages.
bool isManagerLevel(int level, {bool isSuperAdmin = false}) =>
    isSuperAdmin || level >= RoleLevel.projectManager;
