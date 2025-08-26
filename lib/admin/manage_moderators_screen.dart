import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/moderator_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';

import '../screens/auth/login_screen.dart';
import 'add_moderators_screen.dart';

class ManageModeratorsScreen extends StatelessWidget {
  const ManageModeratorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Moderators'),
      ),
      body: StreamBuilder<List<Moderator>>(
        stream: firebaseService.getModeratorsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 5, itemBuilder: (ctx, i) => const ListTileShimmer());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No moderators found in Firestore.'));
          }
          final moderators = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: moderators.length,
            itemBuilder: (context, index) {
              final mod = moderators[index];
              if (mod.role == 'admin') return const SizedBox.shrink();

              final bool isActive = mod.status == 'active';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SwitchListTile(
                  title: Text(mod.fullName.isNotEmpty ? mod.fullName : mod.email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(mod.email),
                  value: isActive,
                  onChanged: (value) async {
                    final newStatus = value ? 'active' : 'blocked';
                    try {
                      await firebaseService.updateModeratorStatus(mod.uid, newStatus);
                      CustomSnackbar.show(context, '${mod.email} is now ${newStatus}.');
                    } catch (e) {
                      CustomSnackbar.show(context, 'Failed to update status.', isError: true);
                    }
                  },
                  secondary: Icon(isActive ? Icons.check_circle : Icons.block, color: isActive ? Colors.green : Colors.red),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddModeratorScreen())),
        label: const Text('New Moderator'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}