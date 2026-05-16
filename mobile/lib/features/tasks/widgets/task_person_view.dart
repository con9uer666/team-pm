import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/org/users_api.dart';
import '../data/task_models.dart';
import 'task_card.dart';

/// Tasks grouped by assignee with per-person completion bar.
/// Mirrors the "person view" tab in `frontend/src/views/Tasks.vue`.
class TaskPersonView extends ConsumerStatefulWidget {
  const TaskPersonView({
    super.key,
    required this.tasks,
    required this.myId,
    required this.onTap,
  });

  final List<TaskItem> tasks;
  final String? myId;
  final void Function(TaskItem) onTap;

  @override
  ConsumerState<TaskPersonView> createState() => _TaskPersonViewState();
}

class _TaskPersonViewState extends ConsumerState<TaskPersonView> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(orgStructureProvider).valueOrNull;
    final groups = <String, List<TaskItem>>{};
    for (final t in widget.tasks) {
      groups.putIfAbsent(t.assigneeId, () => []).add(t);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final na = org?.userName(a) ?? a;
        final nb = org?.userName(b) ?? b;
        return na.compareTo(nb);
      });

    if (sortedKeys.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('暂无任务', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: sortedKeys.length,
      itemBuilder: (context, i) {
        final assigneeId = sortedKeys[i];
        final tasks = groups[assigneeId]!;
        final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
        final total = tasks.length;
        final progress = total == 0 ? 0.0 : completed / total;
        final name = org?.userName(assigneeId) ?? '未知';
        final isMe = assigneeId == widget.myId;
        final isExpanded = _expanded.contains(assigneeId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    isExpanded ? _expanded.remove(assigneeId) : _expanded.add(assigneeId);
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isMe ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1) : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('我', style: TextStyle(fontSize: 10, color: Color(0xFF3B82F6))),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    '$completed / $total',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation(
                                    progress >= 1
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 150),
                          turns: isExpanded ? 0.25 : 0,
                          child: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      children: [
                        for (final t in tasks)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TaskCard(
                              task: t,
                              isMine: isMe,
                              onTap: () => widget.onTap(t),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
