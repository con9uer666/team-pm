import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../objectives/data/objective_models.dart';
import '../../objectives/data/objectives_api.dart';

final _allObjectivesProvider =
    FutureProvider.autoDispose<List<ObjectiveSummary>>((ref) async {
  return ref.watch(objectivesApiProvider).list();
});

enum _ScopeFilter { all, division, group }

enum _StatusFilter { all, active, completed }

class AdminObjectivesScreen extends ConsumerStatefulWidget {
  const AdminObjectivesScreen({super.key});

  @override
  ConsumerState<AdminObjectivesScreen> createState() =>
      _AdminObjectivesScreenState();
}

class _AdminObjectivesScreenState
    extends ConsumerState<AdminObjectivesScreen> {
  _ScopeFilter _scope = _ScopeFilter.all;
  _StatusFilter _status = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_allObjectivesProvider);
    final org = ref.watch(orgStructureProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_allObjectivesProvider);
        await ref.read(_allObjectivesProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 80),
          Center(
            child: Text(dioErrorMessage(e, '加载失败'),
                style: TextStyle(color: AppTheme.dangerFg)),
          ),
        ]),
        data: (list) {
          final total = list.length;
          final active = list.where((o) => o.status == 'active').length;
          final completed = list.where((o) => o.status == 'completed').length;
          final filtered = list.where((o) {
            if (_scope == _ScopeFilter.division && o.scope != 'division') {
              return false;
            }
            if (_scope == _ScopeFilter.group && o.scope != 'group') {
              return false;
            }
            if (_status == _StatusFilter.active && o.status != 'active') {
              return false;
            }
            if (_status == _StatusFilter.completed &&
                o.status != 'completed') {
              return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  _Pill(label: '总数 $total', dark: true),
                  const SizedBox(width: 6),
                  _Pill(label: '进行中 $active'),
                  const SizedBox(width: 6),
                  _Pill(label: '已完成 $completed'),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: SegmentedButton<_ScopeFilter>(
                  segments: const [
                    ButtonSegment(value: _ScopeFilter.all, label: Text('全部')),
                    ButtonSegment(
                        value: _ScopeFilter.division, label: Text('兵种')),
                    ButtonSegment(
                        value: _ScopeFilter.group, label: Text('技术组')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) =>
                      setState(() => _scope = s.first),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<_StatusFilter>(
                  segments: const [
                    ButtonSegment(value: _StatusFilter.all, label: Text('全部')),
                    ButtonSegment(
                        value: _StatusFilter.active, label: Text('进行中')),
                    ButtonSegment(
                        value: _StatusFilter.completed, label: Text('已完成')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) =>
                      setState(() => _status = s.first),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text('无匹配目标',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                for (var i = 0; i < filtered.length; i++)
                  if (i < 5)
                    FadeInUp.once(
                      key: ValueKey(filtered[i].id),
                      delay: Duration(milliseconds: 40 * i),
                      child: _ObjectiveCard(
                        objective: filtered[i],
                        org: org,
                        onComplete: () =>
                            _complete(context, ref, filtered[i]),
                        onRemove: () =>
                            _remove(context, ref, filtered[i]),
                      ),
                    )
                  else
                    _ObjectiveCard(
                      objective: filtered[i],
                      org: org,
                      onComplete: () => _complete(context, ref, filtered[i]),
                      onRemove: () => _remove(context, ref, filtered[i]),
                    ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref,
      ObjectiveSummary o) async {
    final ok = await _confirm(
        context, '标记完成', '将目标「${o.title}」标记为已完成？');
    if (!ok) return;
    try {
      await ref.read(objectivesApiProvider).markComplete(o.id);
      ref.invalidate(_allObjectivesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已标记完成')));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref,
      ObjectiveSummary o) async {
    final ok = await _confirm(
        context, '删除目标', '删除「${o.title}」？关联任务的目标会被解除关联，任务本身保留。');
    if (!ok) return;
    try {
      await ref.read(objectivesApiProvider).remove(o.id);
      ref.invalidate(_allObjectivesProvider);
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.dark = false});
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: dark ? null : Border.all(color: const Color(0xFFCBD5E1)),
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

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({
    required this.objective,
    required this.org,
    required this.onComplete,
    required this.onRemove,
  });
  final ObjectiveSummary objective;
  final OrgStructure? org;
  final VoidCallback onComplete;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final completed = objective.status == 'completed';
    final total = objective.totalTasks ?? 0;
    final done = objective.completedTasks ?? 0;
    final progress = total == 0 ? 0.0 : done / total;
    final scopeLabel = _scopeLabel(objective, org);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            const SizedBox(height: 4),
            Text(scopeLabel,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (objective.description != null &&
                objective.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(objective.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                valueColor: AlwaysStoppedAnimation(completed
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
                const Spacer(),
                Text('截止 ${_fmtDate(objective.dueDate)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!completed)
                  OutlinedButton(
                    onPressed: onComplete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      textStyle: const TextStyle(fontSize: 12),
                      foregroundColor: const Color(0xFF15803D),
                    ),
                    child: const Text('标完成'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onRemove,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                    foregroundColor: AppTheme.dangerFg,
                  ),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _scopeLabel(ObjectiveSummary o, OrgStructure? org) {
    if (o.scope == 'division') {
      final name = org?.divisionName(o.divisionId);
      return name == null || name.isEmpty ? '[兵种]' : '[兵种] $name';
    }
    if (o.scope == 'group') {
      final name = org?.groupName(o.groupId);
      return name == null || name.isEmpty ? '[技术组]' : '[技术组] $name';
    }
    return o.scope;
  }
}

String _fmtDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
