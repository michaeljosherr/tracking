import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/widgets/all_trackers_radar.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:provider/provider.dart';

class AllTrackersRadarScreen extends StatelessWidget {
  const AllTrackersRadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('All trackers radar'),
      ),
      body: Consumer<TrackerProvider>(
        builder: (context, provider, _) {
          final trackers = provider.trackers;
          if (trackers.isEmpty) {
            return AppPageLayout(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.scanSearch,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No registered trackers',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a tracker from the dashboard to see it on the radar.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              AppPageLayout(
                child: AllTrackersRadarPanel(trackers: trackers),
              ),
            ],
          );
        },
      ),
    );
  }
}
