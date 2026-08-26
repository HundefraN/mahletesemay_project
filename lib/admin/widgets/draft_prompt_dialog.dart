import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_ui_kit.dart';

/// Result of the draft prompt dialog.
enum DraftPromptResult {
  /// User chose to save the current form data as a draft.
  saveDraft,

  /// User chose to discard unsaved changes and leave.
  discard,

  /// User chose to cancel and stay on the page.
  cancel,
}

/// A premium-styled dialog shown when the admin presses back with unsaved changes.
///
/// Offers three options: Save Draft, Discard, or Cancel (stay).
class DraftPromptDialog extends StatelessWidget {
  final String entityType; // e.g. "Song", "Album", "Artist"

  const DraftPromptDialog({super.key, required this.entityType});

  /// Shows the dialog and returns the user's choice.
  static Future<DraftPromptResult> show(BuildContext context, String entityType) async {
    final result = await showDialog<DraftPromptResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DraftPromptDialog(entityType: entityType),
    );
    return result ?? DraftPromptResult.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13233D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black12,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AdminUiKit.amberOrange.withOpacity(0.12),
                    AdminUiKit.amberOrange.withOpacity(0.04),
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
                      color: AdminUiKit.amberOrange.withOpacity(0.15),
                      border: Border.all(
                        color: AdminUiKit.amberOrange.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AdminUiKit.amberOrange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unsaved Changes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Message
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Text(
                'You have unsaved changes in this $entityType form. Would you like to save them as a draft so you can continue later?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Save Draft — primary action
                  AdminPrimaryButton(
                    label: 'Save Draft',
                    icon: Icons.save_rounded,
                    height: 42,
                    color: AdminUiKit.emeraldGreen,
                    onPressed: () {
                      AdminUiKit.hapticSuccess();
                      Navigator.pop(context, DraftPromptResult.saveDraft);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Discard — destructive
                  AdminPrimaryButton(
                    label: 'Discard Changes',
                    icon: Icons.delete_outline_rounded,
                    height: 42,
                    color: AdminUiKit.roseRed,
                    onPressed: () {
                      AdminUiKit.hapticMedium();
                      Navigator.pop(context, DraftPromptResult.discard);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Cancel — stay on page
                  AdminPrimaryButton(
                    label: 'Keep Editing',
                    icon: Icons.edit_rounded,
                    height: 42,
                    isSecondary: true,
                    onPressed: () {
                      Navigator.pop(context, DraftPromptResult.cancel);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
