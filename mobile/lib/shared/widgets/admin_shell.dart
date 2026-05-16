import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';

/// Shell wrapper for the admin section. Renders a bottom NavigationBar with
/// up to 5 admin tabs visible directly; the remaining 2 live behind a
/// "更多" entry on the rightmost slot. Real screens land in [child] via the
/// parent ShellRoute defined in app_router.dart.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _AdminTab(route: '/admin', label: '概览', icon: Icons.dashboard_outlined),
    _AdminTab(route: '/admin/users', label: '用户', icon: Icons.people_outline),
    _AdminTab(route: '/admin/org', label: '组织', icon: Icons.account_tree_outlined),
    _AdminTab(route: '/admin/tasks', label: '任务', icon: Icons.assignment_outlined),
    _AdminTab(route: '/admin/more', label: '更多', icon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.canAdmin) {
      // Defensive: router already guards this. If we land here as a non-admin,
      // bounce home rather than render an empty shell.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = _tabs.indexWhere((t) => location.startsWith(t.route) && t.route != '/admin' ||
        location == '/admin' && t.route == '/admin');
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: '退出管理',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).setAdminMode(false);
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          if (_tabs[i].route == '/admin/more') {
            _showMoreSheet(context);
            return;
          }
          context.go(_tabs[i].route);
        },
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('会议'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.go('/admin/meetings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('目标'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.go('/admin/objectives');
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('围栏'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.go('/admin/fences');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTab {
  const _AdminTab({required this.route, required this.label, required this.icon});
  final String route;
  final String label;
  final IconData icon;
}

/// Placeholder for admin sub-pages until they are implemented in later
/// batches. Title is shown in the body so we know which slot is wired.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text('$title 待实现', style: const TextStyle(fontSize: 16, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}
