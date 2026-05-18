import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../attendance/data/attendance_api.dart';
import '../meetings/data/meetings_api.dart';
import '../tasks/data/task_models.dart';
import '../tasks/data/tasks_api.dart';

class _HomeStats {
  const _HomeStats({
    required this.pending,
    required this.completed,
    required this.overdue,
    required this.upcomingMeetings,
    required this.completionRate,
    required this.activeSession,
  });
  final int pending;
  final int completed;
  final int overdue;
  final int upcomingMeetings;
  final double completionRate;
  final AttendanceSession? activeSession;
}

final _homeStatsProvider = FutureProvider.autoDispose<_HomeStats>((ref) async {
  final tasksApi = ref.watch(tasksApiProvider);
  final meetingsApi = ref.watch(meetingsApiProvider);
  final attendanceApi = ref.watch(attendanceApiProvider);
  final auth = ref.watch(authControllerProvider);
  final userId = auth.user?.id;
  if (userId == null) {
    return const _HomeStats(
      pending: 0,
      completed: 0,
      overdue: 0,
      upcomingMeetings: 0,
      completionRate: 0,
      activeSession: null,
    );
  }

  final results = await Future.wait([
    tasksApi.getMyScope(scope: 'all'),
    meetingsApi.getMy(),
    attendanceApi.getActive(),
  ]);

  final tasks = results[0] as List<TaskItem>;
  final meetings = results[1] as List<MeetingInfo>;
  final active = results[2] as AttendanceSession?;

  final myTasks = tasks.where((t) => t.assigneeId == userId).toList();
  final now = DateTime.now();
  var pending = 0;
  var completed = 0;
  var overdue = 0;
  for (final t in myTasks) {
    if (t.status == TaskStatus.completed) {
      completed++;
    } else if (t.status == TaskStatus.overdue) {
      overdue++;
    } else {
      pending++;
    }
  }
  final total = myTasks.length;
  final rate = total == 0 ? 0.0 : completed / total;

  final upcoming = meetings.where((m) {
    return (m.status == 'scheduled' || m.status == 'in_progress') &&
        m.endTime.isAfter(now);
  }).length;

  return _HomeStats(
    pending: pending,
    completed: completed,
    overdue: overdue,
    upcomingMeetings: upcoming,
    completionRate: rate,
    activeSession: active,
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final stats = ref.watch(_homeStatsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(_homeStatsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _GreetingCard(realName: auth.user?.realName ?? ''),
              const SizedBox(height: 16),
              stats.when(
                loading: () => const _SkeletonGrid(),
                error: (e, _) => _ErrorCard(
                  message: '加载失败: $e',
                  onRetry: () => ref.invalidate(_homeStatsProvider),
                ),
                data: (s) => Column(
                  children: [
                    _StatsGrid(stats: s),
                    const SizedBox(height: 16),
                    _CompletionCard(
                      rate: s.completionRate,
                      hasAny: s.pending + s.completed + s.overdue > 0,
                    ),
                    if (s.activeSession != null) ...[
                      const SizedBox(height: 16),
                      _ActiveAttendanceCard(session: s.activeSession!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _QuickActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.realName});
  final String realName;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.gradHero,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x33335BFF), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}，$realName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '今天也要继续加油',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final _HomeStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatTile(
          gradient: AppTheme.gradBlue,
          icon: Icons.pending_actions_rounded,
          label: '待处理任务',
          value: '${stats.pending}',
          onTap: () => context.go('/tasks?status=pending'),
        ),
        _StatTile(
          gradient: AppTheme.gradGreen,
          icon: Icons.check_circle_rounded,
          label: '已完成任务',
          value: '${stats.completed}',
          onTap: () => context.go('/tasks?status=completed'),
        ),
        _StatTile(
          gradient: AppTheme.gradCyan,
          icon: Icons.event_available_rounded,
          label: '即将开始会议',
          value: '${stats.upcomingMeetings}',
          onTap: () => context.push('/meetings'),
        ),
        _StatTile(
          gradient: AppTheme.gradOrange,
          icon: Icons.warning_amber_rounded,
          label: '逾期任务',
          value: '${stats.overdue}',
          onTap: () => context.go('/tasks?status=overdue'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.rate, required this.hasAny});
  final double rate;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: hasAny ? rate.clamp(0.0, 1.0) : 0,
                      strokeWidth: 7,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                    ),
                  ),
                  Text(
                    hasAny ? '$pct%' : '—',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '任务完成率',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAny ? '保持节奏，稳步推进' : '暂无任务',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAttendanceCard extends StatelessWidget {
  const _ActiveAttendanceCard({required this.session});
  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final hh = session.clockInAt.toLocal();
    final timeStr =
        '${hh.hour.toString().padLeft(2, '0')}:${hh.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.gradGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_filled, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '考勤进行中',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '签到时间 $timeStr',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
            ),
            onPressed: () => context.go('/attendance'),
            child: const Text('查看'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = [
      const _QuickAction(
          icon: Icons.add_task_rounded,
          label: '任务',
          gradient: AppTheme.gradBlue,
          route: '/tasks'),
      const _QuickAction(
          icon: Icons.workspaces_outline,
          label: '我的空间',
          gradient: AppTheme.gradCyan,
          route: '/spaces'),
      const _QuickAction(
          icon: Icons.event_rounded,
          label: '会议',
          gradient: AppTheme.gradPurple,
          route: '/meetings'),
      const _QuickAction(
          icon: Icons.location_on_rounded,
          label: '打卡',
          gradient: AppTheme.gradGreen,
          route: '/attendance'),
      const _QuickAction(
          icon: Icons.notifications_rounded,
          label: '通知',
          gradient: AppTheme.gradOrange,
          route: '/notifications'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷操作',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              runSpacing: 14,
              children: items,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.route,
  });

  /// Routes pushed onto the stack (have a back button) rather than swapping the
  /// current tab. Everything in MainScaffold's ShellRoute that isn't a primary
  /// bottom tab belongs here.
  static const _pushRoutes = {'/meetings', '/notifications', '/spaces'};

  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (_pushRoutes.contains(route)) {
          context.push(route);
          return;
        }
        context.go(route);
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: List.generate(
              2,
              (_) => Expanded(
                child: Container(
                  height: 86,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 36),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
