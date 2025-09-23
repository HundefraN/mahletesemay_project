import 'package:flutter/widgets.dart';

extension ResponsiveSizer on BuildContext {
  static const double _baseWidth = 390.0;

  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  double w(double size) {
    return (size / _baseWidth) * screenWidth;
  }

  double sp(double size) {
    return (size / _baseWidth) * screenWidth;
  }
}