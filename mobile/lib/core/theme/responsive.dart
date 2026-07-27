import 'package:flutter/material.dart';

/// Layout breakpoints. Anything at or above [tablet] gets the large-screen
/// treatment (side navigation, wider content, multi-column grids).
class Breakpoints {
  Breakpoints._();
  static const double tablet = 800;
  static const double desktop = 1200;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isTablet => screenWidth >= Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Number of columns for card grids at the current width.
  int get gridColumns => screenWidth >= Breakpoints.desktop
      ? 4
      : screenWidth >= Breakpoints.tablet
          ? 3
          : 2;
}

/// Centres its child and caps its width so text lines and cards never stretch
/// uncomfortably wide on tablets, foldables or landscape phones.
///
/// Use this around *scrollable page content* — never around app chrome such as
/// the navigation bar or app bar, which should always span the full width.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
