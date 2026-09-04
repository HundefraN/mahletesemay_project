import 'package:flutter/material.dart';
import '../utils/responsive_sizer.dart';
import '../../l10n/app_localizations.dart';

class MasterDetailScaffold extends StatelessWidget {
  final Widget masterPane;
  final Widget detailPane;
  final bool isDetailPaneVisible;

  const MasterDetailScaffold({
    super.key,
    required this.masterPane,
    required this.detailPane,
    required this.isDetailPaneVisible,
  });

  @override
  Widget build(BuildContext context) {
    final width = context.screenWidth;
    final isWide = width > 720;

    if (!isWide) {
      return masterPane;
    }

    // Proportional master width: 35% of screen, clamped between 320–420px.
    final masterWidth = (width * 0.35).clamp(320.0, 420.0);

    return Row(
      children: [
        SizedBox(
          width: masterWidth,
          child: masterPane,
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
        Expanded(
          child: isDetailPaneVisible
              ? detailPane
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.selectItemFromList ??
                            'Select an item from the list',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}