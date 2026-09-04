import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../models/vocal_plan_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/loading_placeholders.dart';
import '../../l10n/app_localizations.dart';
import 'add_edit_vocal_day_screen.dart';

class ManagePlanDaysScreen extends StatelessWidget {
  final String planId;
  final String planTitle;

  const ManagePlanDaysScreen({
    super.key,
    required this.planId,
    required this.planTitle,
  });

  Future<void> _deleteDay(BuildContext context, VocalExerciseDay day) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n?.deletePrompt('Day ${day.dayNumber}') ?? 'Delete Day ${day.dayNumber}?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(l10n?.deleteConfirmPrompt('Day ${day.dayNumber} ("${day.title}")') ?? 'Are you sure you want to delete Day ${day.dayNumber} ("${day.title}")?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n?.cancel ?? 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final firebaseService = FirebaseService();
        await firebaseService.deleteVocalExerciseDay(planId, day.id);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'DELETE_EXERCISE_DAY',
            details: 'Deleted Day ${day.dayNumber} ("${day.title}") from "$planTitle"',
          );
        }

        if (context.mounted) {
          CustomSnackbar.show(context, l10n?.dayDeleted ?? 'Day deleted successfully.');
        }
      } catch (e) {
        if (context.mounted) {
          CustomSnackbar.show(context, '${l10n?.failedToDeleteDay ?? "Failed to delete day"}: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          planTitle,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<VocalExerciseDay>>(
        stream: firebaseService.getVocalPlanDaysStream(planId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 8, itemBuilder: (context, index) => const ListTileShimmer());
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n?.failedToLoadPlanDays ?? 'Failed to load plan days',
              description: snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return AdminEmptyState(
              icon: Icons.fitness_center_rounded,
              title: l10n?.noDaysAddedYet ?? 'No Days Added Yet',
              description: l10n?.startBuildingCurriculum ?? 'Start building this vocal curriculum by adding Day 1.',
              actionLabel: l10n?.addFirstDay ?? 'Add First Day',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditVocalDayScreen(planId: planId)),
              ),
            );
          }
          final days = snapshot.data!;
          return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              physics: const BouncingScrollPhysics(),
              itemCount: days.length,
              itemBuilder: (context, index) {
              final day = days[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: AdminGlassCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditVocalDayScreen(
                        planId: planId,
                        existingDay: day,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      // Day Number Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : AdminUiKit.royalBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${day.dayNumber}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: isDark ? Colors.white : AdminUiKit.royalBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    day.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (day.isRestDay)
                                  AdminStatusBadge(
                                    label: l10n?.restDayBadge ?? 'REST DAY',
                                    color: AdminUiKit.amberOrange,
                                    icon: Icons.hotel_rounded,
                                    fontSize: 9.5,
                                  )
                                else if (day.audioUrl != null && day.audioUrl!.isNotEmpty)
                                  AdminStatusBadge(
                                    label: l10n?.audioAttachedBadge ?? 'AUDIO ATTACHED',
                                    color: AdminUiKit.emeraldGreen,
                                    icon: Icons.graphic_eq_rounded,
                                    fontSize: 9.5,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              day.isRestDay ? (l10n?.scheduledRest ?? 'Scheduled vocal rest & recovery') : day.description,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AdminUiKit.roseRed),
                        tooltip: l10n?.deleteDay ?? 'Delete Day',
                        onPressed: () => _deleteDay(context, day),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditVocalDayScreen(planId: planId)),
        ),
        backgroundColor: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
        foregroundColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          l10n?.addDay ?? 'Add Day',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }
}