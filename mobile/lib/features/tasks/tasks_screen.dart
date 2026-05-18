import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/fade_in.dart';
import 'data/task_models.dart';
import 'data/tasks_api.dart';
import 'widgets/task_card.dart';
import 'widgets/task_detail_sheet.dart';
import 'widgets/task_create_sheet.dart';
import 'widgets/task_person_view.dart';
import 'widgets/task_gantt_view.dart';

final _tasksProvider = FutureProvider.autoDispose<List<TaskItem>>((ref) async {
  final api = ref.watch(tasksApiProvider);
  return api.getMyScope(scope: 'all');
});

enum _TaskScope { own, team, all }

enum _ViewMode { list, person, gantt }

const _statusFilters = kTaskStatusFilters;

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TaskScope _scope = _TaskScope.own;
  _ViewMode _viewMode = _ViewMode.list;
  String _statusFilter = '';
  bool _queryApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Apply ?status=… from the URL once when the screen first opens (e.g. when
    // tapped from the home stat cards). Subsequent visits without a query keep
    // whatever the user picked manually.
    if (_queryApplied) return;
    final q = GoRouterState.of(context).uri.queryParameters['status'];
    if (q == null || q.isEmpty) {
      _queryApplied = true;
      return;
    }
    // Map shorthand aliases (e.g. ?status=pending → pending_review).
    final normalized = q == 'pending' ? 'pending_review' : q;
    final hit = _statusFilters
        .any((o) => o.value.isNotEmpty && o.value == normalized);
    if (hit) _statusFilter = normalized;
    _queryApplied = true;
  }

  Future<void> _refresh() async {
    ref.invalidate(_tasksProvider);
    await ref.read(_tasksProvider.future).catchError((_) => <TaskItem>[]);
  }

  List<TaskItem> _applyFilters(List<TaskItem> all, String? myId) {
    Iterable<TaskItem> list = all;
    switch (_scope) {
      case _TaskScope.own:
        list = list.where((t) => t.assigneeId == myId);
        break;
      case _TaskScope.team:
        list = list.where((t) => t.assigneeId != myId);
        break;
      case _TaskScope.all:
        // no assignee filter
        break;
    }
    if (_statusFilter.isNotEmpty) {
      list = list.where((t) => t.rawStatus == _statusFilter);
    }
    return list.toList();
  }

  Future<void> _openDetail(TaskItem t) async {
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
    if (changed == true) {
      ref.invalidate(_tasksProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final asyncTasks = ref.watch(_tasksProvider);
    final myId = auth.user?.id;
    final roleLevel = auth.user?.roleLevel ?? 0;
    final isLeader = roleLevel >= 3;
    final isManager = roleLevel >= 5 || (auth.user?.isSuperAdmin ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (_) => const TaskCreateSheet(),
                );
                if (created == true) {
                  ref.invalidate(_tasksProvider);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _ScopeTabs(
              scope: _scope,
              showAll: isManager,
              onChanged: (s) => setState(() => _scope = s),
            ),
            _ViewModeBar(
              mode: _viewMode,
              onChanged: (m) => setState(() => _viewMode = m),
            ),
            _StatusChips(
              active: _statusFilter,
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: asyncTasks.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => _ErrorView(
                  message: dioErrorMessage(err, '加载失败'),
                  onRetry: _refresh,
                ),
                data: (all) {
                  final filtered = _applyFilters(all, myId);
                  if (filtered.isEmpty) {
                    return _EmptyView(onRefresh: _refresh);
                  }
                  switch (_viewMode) {
                    case _ViewMode.list:
                      return RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final t = filtered[i];
                            final card = Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TaskCard(
                                task: t,
                                isMine: t.assigneeId == myId,
                                onTap: () => _openDetail(t),
                              ),
                            );
                            // Stagger only the first few rows on initial entry
                            // — skipping the rest avoids replaying as the user
                            // scrolls deep into a long list.
                            if (i >= 6) return card;
                            return FadeInUp.once(
                              key: ValueKey(t.id),
                              delay: Duration(milliseconds: 40 * i),
                              child: card,
                            );
                          },
                        ),
                      );
                    case _ViewMode.person:
                      return RefreshIndicator(
                        onRefresh: _refresh,
                        child: TaskPersonView(
                          tasks: filtered,
                          myId: myId,
                          onTap: _openDetail,
                        ),
                      );
                    case _ViewMode.gantt:
                      return TaskGanttView(
                        tasks: filtered,
                        onTap: _openDetail,
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.scope,
    required this.showAll,
    required this.onChanged,
  });
  final _TaskScope scope;
  final bool showAll;
  final ValueChanged<_TaskScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <_ScopeOption>[
      const _ScopeOption(_TaskScope.own, '我的任务'),
      _ScopeOption(_TaskScope.team, showAll ? '团队任务' : '组员任务'),
      if (showAll) const _ScopeOption(_TaskScope.all, '全部任务'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (final o in items)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scope == o.value ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: scope == o.value
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      o.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: scope == o.value
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScopeOption {
  const _ScopeOption(this.value, this.label);
  final _TaskScope value;
  final String label;
}

class _ViewModeBar extends StatelessWidget {
  const _ViewModeBar({required this.mode, required this.onChanged});
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SegmentedButton<_ViewMode>(
        segments: const [
          ButtonSegment(value: _ViewMode.list, label: Text('列表'), icon: Icon(Icons.view_list_outlined)),
          ButtonSegment(value: _ViewMode.person, label: Text('人员'), icon: Icon(Icons.people_outline)),
          ButtonSegment(value: _ViewMode.gantt, label: Text('Gantt'), icon: Icon(Icons.timeline_outlined)),
        ],
        selected: {mode},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.active, required this.onChanged});
  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statusFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final o = _statusFilters[i];
          final selected = active == o.value;
          return ChoiceChip(
            label: Text(o.label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(o.value),
            selectedColor: AppTheme.primary.withValues(alpha: 0.12),
            side: BorderSide(
              color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
            ),
            labelStyle: TextStyle(
              color: selected ? AppTheme.primary : const Color(0xFF475569),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Icon(Icons.inbox_outlined, color: Color(0xFFCBD5E1), size: 72),
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              '暂无任务',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
