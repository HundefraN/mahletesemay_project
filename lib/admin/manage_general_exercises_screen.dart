import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/vocal_plan_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/loading_placeholders.dart';
import '../screens/admin/add_edit_vocal_day_screen.dart';
import 'widgets/admin_ui_kit.dart';

class ManageGeneralExercisesScreen extends StatelessWidget {
  const ManageGeneralExercisesScreen({super.key});

  Future<void> _deleteExercise(BuildContext context, VocalExerciseDay exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Exercise?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${exercise.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final firebaseService = FirebaseService();
        await firebaseService.deleteGeneralExercises([exercise.id]);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'DELETE_EXERCISE',
            details: 'Deleted general exercise: "${exercise.title}"',
          );
        }

        if (context.mounted) {
          CustomSnackbar.show(context, 'Exercise deleted successfully.');
        }
      } catch (e) {
        if (context.mounted) {
          CustomSnackbar.show(context, 'Failed to delete exercise: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'General Vocal Exercises',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<VocalExerciseDay>>(
        stream: firebaseService.getGeneralExercisesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 8, itemBuilder: (context, index) => const ListTileShimmer());
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load exercises',
              description: snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return AdminEmptyState(
              icon: Icons.graphic_eq_rounded,
              title: 'No General Exercises',
              description: 'Create standalone vocal workout drills for users to practice anytime.',
              actionLabel: 'Add General Drill',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditVocalDayScreen(isGeneralExercise: true)),
              ),
            );
          }
          final exercises = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            physics: const BouncingScrollPhysics(),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: AdminGlassCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditVocalDayScreen(isGeneralExercise: true, existingDay: exercise),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AdminUiKit.violetPurple.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: AdminUiKit.violetPurple, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              exercise.description,
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
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AdminUiKit.roseRed),
                        tooltip: 'Delete Drill',
                        onPressed: () => _deleteExercise(context, exercise),
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
          MaterialPageRoute(builder: (_) => const AddEditVocalDayScreen(isGeneralExercise: true)),
        ),
        backgroundColor: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
        foregroundColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Add Drill',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }
}