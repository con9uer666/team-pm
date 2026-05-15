import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../data/tasks_api.dart';

class TaskCreateSheet extends ConsumerStatefulWidget {
  const TaskCreateSheet({super.key, required this.isLeader});
  final bool isLeader;

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _LeaderRole {
  _LeaderRole({required this.type, required this.id, required this.label});
  final String type; // 'division' | 'group'
  final String id;
  final String label;
}

class _OtherDimOpt {
  const _OtherDimOpt({required this.id, required this.label});
  final String id;
  final String label;
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _requirements = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 3));
  int _priority = 0;

  bool _assignMode = false;
  _LeaderRole? _role;
  String? _assigneeId;

  // The "other dimension" — auto-filled when assignee has a single option,
  // user-picked from [_otherOpts] when multiple. Mirrors Tasks.vue onAssigneeChange.
  String? _otherDimId;
  List<_OtherDimOpt> _otherOpts = const [];

  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _due,
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (time == null) return;
    setState(() {
      _due = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  /// Recompute the other-dimension state when assignee or role changes.
  /// Mirrors Tasks.vue lines 194-211.
  void _refreshOtherDim(OrgStructure org) {
    if (_role == null || _assigneeId == null) {
      _otherDimId = null;
      _otherOpts = const [];
      return;
    }
    UserInfo? assignee;
    for (final u in org.users) {
      if (u.id == _assigneeId) {
        assignee = u;
        break;
      }
    }
    if (assignee == null) {
      _otherDimId = null;
      _otherOpts = const [];
      return;
    }
    final opts = <_OtherDimOpt>[];
    if (_role!.type == 'division') {
      // Need to pick a group. Use assignee.groupIds ∩ org.groups.
      for (final g in org.groups) {
        if (assignee.groupIds.contains(g.id)) {
          opts.add(_OtherDimOpt(id: g.id, label: g.name));
        }
      }
    } else {
      // Need to pick a division.
      for (final d in org.divisions) {
        if (assignee.divisionIds.contains(d.id)) {
          opts.add(_OtherDimOpt(id: d.id, label: d.name));
        }
      }
    }
    if (opts.length == 1) {
      _otherDimId = opts.first.id;
      _otherOpts = const [];
    } else if (opts.isEmpty) {
      _otherDimId = null;
      _otherOpts = const [];
    } else {
      // Keep existing pick if still valid, else clear.
      if (_otherDimId != null && !opts.any((o) => o.id == _otherDimId)) {
        _otherDimId = null;
      }
      _otherOpts = opts;
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_assignMode) {
      if (_role == null || _assigneeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择身份和被分配人')),
        );
        return;
      }
      if (_otherDimId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_otherOpts.isEmpty
              ? '该成员不属于其它维度的任何组织，无法派发'
              : '请选择${_role!.type == 'division' ? '技术组' : '兵种'}')),
        );
        return;
      }
      if (_requirements.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写验收标准')),
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(tasksApiProvider);
      final isDivisionRole = _role?.type == 'division';
      await api.create(
        title: _title.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        completionRequirements:
            _assignMode ? _requirements.text.trim() : null,
        dueDate: _due,
        priority: _priority,
        divisionId: _assignMode
            ? (isDivisionRole ? _role!.id : _otherDimId)
            : null,
        groupId: _assignMode
            ? (isDivisionRole ? _otherDimId : _role!.id)
            : null,
        assigneeId: _assignMode ? _assigneeId : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务已创建')),
      );
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e, '创建失败'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.user?.id;
    final orgAsync = widget.isLeader ? ref.watch(orgStructureProvider) : null;

    final leaderRoles = <_LeaderRole>[];
    List<UserInfo> candidates = const [];
    if (widget.isLeader && orgAsync != null) {
      orgAsync.whenData((org) {
        for (final d in org.divisions) {
          if (d.leaderIds.contains(userId)) {
            leaderRoles.add(_LeaderRole(type: 'division', id: d.id, label: '[兵种] ${d.name}'));
          }
        }
        for (final g in org.groups) {
          if (g.leaderIds.contains(userId)) {
            leaderRoles.add(_LeaderRole(type: 'group', id: g.id, label: '[技术组] ${g.name}'));
          }
        }
        if (_role != null) {
          candidates = org.users.where((u) {
            if (u.id == userId) return false;
            if (_role!.type == 'division') return u.divisionIds.contains(_role!.id);
            return u.groupIds.contains(_role!.id);
          }).toList();
        }
        _refreshOtherDim(org);
      });
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Form(
            key: _form,
            child: Column(
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
                      '新建任务',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: '任务标题',
                          hintText: '简短描述',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _desc,
                        decoration: const InputDecoration(
                          labelText: '描述（可选）',
                          hintText: '补充任务背景或要求',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: const Text('截止时间'),
                        subtitle: Text(
                          '${_due.year}-${_due.month.toString().padLeft(2, '0')}-${_due.day.toString().padLeft(2, '0')} '
                          '${_due.hour.toString().padLeft(2, '0')}:${_due.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.priority_high, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          const Text('优先级'),
                          const Spacer(),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('普通')),
                              ButtonSegment(value: 1, label: Text('重要')),
                              ButtonSegment(value: 2, label: Text('紧急')),
                            ],
                            selected: {_priority},
                            onSelectionChanged: (s) => setState(() => _priority = s.first),
                          ),
                        ],
                      ),
                      if (widget.isLeader) ...[
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('分配给组员'),
                          subtitle: const Text('关闭则分配给自己'),
                          value: _assignMode,
                          onChanged: leaderRoles.isEmpty
                              ? null
                              : (v) => setState(() {
                                    _assignMode = v;
                                    if (!v) {
                                      _role = null;
                                      _assigneeId = null;
                                      _otherDimId = null;
                                      _otherOpts = const [];
                                    }
                                  }),
                        ),
                        if (_assignMode) ...[
                          const SizedBox(height: 8),
                          if (orgAsync?.isLoading == true)
                            const Center(child: CircularProgressIndicator())
                          else ...[
                            DropdownButtonFormField<_LeaderRole>(
                              initialValue: _role,
                              decoration: const InputDecoration(labelText: '我的身份'),
                              items: [
                                for (final r in leaderRoles)
                                  DropdownMenuItem(value: r, child: Text(r.label)),
                              ],
                              onChanged: (v) => setState(() {
                                _role = v;
                                _assigneeId = null;
                                _otherDimId = null;
                                _otherOpts = const [];
                              }),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _assigneeId,
                              decoration: const InputDecoration(labelText: '被分配人'),
                              items: [
                                for (final u in candidates)
                                  DropdownMenuItem(
                                    value: u.id,
                                    child: Text('${u.realName} (@${u.username})'),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                _assigneeId = v;
                                _otherDimId = null;
                              }),
                            ),
                            if (_assigneeId != null && _otherOpts.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _otherDimId,
                                decoration: InputDecoration(
                                  labelText: _role?.type == 'division'
                                      ? '所属技术组'
                                      : '所属兵种',
                                  helperText: '该成员属于多个，请手动选择',
                                ),
                                items: [
                                  for (final o in _otherOpts)
                                    DropdownMenuItem(value: o.id, child: Text(o.label)),
                                ],
                                onChanged: (v) => setState(() => _otherDimId = v),
                              ),
                            ],
                            if (_assigneeId != null &&
                                _otherOpts.isEmpty &&
                                _otherDimId == null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '该成员不属于其它维度的任何组织，无法派发',
                                        style: TextStyle(
                                            color: Color(0xFFB91C1C), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_otherDimId != null) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _requirements,
                                decoration: const InputDecoration(
                                  labelText: '验收标准',
                                  hintText: '说明任务完成的判定条件',
                                ),
                                maxLines: 3,
                                validator: (v) {
                                  if (!_assignMode) return null;
                                  if (v == null || v.trim().isEmpty) {
                                    return '请填写验收标准';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
                Container(
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
                          onPressed: _busy ? null : _submit,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
