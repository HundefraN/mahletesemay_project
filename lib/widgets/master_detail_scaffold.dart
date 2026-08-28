import 'package:flutter/material.dart';
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
    final isTablet = MediaQuery.of(context).size.width > 720;

    if (!isTablet) {
      return masterPane;
    }

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: masterPane,
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: isDetailPaneVisible
              ? detailPane
              : Center(
            child: Text(AppLocalizations.of(context)?.selectItemFromList ?? 'Select an item from the list'),
          ),
        ),
      ],
    );
  }
}