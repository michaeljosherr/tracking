import 'package:flutter/material.dart';

/// Skeleton loader widget with shimmer animation
/// Used to show placeholder content while data is loading
class SkeletonLoader extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsets padding;
  final MainAxisAlignment mainAxisAlignment;

  const SkeletonLoader({
    super.key,
    this.itemCount = 3,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return ShimmerWidget(
          animationController: _animationController,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

/// Shimmer effect overlay for skeleton items
class ShimmerWidget extends StatelessWidget {
  final AnimationController animationController;
  final Widget child;

  const ShimmerWidget({
    super.key,
    required this.animationController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.5 - (animationController.value * 3), 0),
              end: Alignment(1.0, 0),
              colors: [
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                isDark ? const Color(0xFF475569) : const Color(0xFFF1F5F9),
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}

/// Skeleton card for tracker list loading
class SkeletonTrackerCard extends StatelessWidget {
  final EdgeInsets padding;

  const SkeletonTrackerCard({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 150, height: 16),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: 100, height: 14),
                  ],
                ),
                _SkeletonBox(width: 60, height: 24),
              ],
            ),
            const SizedBox(height: 16),
            // Signal and battery row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 80, height: 40),
                _SkeletonBox(width: 80, height: 40),
                _SkeletonBox(width: 60, height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton card for dashboard stats loading
class SkeletonStatsCard extends StatelessWidget {
  final EdgeInsets padding;

  const SkeletonStatsCard({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 100, height: 14),
                _SkeletonBox(width: 40, height: 40),
              ],
            ),
            const SizedBox(height: 12),
            _SkeletonBox(width: 120, height: 24),
            const SizedBox(height: 8),
            _SkeletonBox(width: 160, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Generic skeleton box
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBox({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
