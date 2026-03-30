import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/responsive_helper.dart';

class AppPageLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool includeBottomSafeArea;

  const AppPageLayout({
    super.key,
    required this.child,
    this.maxWidth = 1040,
    this.padding,
    this.includeBottomSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = context.responsive.responsiveValue(
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
    final bottomSafeArea = includeBottomSafeArea
        ? math.max(24.0, MediaQuery.of(context).padding.bottom + 16)
        : 0.0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                bottomSafeArea,
              ),
          child: child,
        ),
      ),
    );
  }
}
