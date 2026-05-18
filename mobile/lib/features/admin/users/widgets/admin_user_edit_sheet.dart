import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/role.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/org/org_api.dart';
import '../../../../core/org/users_api.dart';

/// Edit role / position / groups / divisions for an existing approved user.
class AdminUserEditSheet extends ConsumerStatefulWidget {
  const AdminUserEditSheet({super.key, required this.user});
  final UserInfo user;

  @override
  ConsumerState<AdminUserEditSheet> createState() => _AdminUserEditSheetState();
}

class _AdminUserEditSheetState extends ConsumerState<AdminUserEditSheet> {
  late int _roleLevel = widget.user.roleLevel;
  late Position? _position = widget.user.position;
  late Set<String> _groupIds = widget.user.groupIds.toSet();
  late Set<String> _divisionIds = widget.user.divisionIds.toSet();
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(orgApiProvider);
      // role / position
      await api.updateRole(
        id: widget.user.id,
        roleLevel: _roleLevel,
        position: _roleLevel == 5 ? _position : null,
      );
      // groups + divisions (always send to keep current behaviour explicit)
      await api.assignGroups(id: widget.user.id, groupIds: _groupIds.toList());
      await api.assignDivisions(
          id: widget.user.id, divisionIds: _divisionIds.toList());
      ref.invalidate(orgStructureProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '保存失败'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(orgStructureProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '编辑 ${widget.user.realName.isEmpty ? widget.user.username : widget.user.realName}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  const Text('角色', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final lvl in const [1, 2, 3, 5, 6])
                        ChoiceChip(
                          label: Text(roleLabel(lvl)),
                          selected: _roleLevel == lvl,
                          onSelected: (_) => setState(() {
                            _roleLevel = lvl;
                            if (lvl != 5) _position = null;
                          }),
                        ),
                    ],
                  ),
                  if (_roleLevel == 5) ...[
                    const SizedBox(height: 12),
                    const Text('管理层职位', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('项目管理'),
                          selected: _position == Position.projectManager,
                          onSelected: (_) => setState(
                              () => _position = Position.projectManager),
                        ),
                        ChoiceChip(
                          label: const Text('队长'),
                          selected: _position == Position.teamCaptain,
                          onSelected: (_) => setState(
                              () => _position = Position.teamCaptain),
                        ),
                        ChoiceChip(
                          label: const Text('副队长'),
                          selected: _position == Position.viceCaptain,
                          onSelected: (_) => setState(
                              () => _position = Position.viceCaptain),
                        ),
                      ],
                    ),
                  ],
                  if (org != null) ...[
                    const SizedBox(height: 16),
                    const Text('技术组', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final g in org.groups)
                          FilterChip(
                            label: Text(g.name),
                            selected: _groupIds.contains(g.id),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _groupIds.add(g.id);
                              } else {
                                _groupIds.remove(g.id);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('兵种组', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final d in org.divisions)
                          FilterChip(
                            label: Text(d.name),
                            selected: _divisionIds.contains(d.id),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _divisionIds.add(d.id);
                              } else {
                                _divisionIds.remove(d.id);
                              }
                            }),
                          ),
                      ],
                    ),
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
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
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
                          : const Text('保存'),
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
