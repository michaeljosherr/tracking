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
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset > 0 ? 8 : 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: NavigationBar(
              height: 72,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: const Color(0xFFF8FAFC),
              indicatorColor: const Color(0xFFDBEAFE),
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
    );
  }
}
