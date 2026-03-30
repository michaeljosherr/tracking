import 'package:flutter/material.dart';

/// Animated number counter for smooth stat updates
class AnimatedCounter extends StatefulWidget {
  final int count;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String? suffix;
  final String? prefix;

  const AnimatedCounter({
    super.key,
    required this.count,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.suffix,
    this.prefix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  late Animation<int> _animation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;
    _setupAnimation();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _previousCount = oldWidget.count;
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = IntTween(begin: _previousCount, end: widget.count).animate(
      CurvedAnimation(parent: _animationController!, curve: widget.curve),
    );

    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix ?? ''}${_animation.value}${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

/// Animated stat card with counter animation
class AnimatedStatCard extends StatelessWidget {
  final String label;
  final int value;
  final String? suffix;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const AnimatedStatCard({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    required this.icon,
    this.iconColor = const Color(0xFF2563EB),
    this.backgroundColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: 0.5 + (scale * 0.5), child: child),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedCounter(
                count: value,
                suffix: suffix,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated list tile with slideIn effect
class AnimatedListTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int index;
  final Duration delayDuration;

  const AnimatedListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.index = 0,
    this.delayDuration = const Duration(milliseconds: 40),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(-0.5, 0), end: Offset.zero),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) {
        return Transform.translate(
          offset: offset * 100,
          child: Opacity(opacity: 1 - (offset.dx.abs() * 0.5), child: child),
        );
      },
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
