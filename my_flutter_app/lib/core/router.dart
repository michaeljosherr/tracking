import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/screens/dashboard_screen.dart';
import 'package:my_flutter_app/screens/pairing_screen.dart';
import 'package:my_flutter_app/screens/tracker_detail_screen.dart';
import 'package:my_flutter_app/screens/alerts_screen.dart';
import 'package:my_flutter_app/screens/settings_screen.dart';
import 'package:my_flutter_app/screens/onboarding_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AppPreferencesProvider preferencesProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
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
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingScreen(),
      ),
      GoRoute(
        path: '/tracker/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TrackerDetailScreen(trackerId: id);
        },
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
}
