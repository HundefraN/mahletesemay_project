import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'add_edit_vocal_day_screen.dart';

class ManagePlanDaysScreen extends StatelessWidget {
  final String planId;
  final String planTitle;

  const ManagePlanDaysScreen({super.key, required this.planId, required this.planTitle});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    return Scaffold(
      appBar: AppBar(
        title: Text(planTitle),
      ),
      body: StreamBuilder<List<VocalExerciseDay>>(
        stream: firebaseService.getVocalPlanDaysStream(planId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 8, itemBuilder: (context, index) => const ListTileShimmer());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No days found for this plan.'));
          }
          final days = snapshot.data!;
          return ListView.builder(
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return ListTile(
                leading: CircleAvatar(child: Text(day.dayNumber.toString())),
                title: Text(day.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(day.isRestDay ? 'Rest Day' : day.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditVocalDayScreen(planId: planId, existingDay: day))),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditVocalDayScreen(planId: planId))),
        label: const Text('Add Day'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}