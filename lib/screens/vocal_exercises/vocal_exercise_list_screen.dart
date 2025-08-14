import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';
import 'package:mahlete_semay_project/utils/vocal_plans_data.dart';
import 'gender_selection_screen.dart';
import 'vocal_plan_screen.dart';

class VocalExerciseListScreen extends StatelessWidget {
  const VocalExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<VocalProgressProvider>(context);
    final theme = Theme.of(context);

    if (progressProvider.gender == null) {
      return const GenderSelectionScreen();
    }

    final dailyPlanToShow = progressProvider.gender == 'Male' ? maleDailyPlan : femaleDailyPlan;
    final plans = [dailyPlanToShow, weeklyPlan, monthlyPlan, quarterlyPlan];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocal Training Plans'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          final progress = progressProvider.progress[plan.title] ?? 0;
          final totalSteps = plan.routines.fold<int>(0, (sum, routine) => sum + routine.steps.length);
          final isComplete = totalSteps > 0 && progress >= totalSteps;
          final progressPercent = totalSteps > 0 ? progress / totalSteps : 0.0;

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: plan.routines.isNotEmpty ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VocalPlanScreen(initialPlan: plan)),
                );
              } : null,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '${plan.duration.name.toUpperCase()} ROUTINE',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (totalSteps > 0) ...[
                      LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$progress / $totalSteps Steps Complete'),
                          if (isComplete)
                            const Icon(Icons.check_circle, color: Colors.green)
                        ],
                      ),
                    ] else
                      Text('Coming Soon!', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}