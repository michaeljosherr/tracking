import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/core/router.dart';
import 'package:my_flutter_app/core/app_themes.dart';
import 'package:my_flutter_app/core/theme_provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = TrackerProvider();
            // Call initialize asynchronously
            provider.initialize().then((_) {
              print('[MyApp] TrackerProvider initialized');
            });
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()),
      ],
      child: Consumer3<AuthProvider, ThemeProvider, AppPreferencesProvider>(
        builder:
            (context, authProvider, themeProvider, preferencesProvider, child) {
              if (authProvider.isLoading) {
                return const MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final router = createRouter(preferencesProvider);

              return MaterialApp.router(
                title: 'ESP Tracker',
                debugShowCheckedModeBanner: false,
                theme: AppThemes.lightTheme,
                darkTheme: AppThemes.darkTheme,
                themeMode: themeProvider.themeMode,
                routerConfig: router,
              );
            },
      ),
    );
  }
}
