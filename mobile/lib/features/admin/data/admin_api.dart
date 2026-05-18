import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';

/// Snapshot returned by `GET /admin/dashboard/stats`.
///
/// Maps directly to the shape produced by [`AdminService.getDashboardStats`]
/// in the NestJS backend.
class DashboardStats {
  const DashboardStats({
    required this.users,
    required this.tasks,
    required this.meetings,
    required this.organization,
    required this.objectives,
    required this.usersByRole,
  });

  final _UsersBlock users;
  final _TasksBlock tasks;
  final _MeetingsBlock meetings;
  final _OrgBlock organization;
  final _ObjectivesBlock objectives;

  /// Keys are stringified role levels ("1".."6") plus the special breakdown
  /// "5:project_manager" / "5:team_captain" / "5:unspecified".
  final Map<String, int> usersByRole;

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    final u = (j['users'] as Map<String, dynamic>?) ?? const {};
    final t = (j['tasks'] as Map<String, dynamic>?) ?? const {};
    final m = (j['meetings'] as Map<String, dynamic>?) ?? const {};
    final o = (j['organization'] as Map<String, dynamic>?) ?? const {};
    final ob = (j['objectives'] as Map<String, dynamic>?) ?? const {};
    final byRoleRaw = (u['byRole'] as Map<String, dynamic>?) ?? const {};
    return DashboardStats(
      users: _UsersBlock(
        total: (u['total'] ?? 0) as int,
        pending: (u['pending'] ?? 0) as int,
        approved: (u['approved'] ?? 0) as int,
      ),
      tasks: _TasksBlock(
        total: (t['total'] ?? 0) as int,
        active: (t['active'] ?? 0) as int,
        pendingReview: (t['pendingReview'] ?? 0) as int,
        overdue: (t['overdue'] ?? 0) as int,
      ),
      meetings: _MeetingsBlock(
        total: (m['total'] ?? 0) as int,
        scheduled: (m['scheduled'] ?? 0) as int,
      ),
      organization: _OrgBlock(
        groups: (o['groups'] ?? 0) as int,
        divisions: (o['divisions'] ?? 0) as int,
      ),
      objectives: _ObjectivesBlock(
        active: (ob['active'] ?? 0) as int,
        completed: (ob['completed'] ?? 0) as int,
      ),
      usersByRole: {
        for (final entry in byRoleRaw.entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }
}

class _UsersBlock {
  const _UsersBlock(
      {required this.total, required this.pending, required this.approved});
  final int total;
  final int pending;
  final int approved;
}

class _TasksBlock {
  const _TasksBlock({
    required this.total,
    required this.active,
    required this.pendingReview,
    required this.overdue,
  });
  final int total;
  final int active;
  final int pendingReview;
  final int overdue;
}

class _MeetingsBlock {
  const _MeetingsBlock({required this.total, required this.scheduled});
  final int total;
  final int scheduled;
}

class _OrgBlock {
  const _OrgBlock({required this.groups, required this.divisions});
  final int groups;
  final int divisions;
}

class _ObjectivesBlock {
  const _ObjectivesBlock({required this.active, required this.completed});
  final int active;
  final int completed;
}

class AdminApi {
  AdminApi(this._client);
  final DioClient _client;

  Future<DashboardStats> getDashboardStats() async {
    final data =
        await _client.get<Map<String, dynamic>>('/admin/dashboard/stats');
    return DashboardStats.fromJson(data);
  }
}

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(dioClientProvider));
});

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  return ref.watch(adminApiProvider).getDashboardStats();
});
