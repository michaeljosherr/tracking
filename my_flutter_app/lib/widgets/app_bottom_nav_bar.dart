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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FBFF), Color(0xFFF1F6FE)],
        ),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFF)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCE8F8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
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
                    indicatorColor: const Color(0xFFE0ECFF),
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                      states,
                    ) {
                      final isSelected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF64748B),
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
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF64748B),
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
                      icon: Icon(LucideIcons.userRound),
                      selectedIcon: Icon(LucideIcons.userRoundCog),
                      label: 'Profile',
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
