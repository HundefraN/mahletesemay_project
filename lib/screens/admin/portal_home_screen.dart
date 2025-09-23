import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/suggestion_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../admin/activity_screen.dart';
import '../../admin/add_album_screen.dart';
import '../../admin/add_artists_screen.dart';
import '../../admin/add_moderators_screen.dart';
import '../../admin/add_song_screen.dart';
import '../../admin/analytics_screen.dart';
import '../../admin/create_invitation_screen.dart';
import '../../admin/manage_album_screen.dart';
import '../../admin/manage_artists_screen.dart';
import '../../admin/manage_general_exercises_screen.dart';
import '../../admin/manage_moderators_screen.dart';
import '../../admin/manage_songs_screen.dart';
import '../../admin/review_suggestion_screen.dart';

import '../../providers/auth_proveider.dart';
import 'manage_vocal_plans_screen.dart';

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
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Welcome, ${moderator.firstName}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              centerTitle: false,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Stack(
                  children: [
                    Positioned(top: -50, right: -50, child: Icon(Icons.shield_moon, size: 200, color: Colors.white10)),
                    Positioned(bottom: 20, left: -40, child: Icon(Icons.music_note, size: 150, color: Colors.white10)),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildSectionHeader(context, "Quick Actions"),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildAdminCard(context, icon: Icons.person_add_alt_1, title: 'Add Artist', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddArtistScreen()))),
                      _buildAdminCard(context, icon: Icons.album_outlined, title: 'Add Album', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAlbumScreen()))),
                      _buildAdminCard(context, icon: Icons.music_note_outlined, title: 'Add Song', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSongScreen()))),
                      _buildAdminCard(
                          context,
                          icon: Icons.rate_review_outlined,
                          title: 'Review Suggestions',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewSuggestionsScreen())),
                          badgeStream: firebaseService.getSuggestionsStream().map((list) => list.where((s) => s.status == SuggestionStatus.pending).length)
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, "Content Management"),
                  _buildManageListTile(context, icon: Icons.edit, title: 'Manage Artists', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageArtistsScreen()))),
                  _buildManageListTile(context, icon: Icons.edit_note, title: 'Manage Albums', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAlbumsScreen()))),
                  _buildManageListTile(context, icon: Icons.edit_document, title: 'Manage Songs', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSongsScreen()))),
                  _buildManageListTile(context, icon: Icons.model_training, title: 'Manage Vocal Plans', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageVocalPlansScreen()))),
                  _buildManageListTile(context, icon: Icons.list_alt_rounded, title: 'Manage General Exercises', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageGeneralExercisesScreen()))),

                  if (authProvider.isAdmin) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, "Admin Controls"),
                    _buildManageListTile(context, icon: Icons.people_alt_outlined, title: 'Manage Moderators', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModeratorsManagementScreen()))),
                    _buildManageListTile(context, icon: Icons.person_add, title: 'Add New Moderator', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddModeratorScreen()))),
                    _buildManageListTile(context, icon: Icons.card_membership_rounded, title: 'Create Invitation', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateInvitationScreen()))),
                    _buildManageListTile(
                      context,
                      icon: Icons.history_toggle_off_rounded,
                      title: 'Activities',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
                      badgeStream: firebaseService.getActivityLogsStream().map((list) => list.where((log) => !log.isSeen).length),
                    ),
                    _buildManageListTile(context, icon: Icons.analytics_outlined, title: 'App Analytics', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
                  ],
                  const SizedBox(height: 80),
                ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: 0.1),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, Stream<int>? badgeStream}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ],
              ),
            ),
            if (badgeStream != null)
              Positioned(
                top: 8,
                right: 8,
                child: StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == 0) return const SizedBox.shrink();
                    return Badge(
                      label: Text(snapshot.data.toString()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageListTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, bool isDanger = false, Stream<int>? badgeStream}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDanger ? theme.colorScheme.error : theme.colorScheme.secondary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isDanger ? theme.colorScheme.error : theme.colorScheme.secondary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeStream != null)
              StreamBuilder<int>(
                stream: badgeStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Badge(
                      backgroundColor: isDanger ? theme.colorScheme.error : theme.colorScheme.secondary,
                      label: Text(snapshot.data.toString()),
                    ),
                  );
                },
              ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}