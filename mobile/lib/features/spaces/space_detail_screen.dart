import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/role.dart';
import '../../core/network/dio_client.dart';
import '../../core/org/users_api.dart';
import '../../core/theme/app_theme.dart';
import '../objectives/data/objectives_api.dart';
import '../objectives/data/objective_models.dart';
import '../tasks/data/task_models.dart';
import '../tasks/widgets/task_create_sheet.dart';
import '../tasks/widgets/task_detail_sheet.dart';
import 'data/spaces_api.dart';
import 'widgets/objective_create_sheet.dart';

class SpaceDetailScreen extends ConsumerStatefulWidget {
  const SpaceDetailScreen({
    super.key,
    required this.scope,
    required this.id,
  });
  final String scope;
  final String id;

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen> {
  final Map<String, AsyncValue<List<TaskItem>>> _objTasks = {};
  String? _expandedObjId;

  Future<void> _toggleExpand(String objectiveId) async {
    if (_expandedObjId == objectiveId) {
      setState(() => _expandedObjId = null);
      return;
    }
    setState(() => _expandedObjId = objectiveId);
    if (_objTasks[objectiveId] != null) return;
    setState(() => _objTasks[objectiveId] = const AsyncValue.loading());
    try {
      final tasks =
          await ref.read(objectivesApiProvider).getTasks(objectiveId);
      if (!mounted) return;
      setState(() => _objTasks[objectiveId] = AsyncValue.data(tasks));
    } on Object catch (e, st) {
      if (!mounted) return;
      setState(() => _objTasks[objectiveId] = AsyncValue.error(e, st));
    }
  }

  Future<void> _completeObjective(ObjectiveSummary o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认'),
        content: Text('将目标「${o.title}」标记为已完成？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(objectivesApiProvider).markComplete(o.id);
      if (!mounted) return;
      _objTasks.remove(o.id);
      ref.invalidate(spaceDetailProvider(
          SpaceDetailKey(scope: widget.scope, id: widget.id)));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已标记完成')));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
      );
    }
  }

  Future<void> _removeObjective(ObjectiveSummary o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认'),
        content: Text('删除目标「${o.title}」？关联任务会保留。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(objectivesApiProvider).remove(o.id);
      if (!mounted) return;
      _objTasks.remove(o.id);
      if (_expandedObjId == o.id) _expandedObjId = null;
      ref.invalidate(spaceDetailProvider(
          SpaceDetailKey(scope: widget.scope, id: widget.id)));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '删除失败'))),
      );
    }
  }

  Future<void> _openCreate(SpaceDetail detail) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ObjectiveCreateSheet(
        scope: widget.scope,
        groupId: widget.scope == 'group' ? widget.id : null,
        divisionId: widget.scope == 'division' ? widget.id : null,
      ),
    );
    if (created == true) {
      ref.invalidate(spaceDetailProvider(
          SpaceDetailKey(scope: widget.scope, id: widget.id)));
    }
  }

  bool _canDeliver(SpaceDetail detail) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;
    if (user.isSuperAdmin) return true;
    if (user.roleLevel >= 5) return true;
    return detail.info.leaderIds.contains(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final key = SpaceDetailKey(scope: widget.scope, id: widget.id);
    final async = ref.watch(spaceDetailProvider(key));
    final org = ref.watch(orgStructureProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen(
          data: (d) => d.info.name,
          orElse: () => widget.scope == 'group' ? '技术组' : '兵种组',
        )),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(dioErrorMessage(e, '加载失败'),
                style: TextStyle(color: AppTheme.dangerFg)),
          ),
        ),
        data: (detail) => DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: const Color(0xFF3B82F6),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF3B82F6),
                  tabs: [
                    Tab(text: '阶段性目标 (${detail.objectives.length})'),
                    Tab(text: '成员 (${detail.members.length})'),
                    Tab(text: '任务 (${detail.tasks.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ObjectivesTab(
                      detail: detail,
                      canDeliver: _canDeliver(detail),
                      expandedObjId: _expandedObjId,
                      objTasks: _objTasks,
                      spaceKey: key,
                      onToggle: _toggleExpand,
                      onCreate: () => _openCreate(detail),
                      onComplete: _completeObjective,
                      onRemove: _removeObjective,
                      onTaskCreated: () {
                        _objTasks.clear();
                        ref.invalidate(spaceDetailProvider(key));
                      },
                    ),
                    _MembersTab(detail: detail, org: org, scope: widget.scope),
                    _TasksTab(
                      tasks: detail.tasks,
                      spaceKey: key,
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

class _ObjectivesTab extends StatelessWidget {
  const _ObjectivesTab({
    required this.detail,
    required this.canDeliver,
    required this.expandedObjId,
    required this.objTasks,
    required this.spaceKey,
    required this.onToggle,
    required this.onCreate,
    required this.onComplete,
    required this.onRemove,
    required this.onTaskCreated,
  });

  final SpaceDetail detail;
  final bool canDeliver;
  final String? expandedObjId;
  final Map<String, AsyncValue<List<TaskItem>>> objTasks;
  final SpaceDetailKey spaceKey;
  final void Function(String) onToggle;
  final VoidCallback onCreate;
  final void Function(ObjectiveSummary) onComplete;
  final void Function(ObjectiveSummary) onRemove;
  final VoidCallback onTaskCreated;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (canDeliver)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('下达目标'),
              style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13)),
            ),
          ),
        if (canDeliver) const SizedBox(height: 12),
        if (detail.objectives.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('暂无目标',
                  style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ),
        for (final o in detail.objectives)
          _ObjectiveCard(
            objective: o,
            expanded: expandedObjId == o.id,
            tasksAsync: objTasks[o.id],
            canDeliver: canDeliver,
            spaceKey: spaceKey,
            onToggle: () => onToggle(o.id),
            onComplete: () => onComplete(o),
            onRemove: () => onRemove(o),
            onCreated: onTaskCreated,
          ),
      ],
    );
  }
}

class _ObjectiveCard extends ConsumerWidget {
  const _ObjectiveCard({
    required this.objective,
    required this.expanded,
    required this.tasksAsync,
    required this.canDeliver,
    required this.spaceKey,
    required this.onToggle,
    required this.onComplete,
    required this.onRemove,
    required this.onCreated,
  });

  final ObjectiveSummary objective;
  final bool expanded;
  final AsyncValue<List<TaskItem>>? tasksAsync;
  final bool canDeliver;
  final SpaceDetailKey spaceKey;
  final VoidCallback onToggle;
  final VoidCallback onComplete;
  final VoidCallback onRemove;
  final VoidCallback onCreated;

  Future<void> _newTask(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => TaskCreateSheet(
        prefillObjectiveId: objective.id,
        prefillGroupId:
            objective.scope == 'group' ? objective.groupId : null,
        prefillDivisionId:
            objective.scope == 'division' ? objective.divisionId : null,
      ),
    );
    if (created == true) onCreated();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = objective.status == 'completed';
    final total = objective.totalTasks ?? 0;
    final done = objective.completedTasks ?? 0;
    final progress = total == 0 ? 0.0 : done / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(objective.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: completed
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      completed ? '已完成' : '进行中',
                      style: TextStyle(
                          fontSize: 11,
                          color: completed
                              ? const Color(0xFF15803D)
                              : const Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
              if (objective.description != null &&
                  objective.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(objective.description!,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF475569))),
              ],
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(
                      completed
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF3B82F6)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('$done / $total 任务',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                  if (objective.manuallyCompleted)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('· 手动完成',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ),
                  const Spacer(),
                  Text('截止 ${_fmtDate(objective.dueDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!completed)
                      OutlinedButton(
                        onPressed: () => _newTask(context, ref),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          textStyle: const TextStyle(fontSize: 12),
                          foregroundColor: const Color(0xFF1D4ED8),
                        ),
                        child: const Text('新建任务'),
                      ),
                    if (canDeliver) ...[
                      const SizedBox(width: 8),
                      if (!completed)
                        OutlinedButton(
                          onPressed: onComplete,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            textStyle: const TextStyle(fontSize: 12),
                            foregroundColor: const Color(0xFF15803D),
                          ),
                          child: const Text('标记完成'),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onRemove,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          textStyle: const TextStyle(fontSize: 12),
                          foregroundColor: const Color(0xFFDC2626),
                        ),
                        child: const Text('删除'),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 20),
                _ExpandedTasks(
                  tasksAsync: tasksAsync,
                  spaceKey: spaceKey,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedTasks extends ConsumerWidget {
  const _ExpandedTasks({required this.tasksAsync, required this.spaceKey});
  final AsyncValue<List<TaskItem>>? tasksAsync;
  final SpaceDetailKey spaceKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasksAsync == null) return const SizedBox.shrink();
    return tasksAsync!.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(dioErrorMessage(e, '加载任务失败'),
            style: const TextStyle(color: AppTheme.dangerFg, fontSize: 12)),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('该目标暂无任务',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          );
        }
        return Column(
          children: [
            for (final t in tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${taskStatusStyle(t.status).label} · 截止 ${_fmtDate(t.dueDate)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: taskStatusStyle(t.status).fg)),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFFCBD5E1)),
                onTap: () => openTaskDetail(context, ref, t, spaceKey),
              ),
          ],
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab(
      {required this.detail, required this.org, required this.scope});
  final SpaceDetail detail;
  final OrgStructure? org;
  final String scope;

  @override
  Widget build(BuildContext context) {
    if (detail.members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('暂无成员', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: detail.members.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = detail.members[i];
        final isLeader = detail.info.leaderIds.contains(m.id);
        final otherChips = <Widget>[];
        if (org != null) {
          for (final gid in m.groupIds) {
            if (scope == 'group' && gid == detail.info.id) continue;
            final name = org!.groupName(gid);
            if (name.isEmpty) continue;
            otherChips.add(_Chip(text: name, color: const Color(0xFF3B82F6)));
          }
          for (final did in m.divisionIds) {
            if (scope == 'division' && did == detail.info.id) continue;
            final name = org!.divisionName(did);
            if (name.isEmpty) continue;
            otherChips.add(_Chip(text: name, color: const Color(0xFF8B5CF6)));
          }
        }
        return ListTile(
          title: Text(m.realName.isEmpty ? m.username : m.realName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '@${m.username} · ${roleLabel(m.roleLevel, position: m.position)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
              if (otherChips.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, children: otherChips),
              ],
            ],
          ),
          trailing: isLeader
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('组长',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF1D4ED8))),
                )
              : null,
        );
      },
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.tasks, required this.spaceKey});
  final List<TaskItem> tasks;
  final SpaceDetailKey spaceKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('暂无任务', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = tasks[i];
        return ListTile(
          title: Text(t.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${taskStatusStyle(t.status).label} · 截止 ${_fmtDate(t.dueDate)}',
              style: TextStyle(
                  fontSize: 12, color: taskStatusStyle(t.status).fg)),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
          onTap: () => openTaskDetail(context, ref, t, spaceKey),
        );
      },
    );
  }
}

/// Pop up [TaskDetailSheet] and invalidate the space when the sheet reports
/// a change (so updated tasks/objectives are reloaded).
Future<void> openTaskDetail(
  BuildContext context,
  WidgetRef ref,
  TaskItem task,
  SpaceDetailKey spaceKey,
) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => TaskDetailSheet(task: task),
  );
  if (changed == true) {
    ref.invalidate(spaceDetailProvider(spaceKey));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

String _fmtDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
