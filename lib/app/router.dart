import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/activity/presentation/screens/activity_log_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/dashboard/presentation/screens/settings_screen.dart';
import '../features/departments/domain/models/department.dart';
import '../features/departments/presentation/screens/department_create_screen.dart';
import '../features/departments/presentation/screens/department_detail_screen.dart';
import '../features/departments/presentation/screens/department_list_screen.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/tasks/presentation/screens/task_create_screen.dart';
import '../features/tasks/presentation/screens/task_detail_screen.dart';
import '../features/memos/presentation/screens/memo_detail_screen.dart';
import '../features/memos/presentation/screens/memo_list_screen.dart';
import '../features/tasks/presentation/screens/task_list_screen.dart';
import '../features/tasks/providers/task_provider.dart';
import '../shared/widgets/app_navigation_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter 라우터 Provider
final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final isRecovery = ref.watch(passwordRecoveryProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      const resetPath = '/auth/reset-password';
      final loc = state.matchedLocation;
      // 공개(비로그인) 접근 가능 경로. reset-password는 recovery 링크로
      // 진입하는데, Supabase가 URL 토큰을 파싱하기 전에는 isLoggedIn=false
      // 상태이므로 로그인 가드를 우회해야 한다.
      final isPublic = loc == '/login' ||
          loc == '/register' ||
          loc == resetPath;

      // 이미 복구 세션이 활성화됐다면 재설정 화면으로 강제 이동
      if (isRecovery && loc != resetPath) return resetPath;

      if (!isLoggedIn && !isPublic) return '/login';
      if (isLoggedIn && !isRecovery &&
          (loc == '/login' || loc == '/register')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // Main app routes with shell navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return _ShellWithNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/departments',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DepartmentListScreen()),
          ),
          GoRoute(
            path: '/tasks',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TaskListScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CalendarScreen()),
          ),
          GoRoute(
            path: '/memos',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MemoListScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),

      // Activity log
      GoRoute(
        path: '/activity',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ActivityLogScreen(),
      ),

      // ─── Task standalone routes ───
      GoRoute(
        path: '/tasks/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TaskCreateScreen(),
      ),
      GoRoute(
        path: '/tasks/:taskId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          return TaskDetailScreen(taskId: taskId);
        },
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              return _TaskEditLoader(taskId: taskId);
            },
          ),
        ],
      ),

      // ─── Department routes ───
      GoRoute(
        path: '/departments/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DepartmentCreateScreen(),
      ),
      GoRoute(
        path: '/departments/:departmentId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['departmentId']!;
          return DepartmentDetailScreen(departmentId: id);
        },
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final extra = state.extra;
              return DepartmentCreateScreen(
                department: extra is Department ? extra : null,
              );
            },
          ),
        ],
      ),

      // ─── Memo routes ───
      GoRoute(
        path: '/memos/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MemoDetailScreen(),
      ),
      GoRoute(
        path: '/memos/:memoId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final memoId = state.pathParameters['memoId']!;
          return MemoDetailScreen(memoId: memoId);
        },
      ),
    ],
  );
});

/// 태스크 수정 로더
class _TaskEditLoader extends ConsumerWidget {
  const _TaskEditLoader({required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    return taskAsync.when(
      data: (task) => TaskCreateScreen(task: task),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('오류: $e')),
      ),
    );
  }
}

/// Navigation Shell with AppBar + NavigationShell
class _ShellWithNav extends ConsumerWidget {
  const _ShellWithNav({required this.child});

  final Widget child;

  static const _paths = [
    '/dashboard',
    '/departments',
    '/tasks',
    '/calendar',
    '/memos',
    '/settings',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _paths.indexOf(location).clamp(0, _paths.length - 1);

    return AppNavigationShell(
      currentIndex: currentIndex,
      onDestinationSelected: (index) {
        context.go(_paths[index]);
      },
      child: child,
    );
  }
}
