import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TrackerProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }

          final router = createRouter(authProvider);

          return MaterialApp.router(
            title: 'ESP Tracker',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2563EB),
                primary: const Color(0xFF2563EB),
                surface: Colors.white,
                background: const Color(0xFFF8FAFC), // Slate 50
              ),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).copyWith(
                titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
                bodyLarge: GoogleFonts.inter(color: const Color(0xFF1E293B)),
                bodyMedium: GoogleFonts.inter(color: const Color(0xFF475569)),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)), // Slate 200
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF2563EB), // Blue 600
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
