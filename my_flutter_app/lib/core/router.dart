import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/screens/login_screen.dart';
import 'package:my_flutter_app/screens/dashboard_screen.dart';
import 'package:my_flutter_app/screens/pairing_screen.dart';
import 'package:my_flutter_app/screens/tracker_detail_screen.dart';
import 'package:my_flutter_app/screens/alerts_screen.dart';
import 'package:my_flutter_app/screens/settings_screen.dart';
import 'package:my_flutter_app/screens/onboarding_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(
  AuthProvider authProvider,
  AppPreferencesProvider preferencesProvider,
) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([authProvider, preferencesProvider]),
    redirect: (context, state) {
      final isLoggedIn = authProvider.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final hasCompletedOnboarding = preferencesProvider.onboardingCompleted;
      final isOnboarding = state.matchedLocation == '/onboarding';

      // If not logged in and not already on login page, go to login
      if (!isLoggedIn && !isLoggingIn) return '/login';

      // If logged in and on login page, go to dashboard (or onboarding if first time)
      if (isLoggedIn && isLoggingIn) {
        return hasCompletedOnboarding ? '/' : '/onboarding';
      }

      // If logged in and hasn't completed onboarding, show onboarding
      if (isLoggedIn && !hasCompletedOnboarding && !isOnboarding) {
        return '/onboarding';
      }

      // If logged in and completed onboarding but on onboarding page, go to dashboard
      if (isLoggedIn && hasCompletedOnboarding && isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
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
