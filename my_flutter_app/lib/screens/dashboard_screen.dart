import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';
import 'package:my_flutter_app/widgets/app_bottom_nav_bar.dart';
import 'package:my_flutter_app/widgets/animated_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _filter = 'all';
  bool _isGridView = false; // New: grid/list toggle

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
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          context.read<TrackerProvider>().refreshTrackers();
        },
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmallScreen = constraints.maxWidth < 400;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: isSmallScreen
                            ? [
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildStatCard('Connected', connectedCount, LucideIcons.radioReceiver),
                                      const SizedBox(height: 12),
                                      _buildStatCard('Out of Range', outOfRangeCount, LucideIcons.mapPinOff),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard('Disconnected', disconnectedCount, LucideIcons.wifiOff),
                                ),
                              ]
                            : [
                                _buildStatCard('Connected', connectedCount, LucideIcons.radioReceiver),
                                const SizedBox(width: 12),
                                _buildStatCard('Out of Range', outOfRangeCount, LucideIcons.mapPinOff),
                                const SizedBox(width: 12),
                                _buildStatCard('Disconnected', disconnectedCount, LucideIcons.wifiOff),
                              ],
                      );
                    },
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
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                  tooltip: 'Clear search',
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9), // Slate 100
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
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
                          ),
                          if (_filter != 'all')
                            TextButton(
                              onPressed: () => setState(() => _filter = 'all'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Reset', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                            ),
                        ],
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
                              Icon(LucideIcons.users, size: 20, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Text('Active Trackers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Row(
                            children: [
                              Text('${filteredTrackers.length} devices', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: Icon(
                                  _isGridView ? LucideIcons.list : LucideIcons.layoutGrid,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(() => _isGridView = !_isGridView),
                                tooltip: _isGridView ? 'List View' : 'Grid View',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (filteredTrackers.isEmpty)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, value, child) {
                            return Opacity(opacity: value, child: child);
                          },
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.users,
                                    size: 48,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No trackers found',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      )),
                                  const SizedBox(height: 4),
                                  Text('Try adjusting your search or filters',
                                      style: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (_isGridView)
                        _buildGridView(filteredTrackers)
                      else
                        _buildListView(filteredTrackers),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pairing'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
      bottomNavigationBar: AppBottomNavBar(currentPath: '/'),
    );
    },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
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
              AnimatedCounter(
                count: count,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                duration: const Duration(milliseconds: 800),
              ),
            ],
          ),
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
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Tracker> trackers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trackers.length,
      itemBuilder: (context, index) {
        final tracker = trackers[index];
        
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: TrackerCard(tracker: tracker),
        );
      },
    );
  }

  Widget _buildGridView(List<Tracker> trackers) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: trackers.length,
      itemBuilder: (context, index) {
        final tracker = trackers[index];
        
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (50 * index)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _buildGridCard(tracker),
        );
      },
    );
  }

  Widget _buildGridCard(Tracker tracker) {
    Color statusColor;
    String statusText;
    switch (tracker.status) {
      case TrackerStatus.connected:
        statusColor = Colors.green.shade600;
        statusText = 'Connected';
        break;
      case TrackerStatus.outOfRange:
        statusColor = Colors.orange.shade600;
        statusText = 'Out of Range';
        break;
      case TrackerStatus.disconnected:
        statusColor = Colors.red.shade600;
        statusText = 'Disconnected';
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tracker/${tracker.id}'),
        splashColor: const Color(0xFF2563EB).withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.radio, size: 24, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  tracker.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${tracker.deviceId}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
