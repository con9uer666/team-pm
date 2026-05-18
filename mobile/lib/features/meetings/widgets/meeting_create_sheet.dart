import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../data/meetings_api.dart';

class _Target {
  const _Target({required this.scope, required this.id, required this.label});
  final String scope; // 'group' | 'division' | 'team'
  final String? id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is _Target && other.scope == scope && other.id == id;
  @override
  int get hashCode => Object.hash(scope, id);
}

class MeetingCreateSheet extends ConsumerStatefulWidget {
  const MeetingCreateSheet({super.key});

  @override
  ConsumerState<MeetingCreateSheet> createState() => _MeetingCreateSheetState();
}

class _MeetingCreateSheetState extends ConsumerState<MeetingCreateSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  _Target? _target;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final now = DateTime.now();
    final base = isStart
        ? (_start ?? now.add(const Duration(hours: 1)))
        : (_end ?? (_start ?? now).add(const Duration(hours: 1)));
    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: base,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        if (_end != null && !_end!.isAfter(dt)) {
          _end = dt.add(const Duration(hours: 1));
        }
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_target == null) {
      _snack('请选择会议范围');
      return;
    }
    if (_start == null || _end == null) {
      _snack('请选择开始与结束时间');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      _snack('结束时间必须晚于开始时间');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(meetingsApiProvider).create(
            title: _title.text.trim(),
            scope: _target!.scope,
            startTime: _start!,
            endTime: _end!,
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            location:
                _location.text.trim().isEmpty ? null : _location.text.trim(),
            groupId: _target!.scope == 'group' ? _target!.id : null,
            divisionId: _target!.scope == 'division' ? _target!.id : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      _snack(dioErrorMessage(e, '创建失败'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final org = ref.watch(orgStructureProvider).valueOrNull;

    final targets = <_Target>[];
    if (org != null && user != null) {
      // 我领导的兵种 / 技术组
      for (final d in org.divisions) {
        if (d.leaderIds.contains(user.id)) {
          targets.add(_Target(
              scope: 'division', id: d.id, label: '[兵种] ${d.name}'));
        }
      }
      for (final g in org.groups) {
        if (g.leaderIds.contains(user.id)) {
          targets.add(_Target(
              scope: 'group', id: g.id, label: '[技术组] ${g.name}'));
        }
      }
      // 项管 / 队长 / 超管可以发起全队会议
      if (user.isSuperAdmin || user.roleLevel >= 5) {
        targets.insert(0,
            const _Target(scope: 'team', id: null, label: '[全队] 全体成员'));
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
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
                  child: Text('创建会议',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: Form(
                  key: _form,
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      if (targets.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Text(
                            '你不是任何兵种或技术组的 leader，且没有发起全队会议权限',
                            style: TextStyle(
                                color: AppTheme.dangerFg, fontSize: 13),
                          ),
                        )
                      else
                        DropdownButtonFormField<_Target>(
                          initialValue: _target,
                          decoration:
                              const InputDecoration(labelText: '会议范围 *'),
                          items: [
                            for (final t in targets)
                              DropdownMenuItem(value: t, child: Text(t.label)),
                          ],
                          onChanged: (v) => setState(() => _target = v),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: '标题 *',
                          hintText: '会议标题',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '请填写标题' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _desc,
                        maxLength: 2000,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          labelText: '描述（可选）',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _location,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: '地点（可选）',
                          hintText: '腾讯会议链接 / 实体会议室 …',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: const Text('开始时间 *'),
                        subtitle: Text(_start == null ? '请选择' : _fmt(_start!)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickTime(true),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_send),
                        title: const Text('结束时间 *'),
                        subtitle: Text(_end == null ? '请选择' : _fmt(_end!)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickTime(false),
                      ),
                    ],
                  ),
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
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _busy || targets.isEmpty ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white),
                              )
                            : const Text('创建'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
