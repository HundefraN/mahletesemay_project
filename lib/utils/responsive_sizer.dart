import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

extension ResponsiveSizer on BuildContext {
  static const double _baseWidth = 390.0;

  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  // ─── Breakpoints ───────────────────────────────────────────────────────────

  bool get isPhone => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  /// True when running in a web browser (regardless of window width).
  bool get isWebPlatform => kIsWeb;

  // ─── Content Constraints ───────────────────────────────────────────────────

  /// Maximum content width for centered layouts on wide screens.
  double get maxContentWidth {
    if (isDesktop) return 1200;
    if (isTablet) return 900;
    return screenWidth;
  }

  /// Comfortable reading width for text-heavy screens (lyrics, articles).
  double get readableWidth {
    if (isDesktop) return 720;
    if (isTablet) return 640;
    return screenWidth;
  }

  /// Horizontal padding that adapts to the screen size.
  double get responsivePadding {
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 16;
  }

  // ─── Grid Helpers ──────────────────────────────────────────────────────────

  /// Cross-axis count for artist/album grids.
  int get gridCrossAxisCount {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 2;
  }

  /// Cross-axis count for card-style recommendation grids.
  int get recommendationGridCount {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 2;
  }

  /// Number of items visible in a horizontal carousel at once.
  int get carouselVisibleCount {
    if (isDesktop) return 6;
    if (isTablet) return 4;
    return 3;
  }

  // ─── Scale Factor ──────────────────────────────────────────────────────────

  double get _scaleFactor {
    final width = screenWidth;

    if (kIsWeb && width >= 1024) {
      // Desktop web: keep elements at roughly phone-logical size so they
      // don't balloon. Content centering handles the width instead.
      return 1.0;
    }

    if (width >= 600) {
      return (width / _baseWidth).clamp(1.0, 1.25);
    }
    // Mobile phones: prevent oversized elements on wider phone displays
    final ratio = width / _baseWidth;
    if (ratio > 1.0) {
      return 1.0 + (ratio - 1.0) * 0.15;
    }
    return ratio.clamp(0.80, 1.0);
  }

  double w(double size) {
    return (size * 0.84) * _scaleFactor;
  }

  double sp(double size) {
    return (size * 0.84) * _scaleFactor;
  }
}