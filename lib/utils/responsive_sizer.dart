import 'package:flutter/widgets.dart';

extension ResponsiveSizer on BuildContext {
  static const double _baseWidth = 390.0;

  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  double get _scaleFactor {
    final width = screenWidth;
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