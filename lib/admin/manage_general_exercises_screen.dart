import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';

import '../screens/admin/add_edit_vocal_day_screen.dart';

class ManageGeneralExercisesScreen extends StatelessWidget {
  const ManageGeneralExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage General Exercises'),
      ),
      body: StreamBuilder<List<VocalExerciseDay>>(
        stream: firebaseService.getGeneralExercisesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 8, itemBuilder: (context, index) => const ListTileShimmer());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No general exercises found.'));
          }
          final exercises = snapshot.data!;
          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                title: Text(exercise.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(exercise.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditVocalDayScreen(isGeneralExercise: true, existingDay: exercise))),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditVocalDayScreen(isGeneralExercise: true))),
        label: const Text('Add Exercise'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}