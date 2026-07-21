import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/providers.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/biometric_login_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/profile_page.dart';
import '../features/auth/presentation/security_page.dart';
import '../features/auth/presentation/two_factor_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/tasks/presentation/tasks_page.dart';
import '../features/notes/presentation/notes_page.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/habits/presentation/habits_page.dart';
import '../features/journal/presentation/journal_page.dart';
import '../features/expenses/presentation/expenses_page.dart';
import '../features/goals/presentation/goals_page.dart';
import '../features/focus/presentation/focus_page.dart';
import '../features/health/presentation/health_page.dart';
import '../features/files/presentation/files_page.dart';
import '../features/assistant/presentation/assistant_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/admin/presentation/admin_page.dart';
import 'shell/lifeos_shell.dart';

GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRouterRefreshListenable(ref),
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AuthUser?> session = ref.read(authSessionProvider);
      final bool isLoggingIn = state.matchedLocation == '/login';
      final bool isOnAuthOnlyRoute = <String>{
        '/login',
        '/forgot-password',
        '/otp',
        '/biometric-login',
      }.contains(state.matchedLocation);

      return session.when(
        data: (AuthUser? user) {
          if (user == null) {
            return isOnAuthOnlyRoute ? null : '/login';
          }

          if (isLoggingIn) {
            return '/home';
          }

          return null;
        },
        loading: () => null,
        error: (_, _) => '/login',
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) {
          return const ForgotPasswordPage();
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (BuildContext context, GoRouterState state) {
          return const OtpPage();
        },
      ),
      GoRoute(
        path: '/biometric-login',
        builder: (BuildContext context, GoRouterState state) {
          return const BiometricLoginPage();
        },
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return LifeOSShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (BuildContext context, GoRouterState state) {
              return const HomePage();
            },
          ),
          GoRoute(
            path: '/tasks',
            builder: (BuildContext context, GoRouterState state) {
              return const TasksPage();
            },
          ),
          GoRoute(
            path: '/notes',
            builder: (BuildContext context, GoRouterState state) {
              return const NotesPage();
            },
          ),
          GoRoute(
            path: '/calendar',
            builder: (BuildContext context, GoRouterState state) {
              return const CalendarPage();
            },
          ),
          GoRoute(
            path: '/habits',
            builder: (BuildContext context, GoRouterState state) {
              return const HabitsPage();
            },
          ),
          GoRoute(
            path: '/journal',
            builder: (BuildContext context, GoRouterState state) {
              return const JournalPage();
            },
          ),
          GoRoute(
            path: '/expenses',
            builder: (BuildContext context, GoRouterState state) {
              return const ExpensesPage();
            },
          ),
          GoRoute(
            path: '/goals',
            builder: (BuildContext context, GoRouterState state) {
              return const GoalsPage();
            },
          ),
          GoRoute(
            path: '/focus',
            builder: (BuildContext context, GoRouterState state) {
              return const FocusPage();
            },
          ),
          GoRoute(
            path: '/health',
            builder: (BuildContext context, GoRouterState state) {
              return const HealthPage();
            },
          ),
          GoRoute(
            path: '/files',
            builder: (BuildContext context, GoRouterState state) {
              return const FilesPage();
            },
          ),
          GoRoute(
            path: '/assistant',
            builder: (BuildContext context, GoRouterState state) {
              return const AssistantPage();
            },
          ),
          GoRoute(
            path: '/search',
            builder: (BuildContext context, GoRouterState state) {
              return const SearchPage();
            },
          ),
          GoRoute(
            path: '/notifications',
            builder: (BuildContext context, GoRouterState state) {
              return const NotificationsPage();
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (BuildContext context, GoRouterState state) {
              return const SettingsPage();
            },
          ),
          GoRoute(
            path: '/admin',
            builder: (BuildContext context, GoRouterState state) {
              return const AdminPage();
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (BuildContext context, GoRouterState state) {
              return const ProfilePage();
            },
          ),
          GoRoute(
            path: '/security',
            builder: (BuildContext context, GoRouterState state) {
              return const SecurityPage();
            },
          ),
          GoRoute(
            path: '/two-factor',
            builder: (BuildContext context, GoRouterState state) {
              return const TwoFactorPage();
            },
          ),
        ],
      ),
    ],
  );
}

class _AuthRouterRefreshListenable extends ChangeNotifier {
  _AuthRouterRefreshListenable(Ref ref) {
    ref.listen<AsyncValue<AuthUser?>>(authSessionProvider, (_, _) {
      notifyListeners();
    });
  }
}
