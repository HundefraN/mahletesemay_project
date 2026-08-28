import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/duplicate_detection_service.dart';
import '../../l10n/app_localizations.dart';
import 'admin_ui_kit.dart';

/// A premium-styled dialog that warns the admin about potential duplicate entries.
///
/// Shows severity-coded warnings with details of matched items.
/// Returns `true` if the admin chooses to save anyway, `false` otherwise.
class DuplicateWarningDialog extends StatelessWidget {
  final DuplicateCheckResult result;

  const DuplicateWarningDialog({super.key, required this.result});

  /// Shows the dialog and returns `true` if admin wants to proceed anyway.
  static Future<bool> show(BuildContext context, DuplicateCheckResult result) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DuplicateWarningDialog(result: result),
    );
    return shouldProceed ?? false;
  }

  Color _severityColor() {
    switch (result.severity) {
      case DuplicateSeverity.exact:
        return AdminUiKit.roseRed;
      case DuplicateSeverity.likely:
        return AdminUiKit.amberOrange;
      case DuplicateSeverity.possible:
        return AdminUiKit.royalBlue;
    }
  }

  IconData _severityIcon() {
    switch (result.severity) {
      case DuplicateSeverity.exact:
        return Icons.error_rounded;
      case DuplicateSeverity.likely:
        return Icons.warning_rounded;
      case DuplicateSeverity.possible:
        return Icons.info_rounded;
    }
  }

  String _severityLabel() {
    switch (result.severity) {
      case DuplicateSeverity.exact:
        return 'Exact Duplicate Found';
      case DuplicateSeverity.likely:
        return 'Likely Duplicate Found';
      case DuplicateSeverity.possible:
        return 'Possible Duplicate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _severityColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13233D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.15),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Icon(_severityIcon(), color: color, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _severityLabel(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Message
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                result.message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Matched items list
            if (result.matchedItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: result.matchedItems.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    itemBuilder: (context, index) {
                      final item = result.matchedItems[index];
                      return _buildMatchedItemTile(item, isDark, color);
                    },
                  ),
                ),
              ),
            ],

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: AdminPrimaryButton(
                      label: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                      icon: Icons.close_rounded,
                      isSecondary: true,
                      height: 42,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminPrimaryButton(
                      label: AppLocalizations.of(context)?.publishAnyway ?? 'Save Anyway',
                      icon: Icons.check_rounded,
                      height: 42,
                      color: color,
                      onPressed: () {
                        AdminUiKit.hapticMedium();
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedItemTile(
      Map<String, String> item, bool isDark, Color color) {
    // Build subtitle from available fields
    final parts = <String>[];
    if (item.containsKey('artist') && item['artist']!.isNotEmpty) {
      parts.add('Artist: ${item['artist']}');
    }
    if (item.containsKey('album') && item['album']!.isNotEmpty) {
      parts.add('Album: ${item['album']}');
    }
    if (item.containsKey('region') && item['region']!.isNotEmpty) {
      parts.add('Region: ${item['region']}');
    }
    if (item.containsKey('volume') && item['volume'] != '-') {
      parts.add('Vol. ${item['volume']}');
    }

    final displayTitle =
        item['title'] ?? item['name'] ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (parts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      parts.join(' • '),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
