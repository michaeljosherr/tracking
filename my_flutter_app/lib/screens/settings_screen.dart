import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/core/theme_provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/app_top_bar.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _renameHub(
    BuildContext context,
    TrackerProvider trackerProvider,
    String hubBleId,
  ) async {
    final currentName = trackerProvider.getHubDisplayName(
      hubBleId,
      fallbackName: 'Hub',
    );
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename hub'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Hub name',
            hintText: 'Enter a hub name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newName == null || !context.mounted) return;

    final cleaned = newName.trim();
    if (cleaned.isEmpty || cleaned == currentName) return;

    await trackerProvider.renameHub(hubBleId, cleaned);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hub renamed to $cleaned'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeHub(
    BuildContext context,
    TrackerProvider trackerProvider,
    String hubBleId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove hub?'),
        content: const Text(
          'Deletes this hub and every tracker registered to it on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await trackerProvider.removeHubConnection(hubBleId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hub removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Settings',
              subtitle: 'Manage appearance, session, hub connections, and guided setup.',
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  AppPageLayout(
                    includeBottomSafeArea: false,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(context, 'Appearance'),
                        _buildThemeCard(context),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, 'Session'),
                        _buildActionCard(
                          context: context,
                          icon: Icons.restart_alt_rounded,
                          iconColor: const Color(0xFF0F766E),
                          backgroundColor: const Color(0xFFECFDF5),
                          title: 'Restore default profile',
                          subtitle:
                              'Reset the local profile state without leaving the app.',
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            context.read<AuthProvider>().resetLocalSession();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Default profile restored'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
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
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, 'Hub connections'),
                        Consumer<TrackerProvider>(
                          builder: (context, trackerProvider, _) {
                            final hubs = trackerProvider.savedHubBleIds;
                            if (hubs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'No hubs saved yet. Add a hub from the dashboard.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (final id in hubs)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildActionCard(
                                      context: context,
                                      icon: LucideIcons.radioTower,
                                      iconColor: const Color(0xFF0D9488),
                                      backgroundColor: const Color(0xFFCCFBF1),
                                      title: trackerProvider.getHubDisplayName(
                                        id,
                                        fallbackName: 'Hub',
                                      ),
                                      subtitle: id,
                                      onTap: () {
                                        context.push('/hub/${Uri.encodeComponent(id)}');
                                      },
                                      trailing: PopupMenuButton<String>(
                                        tooltip: 'Hub actions',
                                        onSelected: (value) async {
                                          if (value == 'rename') {
                                            await _renameHub(
                                              context,
                                              trackerProvider,
                                              id,
                                            );
                                          } else if (value == 'remove') {
                                            await _removeHub(
                                              context,
                                              trackerProvider,
                                              id,
                                            );
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem<String>(
                                            value: 'rename',
                                            child: Text('Rename'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'remove',
                                            child: Text('Remove'),
                                          ),
                                        ],
                                        child: Icon(
                                          LucideIcons.ellipsisVertical,
                                          color: Theme.of(context)
                                              .iconTheme
                                              .color
                                              ?.withValues(alpha: 0.72),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, 'Guidance'),
                        _buildActionCard(
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
                            if (context.mounted) context.go('/onboarding');
                          },
                        ),
                      ],
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
    Widget? trailing,
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
        trailing: trailing ??
            Icon(
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
