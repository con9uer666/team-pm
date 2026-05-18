import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/role.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/org/org_api.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import '../data/approvals_api.dart';
import 'widgets/admin_approve_sheet.dart';
import 'widgets/admin_user_edit_sheet.dart';

final _allUsersProvider =
    FutureProvider.autoDispose<List<UserInfo>>((ref) async {
  return ref.watch(orgApiProvider).getAllUsers();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _search = TextEditingController();

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingApplicantsProvider);
    final pendingCount = pending.maybeWhen(
      data: (l) => l.length,
      orElse: () => 0,
    );

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF3B82F6),
            tabs: [
              const Tab(text: '全部用户'),
              Tab(text: '待审核${pendingCount > 0 ? ' ($pendingCount)' : ''}'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ApprovedTab(searchCtl: _search),
              const _PendingTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovedTab extends ConsumerWidget {
  const _ApprovedTab({required this.searchCtl});
  final TextEditingController searchCtl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allUsersProvider);
    final keyword = searchCtl.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            controller: searchCtl,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: '搜索姓名或用户名',
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_allUsersProvider);
              await ref.read(_allUsersProvider.future);
            },
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(dioErrorMessage(e, '加载失败'),
                      style: TextStyle(color: AppTheme.dangerFg)),
                ),
              ]),
              data: (users) {
                final filtered = users.where((u) {
                  if (u.approvalStatus != 'approved') return false;
                  if (keyword.isEmpty) return true;
                  return u.realName.toLowerCase().contains(keyword) ||
                      u.username.toLowerCase().contains(keyword);
                }).toList();
                if (filtered.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text('无匹配用户',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final tile = ListTile(
                      title: Row(
                        children: [
                          Text(u.realName.isEmpty ? u.username : u.realName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          if (u.isSuperAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('超管',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFB45309))),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '@${u.username} · ${roleLabel(u.roleLevel, position: u.position)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editUser(context, ref, u),
                    );
                    if (i >= 6) return tile;
                    return FadeInUp.once(
                      key: ValueKey(u.id),
                      delay: Duration(milliseconds: 30 * i),
                      child: tile,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editUser(
      BuildContext context, WidgetRef ref, UserInfo user) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AdminUserEditSheet(user: user),
    );
    if (ok == true) ref.invalidate(_allUsersProvider);
  }
}

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingApplicantsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingApplicantsProvider);
        await ref.read(pendingApplicantsProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 80),
          Center(
            child: Text(dioErrorMessage(e, '加载失败'),
                style: TextStyle(color: AppTheme.dangerFg)),
          ),
        ]),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              Center(
                child: Text('暂无待审核用户',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              final card = _PendingCard(applicant: a);
              if (i >= 6) return card;
              return FadeInUp.once(
                key: ValueKey(a.id),
                delay: Duration(milliseconds: 40 * i),
                child: card,
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.applicant});
  final PendingApplicant applicant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              applicant.realName.isEmpty ? applicant.username : applicant.realName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('@${applicant.username}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (applicant.email != null && applicant.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(applicant.email!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626)),
                  child: const Text('驳回'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _approve(context, ref),
                  child: const Text('审核'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AdminApproveSheet(applicant: applicant),
    );
    if (ok == true) {
      ref.invalidate(pendingApplicantsProvider);
      ref.invalidate(_allUsersProvider);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reasonCtl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('驳回申请'),
        content: TextField(
          controller: reasonCtl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '请输入驳回原因'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonCtl.text.trim().isEmpty) return;
              Navigator.pop(context, reasonCtl.text.trim());
            },
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ref
          .read(approvalsApiProvider)
          .reject(applicant.id, reason);
      ref.invalidate(pendingApplicantsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已驳回')));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '驳回失败'))),
      );
    }
  }
}
