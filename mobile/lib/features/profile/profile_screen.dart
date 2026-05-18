import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/models/role.dart';
import '../../shared/widgets/fade_in.dart';

String _avatarInitial(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'U';
  // Use `characters.first` to handle surrogate pairs (emoji, CJK extension) safely.
  return trimmed.characters.first;
}

/// Returns just the host:port part of the API base, hiding scheme and `/api`
/// path for a cleaner display in the "About" tile.
String _apiHost() {
  final base = AppConfig.apiBase;
  // strip scheme
  final noScheme = base.replaceFirst(RegExp(r'^https?://'), '');
  // strip path
  final slash = noScheme.indexOf('/');
  return slash < 0 ? noScheme : noScheme.substring(0, slash);
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final role = user == null ? '' : roleLabel(user.roleLevel, position: user.position);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeInUp(child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF3B82F6),
                      child: Text(
                        _avatarInitial(user?.realName),
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.realName ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user?.username ?? ''}',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          if (role.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(role, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 40),
              child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.workspaces_outline,
                        color: Color(0xFF3B82F6)),
                    title: const Text('我的空间'),
                    subtitle: const Text('我所属的兵种 / 技术组'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/spaces'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.account_tree_outlined,
                        color: Color(0xFF0EA5E9)),
                    title: const Text('团队架构'),
                    subtitle: const Text('管理层 / 兵种组 / 技术组'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/team-structure'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.event_outlined,
                        color: Color(0xFF8B5CF6)),
                    title: const Text('会议'),
                    subtitle: const Text('查看 / 签到 / 纪要'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/meetings'),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            if (auth.canAdmin)
              FadeInUp(
                delay: const Duration(milliseconds: 80),
                child: Card(
                child: ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Color(0xFF7C3AED)),
                  title: const Text('进入管理后台'),
                  subtitle: const Text('查看管理概览 / 审批用户 / 编辑组织 / 维护围栏'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).setAdminMode(true);
                    if (context.mounted) context.go('/admin');
                  },
                ),
              )),
            if (auth.canAdmin) const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 120),
              child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('关于'),
                    subtitle: Text('服务: ${_apiHost()}'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    title: const Text('退出登录', style: TextStyle(color: Color(0xFFEF4444))),
                    onTap: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
