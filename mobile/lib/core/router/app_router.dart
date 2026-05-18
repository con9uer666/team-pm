import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/fences/admin_fences_screen.dart';
import '../../features/admin/meetings/admin_meetings_screen.dart';
import '../../features/admin/objectives/admin_objectives_screen.dart';
import '../../features/admin/org/admin_org_screen.dart';
import '../../features/admin/tasks/admin_tasks_screen.dart';
import '../../features/admin/users/admin_users_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/collaborate/collaborate_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/meetings/meetings_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/pending/pending_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/spaces/my_space_screen.dart';
import '../../features/spaces/space_detail_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/team_structure/team_structure_screen.dart';
import '../../shared/widgets/admin_shell.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../auth/auth_controller.dart';
import 'router_refresh.dart';

/// Routes that a non-approved (guest) user can still see.
const _guestAllowed = {'pending', 'profile', 'notifications', 'team-structure'};

/// Routes that don't require auth.
const _publicRoutes = {'login', 'register'};

/// Route names that require admin mode (canAdmin && adminMode).
const _adminRoutes = {
  'admin-dashboard',
  'admin-users',
  'admin-org',
  'admin-tasks',
  'admin-meetings',
  'admin-objectives',
  'admin-fences',
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref, authControllerProvider);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final name = state.topRoute?.name ?? '';

      // Until init() finishes, park users on a loading screen.
      if (!auth.ready) {
        return location == '/loading' ? null : '/loading';
      }

      // Once ready, never leave anyone on /loading.
      if (location == '/loading') {
        if (auth.user == null) return '/login';
        if (auth.isGuest) return '/pending';
        return '/';
      }

      final isPublic = _publicRoutes.contains(name);

      if (auth.user == null) {
        return isPublic ? null : '/login';
      }

      // Already logged in but visiting /login → bounce home.
      if (isPublic) return '/';

      // Guest (pending approval) can only access whitelisted routes.
      if (auth.isGuest) {
        if (name == 'pending') return null;
        if (_guestAllowed.contains(name)) return null;
        return '/pending';
      }

      // Admin routes require canAdmin + adminMode toggle.
      if (_adminRoutes.contains(name)) {
        if (!auth.canAdmin || !auth.adminMode) return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        name: 'loading',
        builder: (_, _) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pending',
        name: 'pending',
        builder: (_, _) => const PendingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: TasksScreen()),
          ),
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AttendanceScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/team-structure',
            name: 'team-structure',
            builder: (_, _) => const TeamStructureScreen(),
          ),
          GoRoute(
            path: '/spaces',
            name: 'my-space',
            builder: (_, _) => const MySpaceScreen(),
          ),
          GoRoute(
            path: '/spaces/:scope/:id',
            name: 'space-detail',
            builder: (_, state) => SpaceDetailScreen(
              scope: state.pathParameters['scope']!,
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/meetings',
            name: 'meetings',
            builder: (_, _) => const MeetingsScreen(),
          ),
          GoRoute(
            path: '/collaborate',
            name: 'collaborate',
            builder: (_, _) => const CollaborateScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            name: 'admin-dashboard',
            pageBuilder: (_, _) => const NoTransitionPage(
                child: AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/admin/users',
            name: 'admin-users',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdminUsersScreen()),
          ),
          GoRoute(
            path: '/admin/org',
            name: 'admin-org',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdminOrgScreen()),
          ),
          GoRoute(
            path: '/admin/tasks',
            name: 'admin-tasks',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdminTasksScreen()),
          ),
          GoRoute(
            path: '/admin/meetings',
            name: 'admin-meetings',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdminMeetingsScreen()),
          ),
          GoRoute(
            path: '/admin/objectives',
            name: 'admin-objectives',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdminObjectivesScreen()),
          ),
          GoRoute(
            path: '/admin/fences',
            name: 'admin-fences',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdminFencesScreen()),
          ),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
