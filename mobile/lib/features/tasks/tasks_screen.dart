import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import 'data/task_models.dart';
import 'data/tasks_api.dart';
import 'widgets/task_card.dart';
import 'widgets/task_detail_sheet.dart';
import 'widgets/task_create_sheet.dart';

final _tasksProvider = FutureProvider.autoDispose<List<TaskItem>>((ref) async {
  final api = ref.watch(tasksApiProvider);
  return api.getMyScope(scope: 'all');
});

const _statusFilters = [
  _StatusOption(value: '', label: '全部'),
  _StatusOption(value: 'pending_review', label: '待审核'),
  _StatusOption(value: 'approved', label: '进行中'),
  _StatusOption(value: 'pending_completion', label: '待结案审核'),
  _StatusOption(value: 'completed', label: '已完成'),
  _StatusOption(value: 'rejected', label: '已驳回'),
  _StatusOption(value: 'overdue', label: '已逾期'),
];

class _StatusOption {
  const _StatusOption({required this.value, required this.label});
  final String value;
  final String label;
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int _tabIndex = 0; // 0 = 我的, 1 = 组员
  String _statusFilter = '';

  Future<void> _refresh() async {
    ref.invalidate(_tasksProvider);
    await ref.read(_tasksProvider.future).catchError((_) => <TaskItem>[]);
  }

  List<TaskItem> _applyFilters(List<TaskItem> all, String? myId) {
    final scope = _tabIndex == 0 ? 'own' : 'team';
    Iterable<TaskItem> list = all;
    if (scope == 'own') {
      list = list.where((t) => t.assigneeId == myId);
    } else {
      list = list.where((t) => t.assigneeId != myId);
    }
    if (_statusFilter.isNotEmpty) {
      list = list.where((t) => t.rawStatus == _statusFilter);
    }
    return list.toList();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (_) => TaskCreateSheet(isLeader: isLeader),
          );
          if (created == true) {
            ref.invalidate(_tasksProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SegmentTabs(
              index: _tabIndex,
              isManager: isManager,
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
            const SizedBox(height: 4),
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
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final t = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TaskCard(
                            task: t,
                            isMine: t.assigneeId == myId,
                            onTap: () async {
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
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.index,
    required this.isManager,
    required this.onChanged,
  });
  final int index;
  final bool isManager;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
            for (var i = 0; i < 2; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: index == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: index == i
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
                      i == 0
                          ? '我的任务'
                          : (isManager ? '全部任务' : '组员任务'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: index == i
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
