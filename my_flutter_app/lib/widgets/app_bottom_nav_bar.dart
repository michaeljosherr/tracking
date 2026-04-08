import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? const Color(0xFF111827) : const Color(0xFFF8FBFF),
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F6FE),
          ],
        ),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, bottomInset > 0 ? 10 : 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark ? const Color(0xFF172033) : const Color(0xFFFFFFFF),
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF7FAFF),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Theme(
                data: Theme.of(context).copyWith(
                  navigationBarTheme: NavigationBarThemeData(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    height: 76,
                    indicatorColor: colorScheme.primary.withValues(
                      alpha: isDark ? 0.22 : 0.12,
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                      states,
                    ) {
                      final isSelected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        letterSpacing: 0.1,
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                      states,
                    ) {
                      final isSelected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        color: isSelected
                            ? colorScheme.primary
                            : theme.iconTheme.color,
                        size: 20,
                      );
                    }),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(LucideIcons.radio),
                      selectedIcon: Icon(LucideIcons.radioReceiver),
                      label: 'Trackers',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.bell),
                      selectedIcon: Icon(LucideIcons.bellRing),
                      label: 'Alerts',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.settings),
                      selectedIcon: Icon(LucideIcons.settings2),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
