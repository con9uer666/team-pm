import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/org/org_api.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import 'widgets/admin_create_group_sheet.dart';
import 'widgets/admin_leader_picker_sheet.dart';

class AdminOrgScreen extends ConsumerWidget {
  const AdminOrgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgStructureProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(orgStructureProvider);
        await ref.read(orgStructureProvider.future);
      },
      child: org.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(dioErrorMessage(e, '加载失败'),
                  style: TextStyle(color: AppTheme.dangerFg)),
            ),
          ],
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            FadeInUp(child: _Section(
              title: '兵种组',
              actionLabel: '新增兵种组',
              onAdd: () => _addDivision(context, ref),
              children: [
                for (var i = 0; i < s.divisions.length; i++)
                  _DivisionCard(
                    division: s.divisions[i],
                    org: s,
                    onPickLeaders: () => _pickDivLeaders(
                      context,
                      ref,
                      s.divisions[i],
                      s.users,
                    ),
                  ),
                if (s.divisions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('暂无兵种组',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
              ],
            )),
            const SizedBox(height: 16),
            FadeInUp(delay: const Duration(milliseconds: 60), child: _Section(
              title: '技术组',
              actionLabel: '新增技术组',
              onAdd: () => _addGroup(context, ref),
              children: [
                for (var i = 0; i < s.groups.length; i++)
                  _GroupCard(
                    group: s.groups[i],
                    org: s,
                    onPickLeaders: () => _pickGroupLeaders(
                      context,
                      ref,
                      s.groups[i],
                      s.users,
                    ),
                  ),
                if (s.groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('暂无技术组',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _addGroup(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const AdminCreateGroupSheet(kind: 'group'),
    );
    if (ok == true) ref.invalidate(orgStructureProvider);
  }

  Future<void> _addDivision(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const AdminCreateGroupSheet(kind: 'division'),
    );
    if (ok == true) ref.invalidate(orgStructureProvider);
  }

  Future<void> _pickGroupLeaders(BuildContext context, WidgetRef ref,
      GroupInfo g, List<UserInfo> all) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AdminLeaderPickerSheet(
        title: '设置 ${g.name} 组长',
        currentLeaderIds: g.leaderIds,
        currentMemberIds: all
            .where((u) => u.groupIds.contains(g.id))
            .map((u) => u.id)
            .toList(),
        users: all,
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(orgApiProvider)
          .setGroupLeaders(id: g.id, leaderIds: result);
      ref.invalidate(orgStructureProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '设置组长失败'))),
      );
    }
  }

  Future<void> _pickDivLeaders(BuildContext context, WidgetRef ref,
      DivisionInfo d, List<UserInfo> all) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AdminLeaderPickerSheet(
        title: '设置 ${d.name} 负责人',
        currentLeaderIds: d.leaderIds,
        currentMemberIds: all
            .where((u) => u.divisionIds.contains(d.id))
            .map((u) => u.id)
            .toList(),
        users: all,
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(orgApiProvider)
          .setDivisionLeaders(id: d.id, leaderIds: result);
      ref.invalidate(orgStructureProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '设置负责人失败'))),
      );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.actionLabel,
    required this.onAdd,
    required this.children,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(actionLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DivisionCard extends StatelessWidget {
  const _DivisionCard({
    required this.division,
    required this.org,
    required this.onPickLeaders,
  });
  final DivisionInfo division;
  final OrgStructure org;
  final VoidCallback onPickLeaders;

  @override
  Widget build(BuildContext context) {
    final leaders = division.leaderIds.map((id) => org.userName(id)).where((n) => n.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(division.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if ((division.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(division.description!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  leaders.isEmpty ? '尚未设负责人' : '负责人：${leaders.join('、')}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
              TextButton(
                onPressed: onPickLeaders,
                child: const Text('设负责人'),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.org,
    required this.onPickLeaders,
  });
  final GroupInfo group;
  final OrgStructure org;
  final VoidCallback onPickLeaders;

  @override
  Widget build(BuildContext context) {
    final leaders = group.leaderIds
        .map((id) => org.userName(id))
        .where((n) => n.isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  leaders.isEmpty ? '尚未设组长' : '组长：${leaders.join('、')}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onPickLeaders, child: const Text('设组长')),
        ],
      ),
    );
  }
}
