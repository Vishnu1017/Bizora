import 'package:flutter/material.dart';

class Responsive {
  /// Screen width
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Screen height
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Breakpoints
  static bool isSmallPhone(BuildContext context) => width(context) < 360;

  static bool isMobile(BuildContext context) =>
      width(context) >= 360 && width(context) < 600;

  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1100;

  static bool isDesktop(BuildContext context) => width(context) >= 1100;

  /// Responsive Padding
  static double horizontalPadding(BuildContext context) {
    final w = width(context);

    if (w < 360) return 16;
    if (w < 600) return 20;
    if (w < 1100) return w * 0.22;
    return w * 0.35;
  }

  /// Responsive Font
  static double titleFont(BuildContext context) {
    final w = width(context);

    if (w < 360) return 20;
    if (w < 600) return 24;
    if (w < 1100) return 28;
    return 32;
  }

  static double subtitleFont(BuildContext context) {
    final w = width(context);

    if (w < 360) return 12;
    if (w < 600) return 14;
    if (w < 1100) return 16;
    return 18;
  }

  /// Responsive Icon Size
  static double iconSize(BuildContext context) {
    final w = width(context);

    if (w < 360) return 40;
    if (w < 600) return 55;
    if (w < 1100) return 65;
    return 75;
  }

  /// Responsive Button Height
  static double buttonHeight(BuildContext context) {
    final w = width(context);

    if (w < 360) return 48;
    if (w < 600) return 52;
    return 56;
  }

  /// Responsive Card Padding
  static EdgeInsets cardPadding(BuildContext context) {
    if (isSmallPhone(context)) {
      return const EdgeInsets.all(16);
    }

    if (isMobile(context)) {
      return const EdgeInsets.all(20);
    }

    return const EdgeInsets.all(26);
  }

  /// Responsive Max Width
  static double maxContentWidth(BuildContext context) {
    if (isTablet(context)) return 600;
    if (isDesktop(context)) return 800;
    return 500;
  }
}
