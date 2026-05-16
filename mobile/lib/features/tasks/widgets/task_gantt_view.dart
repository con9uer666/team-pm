import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/org/users_api.dart';
import '../data/task_models.dart';

/// Compact Gantt view: rows = tasks, columns = days. Supports week & month
/// scales with prev/next/today navigation, mirroring the Vue Tasks.vue Gantt
/// tab. No third-party dependency; bars are positioned with Stack + Positioned.
class TaskGanttView extends ConsumerStatefulWidget {
  const TaskGanttView({super.key, required this.tasks, required this.onTap});

  final List<TaskItem> tasks;
  final void Function(TaskItem) onTap;

  @override
  ConsumerState<TaskGanttView> createState() => _TaskGanttViewState();
}

class _TaskGanttViewState extends ConsumerState<TaskGanttView> {
  bool _isWeek = true;
  int _offset = 0;

  _Range _computeRange() {
    final now = DateTime.now();
    if (_isWeek) {
      // Find Monday of current week.
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final start = monday.add(Duration(days: _offset * 7));
      return _Range(start: start, days: 7);
    } else {
      final base = DateTime(now.year, now.month + _offset, 1);
      final daysInMonth = DateTime(base.year, base.month + 1, 0).day;
      return _Range(start: base, days: daysInMonth);
    }
  }

  String _rangeLabel(_Range r) {
    final fmt = DateFormat('M月d日');
    if (_isWeek) {
      final end = r.start.add(Duration(days: r.days - 1));
      return '${fmt.format(r.start)} - ${fmt.format(end)}';
    }
    return DateFormat('yyyy年M月').format(r.start);
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(orgStructureProvider).valueOrNull;
    final range = _computeRange();
    final dayWidth = _isWeek ? 44.0 : 18.0;
    final gridWidth = dayWidth * range.days;
    const leftColWidth = 110.0;

    return Column(
      children: [
        _GanttNavBar(
          label: _rangeLabel(range),
          isWeek: _isWeek,
          onPrev: () => setState(() => _offset -= 1),
          onNext: () => setState(() => _offset += 1),
          onToday: () => setState(() => _offset = 0),
          onScaleChanged: (w) => setState(() {
            _isWeek = w;
            _offset = 0;
          }),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: leftColWidth + gridWidth,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _GanttHeader(range: range, dayWidth: dayWidth, leftColWidth: leftColWidth),
                    for (final t in widget.tasks)
                      _GanttRow(
                        task: t,
                        range: range,
                        dayWidth: dayWidth,
                        leftColWidth: leftColWidth,
                        assigneeName: org?.userName(t.assigneeId) ?? '',
                        onTap: () => widget.onTap(t),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Range {
  const _Range({required this.start, required this.days});
  final DateTime start;
  final int days;

  DateTime get end => start.add(Duration(days: days));
  int get rangeMs => days * 86400000;
}

class _GanttNavBar extends StatelessWidget {
  const _GanttNavBar({
    required this.label,
    required this.isWeek,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onScaleChanged,
  });
  final String label;
  final bool isWeek;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<bool> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
          ),
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('今日', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('周')),
              ButtonSegment(value: false, label: Text('月')),
            ],
            selected: {isWeek},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onScaleChanged(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GanttHeader extends StatelessWidget {
  const _GanttHeader({
    required this.range,
    required this.dayWidth,
    required this.leftColWidth,
  });
  final _Range range;
  final double dayWidth;
  final double leftColWidth;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: leftColWidth,
            height: 32,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('任务', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ),
            ),
          ),
          for (var i = 0; i < range.days; i++)
            SizedBox(
              width: dayWidth,
              height: 32,
              child: _DayHeaderCell(
                date: range.start.add(Duration(days: i)),
                isToday: _sameDay(today, range.start.add(Duration(days: i))),
                compact: dayWidth < 30,
              ),
            ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({required this.date, required this.isToday, required this.compact});
  final DateTime date;
  final bool isToday;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: const Border(left: BorderSide(color: Color(0xFFF1F5F9))),
        color: isToday ? const Color(0xFFDBEAFE) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        compact ? '${date.day}' : '${date.month}/${date.day}',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          color: isToday ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _GanttRow extends StatelessWidget {
  const _GanttRow({
    required this.task,
    required this.range,
    required this.dayWidth,
    required this.leftColWidth,
    required this.assigneeName,
    required this.onTap,
  });
  final TaskItem task;
  final _Range range;
  final double dayWidth;
  final double leftColWidth;
  final String assigneeName;
  final VoidCallback onTap;

  Color _barColor() {
    switch (task.status) {
      case TaskStatus.completed:
        return const Color(0xFF22C55E);
      case TaskStatus.overdue:
        return const Color(0xFFEF4444);
      case TaskStatus.rejected:
        return const Color(0xFFF43F5E);
      case TaskStatus.pendingCompletion:
        return const Color(0xFF8B5CF6);
      case TaskStatus.pendingReview:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gridWidth = dayWidth * range.days;
    final rangeStart = range.start.millisecondsSinceEpoch;
    final rangeEnd = rangeStart + range.rangeMs;
    final tStart = task.createdAt.millisecondsSinceEpoch;
    final tEnd = task.dueDate.millisecondsSinceEpoch;

    // Skip task if entirely outside range.
    final visible = tEnd > rangeStart && tStart < rangeEnd;
    final clampedStart = math.max(tStart, rangeStart);
    final clampedEnd = math.min(tEnd, rangeEnd);

    final left = visible
        ? ((clampedStart - rangeStart) / range.rangeMs) * gridWidth
        : 0.0;
    final width = visible
        ? math.max(((clampedEnd - clampedStart) / range.rangeMs) * gridWidth, 14.0)
        : 0.0;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        height: 36,
        child: Row(
          children: [
            SizedBox(
              width: leftColWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (assigneeName.isNotEmpty)
                      Text(
                        assigneeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: gridWidth,
              height: 36,
              child: Stack(
                children: [
                  // grid lines
                  for (var i = 0; i < range.days; i++)
                    Positioned(
                      left: i * dayWidth,
                      top: 0,
                      bottom: 0,
                      child: const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                    ),
                  // task bar
                  if (visible)
                    Positioned(
                      left: left,
                      top: 9,
                      child: Container(
                        width: width,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _barColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tStart < rangeStart)
                              const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Icon(Icons.arrow_left, size: 14, color: Colors.white),
                              ),
                            const Spacer(),
                            if (tEnd > rangeEnd)
                              const Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(Icons.arrow_right, size: 14, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
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
