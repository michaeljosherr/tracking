import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/theme_provider.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/widgets/app_bottom_nav_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Breadcrumb Navigation
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                child: const Row(
                  children: [
                    Icon(LucideIcons.radio, size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text('Dashboard', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              const Text('Settings', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Account'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2563EB),
                child: Icon(LucideIcons.user, color: Colors.white),
              ),
              title: Text(user?.name ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(user?.role.toUpperCase() ?? 'GUEST'),
              trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Appearance'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Column(
                  children: [
                    _buildThemeTile(
                      context,
                      LucideIcons.sun,
                      'Light',
                      'Bright colors for daytime',
                      themeProvider.themeMode == ThemeMode.light,
                      () {
                        HapticFeedback.lightImpact();
                        themeProvider.setLightTheme();
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildThemeTile(
                      context,
                      LucideIcons.moon,
                      'Dark',
                      'Darker theme for nighttime',
                      themeProvider.themeMode == ThemeMode.dark,
                      () {
                        HapticFeedback.lightImpact();
                        themeProvider.setDarkTheme();
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildThemeTile(
                      context,
                      LucideIcons.monitor,
                      'System',
                      'Follow device settings',
                      themeProvider.themeMode == ThemeMode.system,
                      () {
                        HapticFeedback.lightImpact();
                        themeProvider.setSystemTheme();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          // Help & Support Section
          _buildSectionTitle('Help & Support'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'View Features',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              subtitle: const Text(
                'Explore app features and get started',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFFCBD5E1), size: 20),
              onTap: () async {
                HapticFeedback.lightImpact();
                // Reset onboarding and navigate to it
                await context.read<AppPreferencesProvider>().resetOnboarding();
                if (context.mounted) context.go('/onboarding');
              },
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                context.read<AuthProvider>().logout();
              },
              icon: const Icon(LucideIcons.logOut, size: 20),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade600,
                elevation: 0,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(currentPath: '/settings'),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF94A3B8), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF2563EB) : Color(isDark ? 0xFFA1AEC6 : 0xFF64748B),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
        ),
      ),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Color(isDark ? 0xFF475569 : 0xFFCBD5E1),
            width: 2,
          ),
        ),
        child: isSelected
            ? const Center(
                child: Icon(
                  LucideIcons.check,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
              )
            : null,
      ),
    );
  }
}
