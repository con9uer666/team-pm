import 'package:flutter/material.dart';

import '../../../../core/org/users_api.dart';

/// Picks which users should be set as leaders of a given group/division.
///
/// Mirrors the web flow: the dialog has two sections — current members and
/// everyone else. Selecting a non-member implicitly adds them to the group
/// (backend handles the join via [setGroupLeaders] / [setDivisionLeaders]).
class AdminLeaderPickerSheet extends StatefulWidget {
  const AdminLeaderPickerSheet({
    super.key,
    required this.title,
    required this.currentLeaderIds,
    required this.currentMemberIds,
    required this.users,
  });

  final String title;
  final List<String> currentLeaderIds;
  final List<String> currentMemberIds;
  final List<UserInfo> users;

  @override
  State<AdminLeaderPickerSheet> createState() => _AdminLeaderPickerSheetState();
}

class _AdminLeaderPickerSheetState extends State<AdminLeaderPickerSheet> {
  late Set<String> _selected;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentLeaderIds.toSet();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _search.text.trim().toLowerCase();
    final byId = {for (final u in widget.users) u.id: u};
    final members = widget.currentMemberIds
        .map((id) => byId[id])
        .whereType<UserInfo>()
        .where((u) => _match(u, keyword))
        .toList();
    final others = widget.users
        .where((u) => !widget.currentMemberIds.contains(u.id) && _match(u, keyword))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Column(
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
              child: Text(widget.title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: '搜索姓名或用户名',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (members.isNotEmpty) ...[
                  const _Header('已是本组成员'),
                  for (final u in members) _row(u, joining: false),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _Header('非成员（勾选后自动加入并升组长）'),
                  for (final u in others) _row(u, joining: true),
                ],
                if (members.isEmpty && others.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('暂无匹配用户',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
              ],
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
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    child: Text('确定 (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(UserInfo u, {required bool joining}) {
    final checked = _selected.contains(u.id);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: checked,
      onChanged: (v) => setState(() {
        if (v == true) {
          _selected.add(u.id);
        } else {
          _selected.remove(u.id);
        }
      }),
      title: Text(u.realName.isEmpty ? u.username : u.realName),
      subtitle: Text(joining ? '@${u.username} · 当前非成员' : '@${u.username}',
          style: const TextStyle(fontSize: 12)),
    );
  }

  bool _match(UserInfo u, String keyword) {
    if (keyword.isEmpty) return true;
    final name = u.realName.toLowerCase();
    final username = u.username.toLowerCase();
    return name.contains(keyword) || username.contains(keyword);
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
    );
  }
}
