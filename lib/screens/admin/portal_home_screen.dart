import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/suggestion_model.dart';
import 'package:mahlete_semay_project/screens/admin/manage_vocal_plans_screen.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:provider/provider.dart';

import '../../admin/activity_screen.dart';
import '../../admin/add_album_screen.dart';
import '../../admin/add_artists_screen.dart';
import '../../admin/add_song_screen.dart';
import '../../admin/analytics_screen.dart';
import '../../admin/manage_album_screen.dart';
import '../../admin/manage_artists_screen.dart';
import '../../admin/manage_general_exercises_screen.dart';
import '../../admin/manage_moderators_screen.dart';
import '../../admin/manage_songs_screen.dart';
import '../../admin/review_suggestion_screen.dart';
import '../../models/activity_log_model.dart';
import '../../providers/auth_proveider.dart';

class PortalHomeScreen extends StatelessWidget {
  const PortalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final moderator = authProvider.currentModerator;
    final theme = Theme.of(context);
    final firebaseService = FirebaseService();

    if (moderator == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Welcome, ${moderator.firstName}'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader(context, "Content Creation"),
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
                    _buildAdminCard(context, icon: Icons.fitness_center, title: 'Add Vocal Day', onTap: () => _navigateToAddVocalDay(context)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(context, "Content Management"),
                _buildManageListTile(
                  context,
                  icon: Icons.rate_review_outlined,
                  title: 'Review Suggestions',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewSuggestionsScreen())),
                  trailing: StreamBuilder<List<Suggestion>>(
                    stream: firebaseService.getSuggestionsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final pendingCount = snapshot.data!.where((s) => s.status == SuggestionStatus.pending).length;
                      if (pendingCount == 0) return const SizedBox.shrink();
                      return Badge(
                        label: Text('$pendingCount'),
                        child: const Icon(Icons.arrow_forward_ios, size: 16),
                      );
                    },
                  ),
                ),
                _buildManageListTile(context, icon: Icons.edit, title: 'Manage Artists', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageArtistsScreen()))),
                _buildManageListTile(context, icon: Icons.edit_note, title: 'Manage Albums', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAlbumsScreen()))),
                _buildManageListTile(context, icon: Icons.edit_document, title: 'Manage Songs', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSongsScreen()))),
                _buildManageListTile(context, icon: Icons.model_training, title: 'Manage Vocal Plans', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocalPlansScreen()))),
                _buildManageListTile(context, icon: Icons.list_alt_rounded, title: 'Manage General Exercises', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageGeneralExercisesScreen()))),

                if (authProvider.isAdmin) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, "Admin Controls"),
                  _buildManageListTile(context, icon: Icons.people_alt_outlined, title: 'Manage Moderators', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageModeratorsScreen())), isDanger: true),
                  _buildManageListTile(
                    context,
                    icon: Icons.history_toggle_off_rounded,
                    title: 'Activities',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
                    isDanger: true,
                    trailing: StreamBuilder<List<ActivityLog>>(
                      stream: firebaseService.getActivityLogsStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final unseenCount = snapshot.data!.where((log) => !log.isSeen).length;
                        if (unseenCount == 0) return const Icon(Icons.arrow_forward_ios, size: 16);
                        return Badge(
                          label: Text('$unseenCount'),
                          child: const Icon(Icons.arrow_forward_ios, size: 16),
                        );
                      },
                    ),
                  ),
                  _buildManageListTile(context, icon: Icons.analytics_outlined, title: 'App Analytics', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())), isDanger: true),
                ]
              ]),
            ),
          )
        ],
      ),
    );
  }

  void _navigateToAddVocalDay(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocalPlansScreen()));
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
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

  Widget _buildManageListTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, bool isDanger = false, Widget? trailing}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDanger ? theme.colorScheme.error : theme.colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}