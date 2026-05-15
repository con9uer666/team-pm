import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/task_models.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.isMine,
    required this.onTap,
  });

  final TaskItem task;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = taskStatusStyle(task.status);
    final dueFmt = DateFormat('MM-dd HH:mm').format(task.dueDate.toLocal());
    final overdue = task.status == TaskStatus.overdue ||
        (task.status != TaskStatus.completed && task.dueDate.isBefore(DateTime.now()));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 4, height: 16, color: style.border),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: style.border.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      style.label,
                      style: TextStyle(
                        color: style.fg,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if ((task.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    task.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: overdue ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '截止 $dueFmt',
                      style: TextStyle(
                        color: overdue ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: overdue ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isMine ? Icons.person_outline : Icons.group_outlined,
                      size: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMine ? '我的' : '组员',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
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
