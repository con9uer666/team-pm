import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../tasks/data/task_models.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/widgets/task_detail_sheet.dart';

final _allTasksProvider =
    FutureProvider.autoDispose<List<TaskItem>>((ref) async {
  return ref.watch(tasksApiProvider).getAll();
});

class AdminTasksScreen extends ConsumerStatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  ConsumerState<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends ConsumerState<AdminTasksScreen> {
  final _search = TextEditingController();
  String _status = '';
  String? _assigneeId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(_allTasksProvider);
    final org = ref.watch(orgStructureProvider).valueOrNull;
    final keyword = _search.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: '搜索任务标题',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  initialValue: _status,
                  decoration: const InputDecoration(
                      isDense: true, labelText: '状态'),
                  items: [
                    for (final f in kTaskStatusFilters)
                      DropdownMenuItem(value: f.value, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  isDense: true,
                  initialValue: _assigneeId,
                  decoration: const InputDecoration(
                      isDense: true, labelText: '负责人'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('全部')),
                    if (org != null)
                      for (final u in org.users)
                        DropdownMenuItem<String?>(
                          value: u.id,
                          child: Text(
                            u.realName.isEmpty ? u.username : u.realName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() => _assigneeId = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 80),
              Center(
                child: Text(dioErrorMessage(e, '加载失败'),
                    style: TextStyle(color: AppTheme.dangerFg)),
              ),
            ]),
            data: (tasks) {
              // Build filtered list + status counts (counts use unfiltered set).
              final counts = <String, int>{};
              for (final t in tasks) {
                counts[t.rawStatus] = (counts[t.rawStatus] ?? 0) + 1;
              }
              final filtered = tasks.where((t) {
                if (_status.isNotEmpty && t.rawStatus != _status) return false;
                if (_assigneeId != null && t.assigneeId != _assigneeId) {
                  return false;
                }
                if (keyword.isNotEmpty &&
                    !t.title.toLowerCase().contains(keyword)) {
                  return false;
                }
                return true;
              }).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_allTasksProvider);
                  await ref.read(_allTasksProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    _StatsRow(total: tasks.length, counts: counts),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text('无匹配任务',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      )
                    else
                      for (var i = 0; i < filtered.length; i++)
                        if (i < 6)
                          FadeInUp.once(
                            key: ValueKey(filtered[i].id),
                            delay: Duration(milliseconds: 30 * i),
                            child: _TaskRow(
                              task: filtered[i],
                              org: org,
                              onTap: () =>
                                  _openDetail(context, ref, filtered[i]),
                              onLongPress: () =>
                                  _showActions(context, ref, filtered[i]),
                            ),
                          )
                        else
                          _TaskRow(
                            task: filtered[i],
                            org: org,
                            onTap: () =>
                                _openDetail(context, ref, filtered[i]),
                            onLongPress: () =>
                                _showActions(context, ref, filtered[i]),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openDetail(
      BuildContext context, WidgetRef ref, TaskItem t) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => TaskDetailSheet(task: t),
    );
    if (changed == true) ref.invalidate(_allTasksProvider);
  }

  Future<void> _showActions(
      BuildContext context, WidgetRef ref, TaskItem t) async {
    final canForceApprove = t.rawStatus == 'pending_review' ||
        t.rawStatus == 'pending_completion';
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canForceApprove)
              ListTile(
                leading: const Icon(Icons.check, color: Color(0xFF15803D)),
                title: const Text('强制通过'),
                onTap: () => Navigator.pop(context, 'approve'),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.dangerFg),
              title: Text('删除', style: TextStyle(color: AppTheme.dangerFg)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (choice == 'approve') {
      await _forceApprove(context, ref, t);
    } else if (choice == 'delete') {
      await _delete(context, ref, t);
    }
  }

  Future<void> _forceApprove(
      BuildContext context, WidgetRef ref, TaskItem t) async {
    final ok = await _confirm(context, '强制通过',
        '将「${t.title}」当前审核通过？此操作绕过常规流程。');
    if (!ok) return;
    try {
      // reviewType 'group' 与 Web 端 admin 默认一致，后端按当前可审核类型处理
      await ref.read(tasksApiProvider).review(
            id: t.id,
            action: 'approve',
            reviewType: 'group',
          );
      ref.invalidate(_allTasksProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已强制通过')));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
      );
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, TaskItem t) async {
    final ok = await _confirm(context, '删除任务',
        '删除「${t.title}」？关联审核记录与附件会一并删除。');
    if (!ok) return;
    try {
      await ref.read(tasksApiProvider).delete(t.id);
      ref.invalidate(_allTasksProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '删除失败'))),
      );
    }
  }

  Future<bool> _confirm(
      BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认')),
        ],
      ),
    );
    return ok == true;
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.total, required this.counts});
  final int total;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CountChip(label: '总数 $total', dark: true),
          for (final f in kTaskStatusFilters)
            if (f.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _CountChip(
                    label: '${f.label} ${counts[f.value] ?? 0}'),
              ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, this.dark = false});
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: dark
            ? null
            : Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.org,
    required this.onTap,
    required this.onLongPress,
  });
  final TaskItem task;
  final OrgStructure? org;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final assignee = org?.userName(task.assigneeId) ?? task.assigneeId;
    final group = org?.groupName(task.groupId) ?? '';
    final division = org?.divisionName(task.divisionId) ?? '';
    final sub = <String>[
      if (assignee.isNotEmpty) assignee,
      if (division.isNotEmpty) '[兵种] $division',
      if (group.isNotEmpty) '[技术组] $group',
      '截止 ${_fmtDate(task.dueDate)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              if (task.priority > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.priority_high,
                    size: 16,
                    color: task.priority == 2
                        ? AppTheme.dangerFg
                        : const Color(0xFFD97706),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: task.rawStatus, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
