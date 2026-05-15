import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/pending/pending_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../auth/auth_controller.dart';
import 'router_refresh.dart';

/// Routes that a non-approved (guest) user can still see.
const _guestAllowed = {'pending', 'profile', 'notifications', 'team-structure'};

/// Routes that don't require auth.
const _publicRoutes = {'login', 'register'};

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
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (_, _) => const TasksScreen(),
          ),
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            builder: (_, _) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, _) => const ProfileScreen(),
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
