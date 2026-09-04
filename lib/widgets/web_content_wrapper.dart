import 'package:flutter/material.dart';
import '../utils/responsive_sizer.dart';

/// Centers and constrains body content on wide screens.
///
/// On phones it's a passthrough. On desktop/tablet it centers content within
/// [maxContentWidth] with responsive horizontal padding.
///
/// Use this widget to wrap screen bodies that should not stretch across the
/// entire browser width.
class WebContentWrapper extends StatelessWidget {
  final Widget child;

  /// Override the max width (defaults to context.maxContentWidth).
  final double? maxWidth;

  /// Whether to apply horizontal padding (defaults to true).
  final bool applyPadding;

  const WebContentWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.applyPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    // On phones, pass through without any wrapping.
    if (context.isPhone) return child;

    final effectiveMaxWidth = maxWidth ?? context.maxContentWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: applyPadding
            ? Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsivePadding,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}

/// A sliver version of [WebContentWrapper] for use inside [CustomScrollView].
class SliverWebContentWrapper extends StatelessWidget {
  final Widget sliver;
  final double? maxWidth;

  const SliverWebContentWrapper({
    super.key,
    required this.sliver,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isPhone) return sliver;

    final effectiveMaxWidth = maxWidth ?? context.maxContentWidth;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.crossAxisExtent;
        final horizontalPadding =
            ((availableWidth - effectiveMaxWidth) / 2).clamp(0.0, double.infinity);

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: sliver,
        );
      },
    );
  }
}
