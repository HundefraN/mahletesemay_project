import 'dart:ui';

import 'package:flutter/material.dart';

/// Custom scroll behavior for web that enables drag scrolling (like mobile)
/// and shows styled scrollbars.
class WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
