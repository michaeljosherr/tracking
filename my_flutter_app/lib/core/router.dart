import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/screens/alerts_screen.dart';
import 'package:my_flutter_app/screens/dashboard_screen.dart';
import 'package:my_flutter_app/screens/settings_screen.dart';
import 'package:my_flutter_app/screens/onboarding_screen.dart';
import 'package:my_flutter_app/screens/hub_select_screen.dart';
import 'package:my_flutter_app/screens/hub_trackers_screen.dart';
import 'package:my_flutter_app/screens/all_trackers_radar_screen.dart';
import 'package:my_flutter_app/screens/tracker_detail_screen.dart';
import 'package:my_flutter_app/widgets/app_tab_shell.dart';
import 'package:my_flutter_app/core/route_observers.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AppPreferencesProvider preferencesProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    observers: [appRouteObserver],
    refreshListenable: preferencesProvider,
    redirect: (context, state) {
      final hasCompletedOnboarding = preferencesProvider.onboardingCompleted;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!hasCompletedOnboarding && !isOnboarding) {
        return '/onboarding';
      }

      if (hasCompletedOnboarding && isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppTabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AlertsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) => '/settings',
      ),
      GoRoute(
        path: '/pairing',
        redirect: (context, state) => '/hubs/select',
      ),
      GoRoute(
        path: '/hubs/select',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const HubSelectScreen(),
        ),
      ),
      GoRoute(
        path: '/hubs/trackers',
        pageBuilder: (context, state) {
          final hubId = state.uri.queryParameters['hubId'];
          if (hubId == null || hubId.isEmpty) {
            return const MaterialPage<void>(
              child: Scaffold(
                body: Center(child: Text('Missing hub')),
              ),
            );
          }
          return MaterialPage<void>(
            key: state.pageKey,
            child: HubTrackersScreen(hubBleId: hubId),
          );
        },
      ),
      GoRoute(
        path: '/radar',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const AllTrackersRadarScreen(),
        ),
      ),
      GoRoute(
        path: '/tracker/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TrackerDetailScreen(trackerId: id);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
}
