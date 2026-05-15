import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabInfo(route: '/', name: 'home', icon: Icons.home_outlined, label: '首页'),
    _TabInfo(route: '/tasks', name: 'tasks', icon: Icons.assignment_outlined, label: '任务'),
    _TabInfo(
        route: '/attendance',
        name: 'attendance',
        icon: Icons.location_on_outlined,
        label: '打卡'),
    _TabInfo(route: '/profile', name: 'profile', icon: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final location = GoRouterState.of(context).uri.path;
    var currentIndex = _tabs.indexWhere((t) => t.route == location);
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: auth.user == null
          ? null
          : NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_tabs[i].route),
              destinations: [
                for (final t in _tabs)
                  NavigationDestination(icon: Icon(t.icon), label: t.label),
              ],
            ),
    );
  }
}

class _TabInfo {
  const _TabInfo({
    required this.route,
    required this.name,
    required this.icon,
    required this.label,
  });
  final String route;
  final String name;
  final IconData icon;
  final String label;
}
