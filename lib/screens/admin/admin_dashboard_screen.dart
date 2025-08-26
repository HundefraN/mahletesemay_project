import 'package:flutter/material.dart';

import 'package:mahlete_semay_project/screens/admin/manage_vocal_plans_screen.dart';
import 'package:provider/provider.dart';
import '../../admin/add_album_screen.dart';
import '../../admin/add_artists_screen.dart';
import '../../admin/add_song_screen.dart';
import '../../admin/analytics_screen.dart';
import '../../admin/manage_album_screen.dart';
import '../../admin/manage_artists_screen.dart';
import '../../admin/manage_general_exercises_screen.dart';
import '../../admin/manage_songs_screen.dart';
import '../../providers/auth_proveider.dart';


class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  void _showAnalyticsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          // You can wrap AnalyticsScreen in a Navigator for better transitions if needed
          return const AnalyticsScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Portal'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      backgroundColor: theme.colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, "Add New Data"),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildAdminCard(context, icon: Icons.person_add_alt_1, title: 'Add Artist', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddArtistScreen()))),
              _buildAdminCard(context, icon: Icons.album_outlined, title: 'Add Album', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAlbumScreen()))),
              _buildAdminCard(context, icon: Icons.music_note_outlined, title: 'Add Song', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSongScreen()))),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, "Manage Existing Data"),
          _buildManageListTile(context, icon: Icons.edit, title: 'Manage Artists', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageArtistsScreen()))),
          _buildManageListTile(context, icon: Icons.edit_note, title: 'Manage Albums', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAlbumsScreen()))),
          _buildManageListTile(context, icon: Icons.edit_document, title: 'Manage Songs', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSongsScreen()))),
          _buildManageListTile(context, icon: Icons.model_training, title: 'Manage Vocal Plans', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocalPlansScreen()))),
          _buildManageListTile(context, icon: Icons.list_alt_rounded, title: 'Manage General Exercises', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageGeneralExercisesScreen()))),
        ],
      ),
      floatingActionButton: authProvider.isAdmin
          ? FloatingActionButton.extended(
        onPressed: () => _showAnalyticsSheet(context),
        label: const Text('Analytics'),
        icon: const Icon(Icons.analytics_outlined),
      )
          : null,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildManageListTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: theme.colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}