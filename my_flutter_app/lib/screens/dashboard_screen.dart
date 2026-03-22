import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, trackerProvider, child) {
        final trackers = trackerProvider.trackers;
        final connectedCount = trackerProvider.connectedCount;
        final outOfRangeCount = trackerProvider.outOfRangeCount;
        final disconnectedCount = trackerProvider.disconnectedCount;
        final activeAlerts = trackerProvider.activeAlerts;

        final filteredTrackers = trackers.where((tracker) {
          final matchesSearch = tracker.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                tracker.deviceId.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesFilter = _filter == 'all' || 
                               (_filter == 'connected' && tracker.status == TrackerStatus.connected) ||
                               (_filter == 'out-of-range' && tracker.status == TrackerStatus.outOfRange) ||
                               (_filter == 'disconnected' && tracker.status == TrackerStatus.disconnected);
          return matchesSearch && matchesFilter;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2563EB), // Blue 600
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              title: const Row(
                children: [
                  Icon(LucideIcons.radio, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('ESP32 Tracker', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatCard('Connected', connectedCount, LucideIcons.radioReceiver),
                      const SizedBox(width: 12),
                      _buildStatCard('Out of Range', outOfRangeCount, LucideIcons.mapPinOff),
                      const SizedBox(width: 12),
                      _buildStatCard('Disconnected', disconnectedCount, LucideIcons.wifiOff),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell, color: Colors.white),
                    onPressed: () => context.push('/alerts'),
                  ),
                  if (activeAlerts.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444), // Red 500
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2563EB), width: 2),
                        ),
                        child: Text(
                          '${activeAlerts.length}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.settings, color: Colors.white),
                onPressed: () => context.push('/settings'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (activeAlerts.isNotEmpty)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${activeAlerts.length} active ${activeAlerts.length == 1 ? "alert" : "alerts"} require attention',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/alerts'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
            
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search by name or device ID...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)), // Slate 400
                          prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9), // Slate 100
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All (${trackers.length})', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Connected ($connectedCount)', 'connected'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Out of Range ($outOfRangeCount)', 'out-of-range'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Disconnected ($disconnectedCount)', 'disconnected'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.users, size: 20, color: Color(0xFF64748B)), // Slate 500
                              SizedBox(width: 8),
                              Text('Active Trackers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF0F172A))), // Slate 900
                            ],
                          ),
                          Text('${filteredTrackers.length} devices', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (filteredTrackers.isEmpty)
                         Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.users, size: 48, color: Color(0xFFCBD5E1)), // Slate 300
                                const SizedBox(height: 16),
                                const Text('No trackers found', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text('Try adjusting your search or filters', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      if (filteredTrackers.isNotEmpty)
                        ...filteredTrackers.map((tracker) => TrackerCard(tracker: tracker)).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pairing'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
    );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text('$count', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
