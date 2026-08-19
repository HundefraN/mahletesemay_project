import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../admin/activity_screen.dart';
import '../../admin/add_album_screen.dart';
import '../../admin/add_artists_screen.dart';
import '../../admin/add_song_screen.dart';
import '../../admin/analytics_screen.dart';
import '../../admin/create_invitation_screen.dart';
import '../../admin/manage_album_screen.dart';
import '../../admin/manage_artists_screen.dart';
import '../../admin/manage_general_exercises_screen.dart';
import '../../admin/manage_invite_codes_screen.dart';
import '../../admin/manage_moderators_screen.dart';
import '../../admin/manage_songs_screen.dart';
import '../../admin/review_suggestion_screen.dart';
import '../../admin/widgets/admin_ui_kit.dart';
import '../../models/suggestion_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_service.dart';
import '../home_screen.dart';
import 'manage_vocal_plans_screen.dart';

class PortalHomeScreen extends StatelessWidget {
  const PortalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final moderator = authProvider.currentModerator;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firebaseService = FirebaseService();

    if (moderator == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AdminUiKit.goldAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Sleek 2026 Hero Sliver App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF0A1E3F) : AdminUiKit.primaryNavy,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              },
            ),
            actions: [
              IconButton(
                tooltip: 'App Analytics',
                icon: const Icon(Icons.insights_rounded, color: AdminUiKit.goldHighlight, size: 22),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient mesh gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0A1E3F),
                          const Color(0xFF132A52),
                          AdminUiKit.goldAccent.withOpacity(0.35),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Subtle glowing geometric spheres
                  Positioned(
                    top: -30,
                    right: -20,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AdminUiKit.goldAccent.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // User Profile Hero Info
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AdminUiKit.goldAccent, AdminUiKit.goldHighlight],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AdminUiKit.goldAccent.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              moderator.firstName.isNotEmpty
                                  ? moderator.firstName[0].toUpperCase()
                                  : 'M',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AdminUiKit.primaryNavy,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Welcome, ${moderator.firstName}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AdminStatusBadge(
                                    label: moderator.role.toUpperCase(),
                                    color: authProvider.isAdmin ? AdminUiKit.goldHighlight : AdminUiKit.royalBlue,
                                    fontSize: 10,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                moderator.email,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  // Quick Actions Grid Header
                  const AdminSectionHeader(
                    title: 'Quick Actions',
                    icon: Icons.bolt_rounded,
                  ),
                  const SizedBox(height: 4),

                  // 2x2 Quick Actions Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.15,
                    children: [
                      _buildQuickActionCard(
                        context,
                        title: 'Add Artist',
                        subtitle: 'Create profile',
                        icon: Icons.person_add_alt_1_rounded,
                        accentColor: AdminUiKit.royalBlue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddArtistScreen()),
                        ),
                      ),
                      _buildQuickActionCard(
                        context,
                        title: 'Add Album',
                        subtitle: 'Upload release',
                        icon: Icons.album_rounded,
                        accentColor: AdminUiKit.amberOrange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddAlbumScreen()),
                        ),
                      ),
                      _buildQuickActionCard(
                        context,
                        title: 'Add Song',
                        subtitle: 'Lyrics & scales',
                        icon: Icons.music_note_rounded,
                        accentColor: AdminUiKit.emeraldGreen,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddSongScreen()),
                        ),
                      ),
                      _buildQuickActionCard(
                        context,
                        title: 'Suggestions',
                        subtitle: 'Review submissions',
                        icon: Icons.rate_review_rounded,
                        accentColor: AdminUiKit.violetPurple,
                        badgeStream: firebaseService.getSuggestionsStream().map(
                              (list) => list.where((s) => s.status == SuggestionStatus.pending).length,
                            ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReviewSuggestionsScreen()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Content Management
                  const AdminSectionHeader(
                    title: 'Content Management',
                    icon: Icons.folder_copy_rounded,
                  ),
                  const SizedBox(height: 4),

                  _buildModernListTile(
                    context,
                    title: 'Manage Songs',
                    subtitle: 'Edit lyrics, scales, rhythms, and batch delete',
                    icon: Icons.queue_music_rounded,
                    accentColor: AdminUiKit.emeraldGreen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageSongsScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: 'Manage Albums',
                    subtitle: 'Organize albums, covers, and track lists',
                    icon: Icons.library_music_rounded,
                    accentColor: AdminUiKit.amberOrange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageAlbumsScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: 'Manage Artists',
                    subtitle: 'Update artist photos, bio, and regions',
                    icon: Icons.people_outline_rounded,
                    accentColor: AdminUiKit.royalBlue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageArtistsScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: 'Manage Vocal Plans',
                    subtitle: 'Daily, weekly, monthly & quarterly routines',
                    icon: Icons.fitness_center_rounded,
                    accentColor: AdminUiKit.goldAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageVocalPlansScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: 'General Vocal Exercises',
                    subtitle: 'Independent workout audio drills',
                    icon: Icons.graphic_eq_rounded,
                    accentColor: AdminUiKit.violetPurple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageGeneralExercisesScreen()),
                    ),
                  ),

                  // Admin-Only Section
                  if (authProvider.isAdmin) ...[
                    const SizedBox(height: 24),
                    const AdminSectionHeader(
                      title: 'Admin Controls & Security',
                      icon: Icons.security_rounded,
                    ),
                    const SizedBox(height: 4),

                    _buildModernListTile(
                      context,
                      title: 'Manage Moderators',
                      subtitle: 'Device authorizations, role elevation, blocks',
                      icon: Icons.admin_panel_settings_rounded,
                      accentColor: AdminUiKit.goldAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModeratorsManagementScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title: 'Create Invitation Code',
                      subtitle: 'Generate secure single-use access credentials',
                      icon: Icons.send_rounded,
                      accentColor: AdminUiKit.royalBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateInvitationScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title: 'Invitation Codes History',
                      subtitle: 'Track claimed, active & pending invitations',
                      icon: Icons.vpn_key_rounded,
                      accentColor: AdminUiKit.amberOrange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageInviteCodesScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title: 'Audit Activity Logs',
                      subtitle: 'Real-time moderator action timeline',
                      icon: Icons.history_rounded,
                      accentColor: AdminUiKit.violetPurple,
                      badgeStream: firebaseService
                          .getActivityLogsStream()
                          .map((list) => list.where((log) => !log.isSeen).length),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivityScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title: 'App Analytics & Insights',
                      subtitle: 'Live traffic, view charts, and database metrics',
                      icon: Icons.analytics_rounded,
                      accentColor: AdminUiKit.emeraldGreen,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<bool>(
                      stream: SupabaseService().getRepairModeStream(),
                      initialData: SupabaseService().lastKnownRepairMode,
                      builder: (context, snapshot) {
                        final isRepairMode = snapshot.data ?? false;
                        return _buildModernListTile(
                          context,
                          title: 'App Repair Mode',
                          subtitle: isRepairMode
                              ? 'Active • App locked for maintenance'
                              : 'Inactive • App is live & accessible',
                          icon: isRepairMode ? Icons.build_circle_rounded : Icons.build_circle_outlined,
                          accentColor: isRepairMode ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen,
                          onTap: () => _showBeautifulRepairDialog(context, isRepairMode, moderator, authProvider),
                          trailingWidget: Switch.adaptive(
                            value: isRepairMode,
                            onChanged: (val) => _showBeautifulRepairDialog(context, isRepairMode, moderator, authProvider),
                            activeColor: AdminUiKit.roseRed,
                            activeTrackColor: AdminUiKit.roseRed.withOpacity(0.35),
                          ),
                        );
                      }
                    ),
                  ],

                  const SizedBox(height: 60),
                ].animate(interval: 50.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBeautifulRepairDialog(BuildContext context, bool isRepairMode, dynamic moderator, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1D33) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: (isRepairMode ? AdminUiKit.emeraldGreen : AdminUiKit.roseRed).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isRepairMode ? AdminUiKit.emeraldGreen : AdminUiKit.roseRed).withOpacity(0.15),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isRepairMode ? AdminUiKit.emeraldGreen : AdminUiKit.roseRed).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRepairMode ? Icons.lock_open_rounded : Icons.build_circle_rounded,
                  color: isRepairMode ? AdminUiKit.emeraldGreen : AdminUiKit.roseRed,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isRepairMode ? 'Deactivate Repair Mode?' : 'Activate Repair Mode?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isRepairMode
                    ? 'This will deactivate repair mode and unlock the app. All users will regain full access to all features immediately.'
                    : 'This will activate repair mode and lock the app for everyone except Admins. Users will see a maintenance screen. Proceed with caution!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 2),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isRepairMode ? AdminUiKit.emeraldGreen : AdminUiKit.roseRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final adminId = moderator?.id ?? authProvider.currentUser?.id ?? 'admin';
                        final adminName = moderator?.fullName ?? authProvider.currentUser?.email ?? 'Admin';
                        try {
                          await SupabaseService().setRepairMode(
                            !isRepairMode,
                            adminId,
                            adminName,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(!isRepairMode ? 'Repair Mode is now Active (App Locked)' : 'Repair Mode is now Inactive (App Unlocked)'),
                                backgroundColor: !isRepairMode ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: Text(
                        isRepairMode ? 'Deactivate (Unlock)' : 'Activate (Lock)',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    Stream<int>? badgeStream,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          if (badgeStream != null)
            Positioned(
              top: 0,
              right: 0,
              child: StreamBuilder<int>(
                stream: badgeStream,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminUiKit.roseRed,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AdminUiKit.roseRed.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernListTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
    Stream<int>? badgeStream,
    Widget? trailingWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AdminGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 18,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badgeStream != null)
              StreamBuilder<int>(
                stream: badgeStream,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminUiKit.roseRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            trailingWidget ?? Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}