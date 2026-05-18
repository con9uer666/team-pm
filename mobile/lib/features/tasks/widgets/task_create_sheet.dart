import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../data/task_models.dart';
import '../data/tasks_api.dart';
import 'objective_picker_sheet.dart';

class TaskCreateSheet extends ConsumerStatefulWidget {
  const TaskCreateSheet({
    super.key,
    this.prefillObjectiveId,
    this.prefillGroupId,
    this.prefillDivisionId,
  });

  /// When set, pre-selects the objective and locks the related group/division
  /// to match the objective's scope so the new task is created under it.
  /// Used by SpaceDetail's "新建任务" button on each objective card.
  final String? prefillObjectiveId;
  final String? prefillGroupId;
  final String? prefillDivisionId;

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _LeaderRole {
  const _LeaderRole({required this.type, required this.id, required this.label});
  final String type; // 'division' | 'group'
  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _LeaderRole && other.type == type && other.id == id;
  @override
  int get hashCode => Object.hash(type, id);
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _requirements = TextEditingController();

  DateTime? _dueDate; // 仅日期，对齐 Web 端 <input type="date">
  bool _assignMode = false;
  _LeaderRole? _leaderRole;
  String? _assigneeId;

  String? _divisionId;
  String? _groupId;
  String? _objectiveId;
  final Set<String> _selectedDeps = {};

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _objectiveId = widget.prefillObjectiveId;
    _groupId = widget.prefillGroupId;
    _divisionId = widget.prefillDivisionId;
  }

  @override
  void dispose() {
    _title.dispose();
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _dueDate ?? now.add(const Duration(days: 3)),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  void _onAssignModeChange(bool v) {
    setState(() {
      _assignMode = v;
      if (!v) {
        _leaderRole = null;
        _assigneeId = null;
        _divisionId = null;
        _groupId = null;
      }
    });
  }

  void _onLeaderRoleChange(_LeaderRole? r) {
    setState(() {
      _leaderRole = r;
      _assigneeId = null;
      if (r == null) {
        _divisionId = null;
        _groupId = null;
      } else if (r.type == 'division') {
        _divisionId = r.id;
        _groupId = null;
      } else {
        _groupId = r.id;
        _divisionId = null;
      }
    });
  }

  void _onAssigneeChange(String? id, OrgStructure org) {
    setState(() {
      _assigneeId = id;
      final assignee = org.findUser(id);
      final role = _leaderRole;
      if (assignee == null || role == null) return;
      // 自动填充另一维度（assignee 只属于一个时直接选中）
      if (role.type == 'division') {
        final opts =
            org.groups.where((g) => assignee.groupIds.contains(g.id)).toList();
        _groupId = opts.length == 1 ? opts.first.id : null;
      } else {
        final opts = org.divisions
            .where((d) => assignee.divisionIds.contains(d.id))
            .toList();
        _divisionId = opts.length == 1 ? opts.first.id : null;
      }
    });
  }

  Future<void> _submit(OrgStructure org) async {
    if (_busy) return;
    // 统一校验：表单字段 + 各 Dropdown / 日期。失败立即提示第一个问题。
    if (!_form.currentState!.validate()) return;
    if (_dueDate == null) {
      _snack('请选择结案日期');
      return;
    }
    if (_assignMode) {
      if (_leaderRole == null) {
        _snack('请选择派发身份');
        return;
      }
      if (_assigneeId == null) {
        _snack('请选择指派人');
        return;
      }
    }
    if (_divisionId == null) {
      _snack(_assignMode ? '请选择被指派人所属兵种' : '请选择兵种');
      return;
    }
    if (_groupId == null) {
      _snack(_assignMode ? '请选择被指派人所属技术组' : '请选择技术组');
      return;
    }
    if (_requirements.text.trim().isEmpty) {
      _snack('请填写结案要求');
      return;
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(tasksApiProvider);
      await api.create(
        title: _title.text.trim(),
        completionRequirements: _requirements.text.trim(),
        dueDate: _dueDate!,
        divisionId: _divisionId,
        groupId: _groupId,
        assigneeId: _assignMode ? _assigneeId : null,
        objectiveId: _objectiveId,
        dependencyIds: _selectedDeps.isEmpty ? null : _selectedDeps.toList(),
      );
      if (!mounted) return;
      _snack('任务已创建');
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) _snack(dioErrorMessage(e, '创建失败'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickObjective(OrgStructure org) async {
    // 优先匹配 Web 逻辑：依据已选 division/group 列目标。
    final scope = _groupId != null ? 'group' : 'division';
    final outcome = await pickObjective(
      context,
      scope: scope,
      groupId: _groupId,
      divisionId: _divisionId,
      initialId: _objectiveId,
    );
    if (outcome == null) return;
    setState(() => _objectiveId = outcome.objectiveId);
  }

  Future<void> _pickDependencies() async {
    final api = ref.read(tasksApiProvider);
    try {
      final all = await api.getMyScope(scope: 'all');
      if (!mounted) return;
      final result = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => _DependencyPickerSheet(
          tasks: all,
          initial: _selectedDeps.toSet(),
        ),
      );
      if (result == null) return;
      setState(() {
        _selectedDeps
          ..clear()
          ..addAll(result);
      });
    } on Object catch (e) {
      if (!mounted) return;
      _snack(dioErrorMessage(e, '获取任务列表失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.user?.id;
    final orgAsync = ref.watch(orgStructureProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '创建本周任务',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Expanded(
                child: orgAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(dioErrorMessage(e, '加载组织结构失败'),
                          style: const TextStyle(color: AppTheme.dangerFg)),
                    ),
                  ),
                  data: (org) =>
                      _buildForm(context, controller, org, userId),
                ),
              ),
              _buildActions(context, orgAsync.valueOrNull),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, ScrollController controller,
      OrgStructure org, String? userId) {
    final me = org.findUser(userId);

    final leaderRoles = <_LeaderRole>[
      for (final d in org.divisions)
        if (d.leaderIds.contains(userId))
          _LeaderRole(type: 'division', id: d.id, label: '[兵种] ${d.name}'),
      for (final g in org.groups)
        if (g.leaderIds.contains(userId))
          _LeaderRole(type: 'group', id: g.id, label: '[技术组] ${g.name}'),
    ];

    final myDivisions = me == null
        ? <DivisionInfo>[]
        : org.divisions.where((d) => me.divisionIds.contains(d.id)).toList();
    final myGroups = me == null
        ? <GroupInfo>[]
        : org.groups.where((g) => me.groupIds.contains(g.id)).toList();

    final assignableMembers = _leaderRole == null
        ? <UserInfo>[]
        : org.users.where((u) {
            if (u.id == userId) return false;
            return _leaderRole!.type == 'division'
                ? u.divisionIds.contains(_leaderRole!.id)
                : u.groupIds.contains(_leaderRole!.id);
          }).toList();

    final assignee = _assignMode ? org.findUser(_assigneeId) : null;

    return Form(
      key: _form,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          // 1. 派发模式开关（仅 leader 可见）
          if (leaderRoles.isNotEmpty)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('派发任务'),
              subtitle: const Text('为组员创建任务'),
              value: _assignMode,
              onChanged: _onAssignModeChange,
            ),

          // 2. 派发身份 + 指派人（仅派发模式）
          if (_assignMode) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<_LeaderRole>(
              initialValue: _leaderRole,
              decoration: const InputDecoration(labelText: '派发身份 *'),
              items: [
                for (final r in leaderRoles)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: _onLeaderRoleChange,
            ),
            if (_leaderRole != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _assigneeId,
                decoration: const InputDecoration(labelText: '指派人 *'),
                items: [
                  for (final m in assignableMembers)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(m.realName.isEmpty ? m.username : m.realName),
                    ),
                ],
                onChanged: (v) => _onAssigneeChange(v, org),
              ),
            ],
          ],

          // 3. 任务内容
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '任务内容 *',
              hintText: '描述你本周要完成的任务',
            ),
            maxLines: 3,
            minLines: 1,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请填写任务内容' : null,
          ),

          // 4. 兵种 + 技术组
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _divisionId,
            decoration: const InputDecoration(labelText: '兵种 *'),
            items: _buildDivisionItems(
              org,
              myDivisions,
              assignee,
            ),
            onChanged: _shouldDisableDivision()
                ? null
                : (v) => setState(() => _divisionId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _groupId,
            decoration: const InputDecoration(labelText: '技术组 *'),
            items: _buildGroupItems(
              org,
              myGroups,
              assignee,
            ),
            onChanged: _shouldDisableGroup()
                ? null
                : (v) => setState(() => _groupId = v),
          ),

          // 5. 结案日期 + 结案要求
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('结案日期 *'),
            subtitle: Text(_dueDate == null
                ? '请选择日期'
                : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _requirements,
            decoration: const InputDecoration(
              labelText: '结案要求 *',
              hintText: '任务完成的验收标准',
            ),
            maxLines: 2,
            minLines: 1,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请填写结案要求' : null,
          ),

          // 6. 关联目标
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined, color: Color(0xFF7C3AED)),
            title: const Text('关联目标'),
            subtitle: Text(_objectiveId == null ? '不关联（可选）' : '已选择'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickObjective(org),
          ),

          // 7. 关联任务（前置依赖）
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link, color: Color(0xFF3B82F6)),
            title: const Text('关联任务'),
            subtitle: Text(_selectedDeps.isEmpty
                ? '无（可选）'
                : '已选 ${_selectedDeps.length} 个'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDependencies,
          ),
        ],
      ),
    );
  }

  bool _shouldDisableDivision() =>
      widget.prefillDivisionId != null ||
      (_assignMode && _leaderRole?.type == 'division');

  bool _shouldDisableGroup() =>
      widget.prefillGroupId != null ||
      (_assignMode && _leaderRole?.type == 'group');

  List<DropdownMenuItem<String>> _buildDivisionItems(
    OrgStructure org,
    List<DivisionInfo> myDivisions,
    UserInfo? assignee,
  ) {
    if (widget.prefillDivisionId != null) {
      final d = org.findDivision(widget.prefillDivisionId);
      return [
        if (d != null) DropdownMenuItem(value: d.id, child: Text(d.name)),
      ];
    }
    if (_assignMode) {
      if (_leaderRole?.type == 'division') {
        final d = org.findDivision(_leaderRole!.id);
        return [
          if (d != null) DropdownMenuItem(value: d.id, child: Text(d.name)),
        ];
      }
      if (_leaderRole?.type == 'group' && assignee != null) {
        return [
          for (final d in org.divisions)
            if (assignee.divisionIds.contains(d.id))
              DropdownMenuItem(value: d.id, child: Text(d.name)),
        ];
      }
      return const [];
    }
    return [
      for (final d in myDivisions)
        DropdownMenuItem(value: d.id, child: Text(d.name)),
    ];
  }

  List<DropdownMenuItem<String>> _buildGroupItems(
    OrgStructure org,
    List<GroupInfo> myGroups,
    UserInfo? assignee,
  ) {
    if (widget.prefillGroupId != null) {
      final g = org.findGroup(widget.prefillGroupId);
      return [
        if (g != null) DropdownMenuItem(value: g.id, child: Text(g.name)),
      ];
    }
    if (_assignMode) {
      if (_leaderRole?.type == 'group') {
        final g = org.findGroup(_leaderRole!.id);
        return [
          if (g != null) DropdownMenuItem(value: g.id, child: Text(g.name)),
        ];
      }
      if (_leaderRole?.type == 'division' && assignee != null) {
        return [
          for (final g in org.groups)
            if (assignee.groupIds.contains(g.id))
              DropdownMenuItem(value: g.id, child: Text(g.name)),
        ];
      }
      return const [];
    }
    return [
      for (final g in myGroups)
        DropdownMenuItem(value: g.id, child: Text(g.name)),
    ];
  }

  Widget _buildActions(BuildContext context, OrgStructure? org) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: (_busy || org == null) ? null : () => _submit(org),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('提交'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DependencyPickerSheet extends StatefulWidget {
  const _DependencyPickerSheet({required this.tasks, required this.initial});
  final List<TaskItem> tasks;
  final Set<String> initial;

  @override
  State<_DependencyPickerSheet> createState() => _DependencyPickerSheetState();
}

class _DependencyPickerSheetState extends State<_DependencyPickerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择关联任务',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            Expanded(
              child: widget.tasks.isEmpty
                  ? const Center(
                      child: Text('暂无任务',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: widget.tasks.length,
                      itemBuilder: (_, i) {
                        final t = widget.tasks[i];
                        final selected = _selected.contains(t.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(t.id);
                            } else {
                              _selected.remove(t.id);
                            }
                          }),
                          title: Text(t.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(taskStatusStyle(t.status).label,
                              style: TextStyle(
                                  color: taskStatusStyle(t.status).fg,
                                  fontSize: 12)),
                          dense: true,
                        );
                      },
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text('确认'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
