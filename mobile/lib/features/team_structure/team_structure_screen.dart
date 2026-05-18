import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/role.dart';
import '../../core/network/dio_client.dart';
import '../../core/org/users_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/fade_in.dart';

class TeamStructureScreen extends ConsumerWidget {
  const TeamStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orgStructureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('团队架构')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orgStructureProvider);
          await ref.read(orgStructureProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(dioErrorMessage(e, '加载失败'),
                      style: TextStyle(color: AppTheme.dangerFg)),
                ),
              ),
            ],
          ),
          data: (org) => _Body(org: org),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.org});
  final OrgStructure org;

  @override
  Widget build(BuildContext context) {
    final topMgmt = org.users.where((u) => u.roleLevel >= 5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        FadeInUp(
          child: _Section(
            title: '管理层',
            child: topMgmt.isEmpty
                ? const _Empty(text: '暂无管理层成员')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final u in topMgmt)
                        _PersonChip(
                          name: u.realName.isEmpty ? u.username : u.realName,
                          label: roleLabel(u.roleLevel, position: u.position),
                          isLeader: true,
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          delay: const Duration(milliseconds: 60),
          child: _Section(
            title: '兵种组',
            child: Column(
              children: [
                for (final d in org.divisions)
                  _ExpandableBranch(
                    name: d.name,
                    leaderIds: d.leaderIds,
                    members: org.users
                        .where((u) =>
                            u.divisionIds.contains(d.id) &&
                            !d.leaderIds.contains(u.id))
                        .toList(),
                    org: org,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          delay: const Duration(milliseconds: 120),
          child: _Section(
            title: '技术组',
            child: Column(
              children: [
                for (final g in org.groups)
                  _ExpandableBranch(
                    name: g.name,
                    leaderIds: g.leaderIds,
                    members: org.users
                        .where((u) =>
                            u.groupIds.contains(g.id) &&
                            !g.leaderIds.contains(u.id))
                        .toList(),
                    org: org,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExpandableBranch extends StatefulWidget {
  const _ExpandableBranch({
    required this.name,
    required this.leaderIds,
    required this.members,
    required this.org,
  });

  final String name;
  final List<String> leaderIds;
  final List<UserInfo> members;
  final OrgStructure org;

  @override
  State<_ExpandableBranch> createState() => _ExpandableBranchState();
}

class _ExpandableBranchState extends State<_ExpandableBranch> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final leaderNames = widget.leaderIds
        .map((id) => widget.org.userName(id))
        .where((n) => n.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 4),
                Text(widget.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (leaderNames.isNotEmpty)
                  Flexible(
                    child: Text(
                      leaderNames.join('、'),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF16A34A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 0, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leaderNames.isNotEmpty) ...[
                        const Text('组长',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final n in leaderNames)
                              _PersonChip(name: n, isLeader: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Text('组员',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      widget.members.isEmpty
                          ? const _Empty(text: '暂无组员')
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final m in widget.members)
                                  _PersonChip(
                                    name: m.realName.isEmpty
                                        ? m.username
                                        : m.realName,
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.name, this.label, this.isLeader = false});
  final String name;
  final String? label;
  final bool isLeader;

  @override
  Widget build(BuildContext context) {
    final bg = isLeader ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9);
    final fg = isLeader ? const Color(0xFF15803D) : const Color(0xFF334155);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label == null ? name : '$name · $label',
        style:
            TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
    );
  }
}
