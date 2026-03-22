import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/auth_provider.dart';

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
          _buildSectionTitle('System'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Column(
              children: [
                _buildListTile(LucideIcons.bell, 'Notifications', 'Manage alert preferences'),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildListTile(LucideIcons.radio, 'Hub Connection', 'Configure ESP32 base station'),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildListTile(Icons.help_outline, 'Help & Support', 'View documentation and FAQs'),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
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

  Widget _buildListTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF64748B)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      trailing: const Icon(LucideIcons.chevronRight, color: Color(0xFFCBD5E1), size: 20),
    );
  }
}
