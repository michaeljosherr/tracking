import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/theme_provider.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/app_top_bar.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor =
        theme.dividerColor.withValues(alpha: 0.4);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Settings',
              subtitle: 'Manage appearance, session, and guided setup.',
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  AppPageLayout(
                    includeBottomSafeArea: false,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return Column(
                            children: [
                              _buildThemeTile(
                                context,
                                LucideIcons.sun,
                                'Light',
                                'Bright colors for daytime use',
                                themeProvider.themeMode == ThemeMode.light,
                                () {
                                  HapticFeedback.lightImpact();
                                  themeProvider.setLightTheme();
                                },
                              ),
                              Divider(height: 1, color: dividerColor),
                              _buildThemeTile(
                                context,
                                LucideIcons.moon,
                                'Dark',
                                'Lower glare for low-light environments',
                                themeProvider.themeMode == ThemeMode.dark,
                                () {
                                  HapticFeedback.lightImpact();
                                  themeProvider.setDarkTheme();
                                },
                              ),
                              Divider(height: 1, color: dividerColor),
                              _buildThemeTile(
                                context,
                                LucideIcons.monitor,
                                'System',
                                'Match your device appearance automatically',
                                themeProvider.themeMode == ThemeMode.system,
                                () {
                                  HapticFeedback.lightImpact();
                                  themeProvider.setSystemTheme();
                                },
                              ),
                              Divider(height: 1, color: dividerColor),
                              _buildActionTile(
                                context: context,
                                icon: Icons.restart_alt_rounded,
                                iconColor: const Color(0xFF0F766E),
                                backgroundColor: const Color(0xFFECFDF5),
                                title: 'Restore default profile',
                                subtitle:
                                    'Reset the local profile state without leaving the app.',
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  context
                                      .read<AuthProvider>()
                                      .resetLocalSession();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Default profile restored'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                              Divider(height: 1, color: dividerColor),
                              _buildActionTile(
                                context: context,
                                icon: LucideIcons.shieldCheck,
                                iconColor: const Color(0xFF0F766E),
                                backgroundColor: const Color(0xFFECFDF5),
                                title: 'System defaults',
                                subtitle:
                                    'The app keeps a local session and no longer requires a login screen.',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Local session mode is already enabled',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                              Divider(height: 1, color: dividerColor),
                              _buildActionTile(
                                context: context,
                                icon: Icons.play_circle_outline_rounded,
                                iconColor: const Color(0xFF2563EB),
                                backgroundColor: const Color(0xFFEFF6FF),
                                title: 'Replay onboarding',
                                subtitle:
                                    'Show the app walkthrough again from the start.',
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  await context
                                      .read<AppPreferencesProvider>()
                                      .resetOnboarding();
                                  if (context.mounted) {
                                    context.go('/onboarding');
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? iconColor.withValues(alpha: 0.16) : backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: theme.iconTheme.color?.withValues(alpha: 0.72),
        size: 18,
      ),
      onTap: onTap,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? colorScheme.primary
              : theme.iconTheme.color?.withValues(alpha: 0.8),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: textTheme.labelLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : theme.colorScheme.outline,
            width: 2,
          ),
        ),
        child: isSelected
            ? Center(
                child: Icon(
                  LucideIcons.check,
                  size: 14,
                  color: colorScheme.primary,
                ),
              )
            : null,
      ),
    );
  }
}
