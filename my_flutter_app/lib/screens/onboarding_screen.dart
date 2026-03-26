import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/app_preferences_provider.dart';

/// Onboarding screen with feature introduction slides
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingSlide> slides = [
    OnboardingSlide(
      icon: LucideIcons.radio,
      title: 'Track Your Devices',
      description: 'Monitor all your ESP32 trackers in real-time with live status updates',
      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
    ),
    OnboardingSlide(
      icon: LucideIcons.bell,
      title: 'Stay Informed',
      description: 'Get instant alerts when devices go offline or move out of range',
      colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)],
    ),
    OnboardingSlide(
      icon: LucideIcons.signalHigh,
      title: 'Signal Strength',
      description: 'Monitor signal quality and battery levels for all your trackers',
      colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
    ),
    OnboardingSlide(
      icon: LucideIcons.settings,
      title: 'Customize Your Setup',
      description: 'Configure alerts, themes, and tracking preferences to your needs',
      colors: [Color(0xFF1F2937), Color(0xFF4B5563), Color(0xFF6B7280)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _skipOnboarding();
    }
  }

  void _skipOnboarding() async {
    HapticFeedback.lightImpact();
    // Mark onboarding as completed
    await context.read<AppPreferencesProvider>().markOnboardingComplete();
    // Navigate to dashboard
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Page view with slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              HapticFeedback.lightImpact();
            },
            itemCount: slides.length,
            itemBuilder: (context, index) {
              return OnboardingSlideWidget(slide: slides[index]);
            },
          ),
          // Bottom navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (index) => Container(
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _skipOnboarding,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _nextPage,
                          icon: Icon(
                            _currentPage == slides.length - 1
                                ? LucideIcons.check
                                : LucideIcons.arrowRight,
                            size: 18,
                          ),
                          label: Text(
                            _currentPage == slides.length - 1 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for onboarding slides
class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> colors; // Gradient colors

  OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
  });
}

/// Individual slide widget
class OnboardingSlideWidget extends StatefulWidget {
  final OnboardingSlide slide;

  const OnboardingSlideWidget({super.key, required this.slide});

  @override
  State<OnboardingSlideWidget> createState() => _OnboardingSlideWidgetState();
}

class _OnboardingSlideWidgetState extends State<OnboardingSlideWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hintsController;
  late Animation<double> _hintsAnimation;

  @override
  void initState() {
    _hintsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _hintsAnimation = CurvedAnimation(
      parent: _hintsController,
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _hintsController.forward();
    });
    super.initState();
  }

  @override
  void dispose() {
    _hintsController.dispose();
    super.dispose();
  }

  List<String> _getHints(int slideIndex) {
    final hints = {
      0: [
        'Add trackers by clicking "Add Tracker"',
        'View real-time status of all devices',
        'Track signal strength and battery',
      ],
      1: [
        'Customize alert preferences in Settings',
        'Receive notifications for device changes',
        'Mark alerts as read to dismiss them',
      ],
      2: [
        'Green bars indicate strong signals',
        'Low battery warnings keep you updated',
        'Signal drops when devices move away',
      ],
      3: [
        'Dark mode for comfortable use',
        'Choose notification frequency',
        'Set custom device names',
      ],
    };
    return hints[slideIndex] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final hints = _getHints(
      [0, 1, 2, 3].indexOf(widget.slide.title.hashCode % 4),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.slide.colors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with circular background
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.slide.icon,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              // Title
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  widget.slide.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              // Description
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  widget.slide.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              // Hints Section
              FadeTransition(
                opacity: _hintsAnimation,
                child: SlideTransition(
                  position: _hintsAnimation.drive(
                    Tween<Offset>(
                      begin: const Offset(0, 20),
                      end: Offset.zero,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.lightbulb,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Quick Tips',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...hints.map((hint) {
                          final index = hints.indexOf(hint);
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < hints.length - 1 ? 8 : 0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(
                                    right: 8,
                                    top: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    hint,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
