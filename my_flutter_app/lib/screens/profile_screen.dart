import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/app_top_bar.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Profile',
              subtitle: 'View account details and manage your local session.',
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
                        _buildProfileCard(user),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Session'),
                        _buildActionCard(
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
                        _buildSectionTitle('Guided Setup'),
                        _buildActionCard(
                          icon: Icons.play_circle_outline_rounded,
                          iconColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFFEFF6FF),
                          title: 'Replay onboarding',
                          subtitle:
                              'Open the setup walkthrough again from the beginning.',
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

  Widget _buildProfileCard(User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF2563EB),
            child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Local User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.email ?? 'local@tracker.app',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaPill(
                      label: (user?.role ?? 'local').toUpperCase(),
                      color: const Color(0xFF1D4ED8),
                      backgroundColor: const Color(0xFFEFF6FF),
                    ),
                    _buildMetaPill(
                      label: 'LOCAL SESSION',
                      color: const Color(0xFF0F766E),
                      backgroundColor: const Color(0xFFECFDF5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill({
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
          size: 22,
        ),
        onTap: onTap,
      ),
    );
  }
}
