import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppBottomNavBar extends StatefulWidget {
  final String currentPath;

  const AppBottomNavBar({super.key, required this.currentPath});

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _getIndexFromPath(widget.currentPath);
  }

  @override
  void didUpdateWidget(AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _selectedIndex = _getIndexFromPath(widget.currentPath);
    }
  }

  int _getIndexFromPath(String path) {
    if (path.startsWith('/tracker')) return 0;
    if (path.startsWith('/alerts')) return 1;
    if (path.startsWith('/settings')) return 2;
    return 0; // Default to dashboard
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/alerts');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }

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
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onNavTap,
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
