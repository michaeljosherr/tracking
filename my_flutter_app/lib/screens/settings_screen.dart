import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/core/theme_provider.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
        backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F5F9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            AppPageLayout(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'Appearance'),
                  _buildThemeCard(context),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Guidance'),
                  _buildActionCard(
                    context: context,
                    icon: Icons.play_circle_outline_rounded,
                    iconColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFEFF6FF),
                    title: 'Replay onboarding',
                    subtitle: 'Show the app walkthrough again from the start.',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await context
                          .read<AppPreferencesProvider>()
                          .resetOnboarding();
                      if (context.mounted) context.go('/onboarding');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionCard(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    return Card(
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
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
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionCard({
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

    return Card(
      child: ListTile(
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
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: theme.textTheme.bodySmall?.color,
          letterSpacing: 0.6,
        ),
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
