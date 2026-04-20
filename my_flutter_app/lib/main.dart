import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/core/bluetooth_status_provider.dart';
import 'package:my_flutter_app/core/notifications_service.dart';
import 'package:my_flutter_app/core/router.dart';
import 'package:my_flutter_app/core/app_themes.dart';
import 'package:my_flutter_app/core/theme_provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/widgets/bluetooth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationsService.instance.initialize(
    onTap: _handleNotificationTap,
  );
  runApp(const MyApp());
}

void _handleNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return;

  if (payload.startsWith('hub:')) {
    final hubBleId = payload.substring(4);
    if (hubBleId.isEmpty) return;
    GoRouter.of(ctx).push('/hub/${Uri.encodeComponent(hubBleId)}');
    return;
  }

  if (payload.startsWith('tracker:')) {
    final trackerId = payload.substring(8);
    if (trackerId.isEmpty) return;
    GoRouter.of(ctx).push('/tracker/$trackerId');
    return;
  }
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
    // If the app was launched from a tapped notification, handle it after the
    // first frame so the router is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload =
          NotificationsService.instance.consumePendingLaunchPayload();
      if (payload != null) {
        _handleNotificationTap(payload);
      }
    });
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
        ChangeNotifierProvider(create: (_) => BluetoothStatusProvider()),
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
                builder: (context, child) {
                  return BluetoothGate(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
      ),
    );
  }
}
