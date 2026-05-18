import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/role.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../../shared/widgets/gradient_stat_tile.dart';
import '../data/admin_api.dart';

/// Read-only overview for the admin tab. Mirrors AdminDashboard.vue: six
/// gradient stat tiles + role distribution + organization breakdown.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        await ref.read(dashboardStatsProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(dioErrorMessage(e, '加载失败'),
                    style: TextStyle(color: AppTheme.dangerFg)),
              ),
            ),
          ],
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            FadeInUp(
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  GradientStatTile(
                    gradient: AppTheme.gradBlue,
                    icon: Icons.group_outlined,
                    label: '全部用户',
                    value: s.users.total,
                  ),
                  GradientStatTile(
                    gradient: AppTheme.gradOrange,
                    icon: Icons.how_to_reg_outlined,
                    label: '待审核用户',
                    value: s.users.pending,
                  ),
                  GradientStatTile(
                    gradient: AppTheme.gradCyan,
                    icon: Icons.assignment_outlined,
                    label: '进行中任务',
                    value: s.tasks.active,
                  ),
                  GradientStatTile(
                    gradient: AppTheme.gradPurple,
                    icon: Icons.warning_amber_rounded,
                    label: '逾期任务',
                    value: s.tasks.overdue,
                  ),
                  GradientStatTile(
                    gradient: AppTheme.gradGreen,
                    icon: Icons.flag_outlined,
                    label: '活跃目标',
                    value: s.objectives.active,
                  ),
                  GradientStatTile(
                    gradient: AppTheme.gradHero,
                    icon: Icons.event_outlined,
                    label: '会议总数',
                    value: s.meetings.total,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 80),
              child: _RoleDistributionCard(byRole: s.usersByRole),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 140),
              child: _OrgSummaryCard(
                groups: s.organization.groups,
                divisions: s.organization.divisions,
                pendingReview: s.tasks.pendingReview,
                tasksTotal: s.tasks.total,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleDistributionCard extends StatelessWidget {
  const _RoleDistributionCard({required this.byRole});
  final Map<String, int> byRole;

  int _of(String key) => byRole[key] ?? 0;

  @override
  Widget build(BuildContext context) {
    final rows = <_DistRow>[
      _DistRow(label: '指导老师', count: _of('${RoleLevel.instructor}')),
      _DistRow(label: '项目管理', count: _of('5:project_manager')),
      _DistRow(label: '队长', count: _of('5:team_captain')),
      _DistRow(label: '副队长', count: _of('${RoleLevel.viceCaptain}')),
      _DistRow(label: '组长', count: _of('${RoleLevel.groupLeader}')),
      _DistRow(label: '正式队员', count: _of('${RoleLevel.officialMember}')),
      _DistRow(label: '梯队员', count: _of('${RoleLevel.reserveMember}')),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('角色分布',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(r.label,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF334155)))),
                    Text('${r.count}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DistRow {
  const _DistRow({required this.label, required this.count});
  final String label;
  final int count;
}

class _OrgSummaryCard extends StatelessWidget {
  const _OrgSummaryCard({
    required this.groups,
    required this.divisions,
    required this.pendingReview,
    required this.tasksTotal,
  });
  final int groups;
  final int divisions;
  final int pendingReview;
  final int tasksTotal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('组织规模',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _kv('兵种组', divisions),
            _kv('技术组', groups),
            _kv('任务总数', tasksTotal),
            _kv('待审核任务', pendingReview),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF334155)))),
            Text('$n',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
