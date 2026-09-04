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
import '../../utils/responsive_sizer.dart';
import '../home_screen.dart';
import 'app_release_management_screen.dart';
import 'manage_vocal_plans_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../l10n/app_localizations.dart';

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
      backgroundColor:
          isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Sleek 2026 Hero Sliver App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor:
                isDark ? const Color(0xFF0A1E3F) : AdminUiKit.primaryNavy,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
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
                icon: const Icon(Icons.insights_rounded,
                    color: AdminUiKit.goldHighlight, size: 22),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground
              ],
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
                          AdminUiKit.goldAccent.withValues(alpha: 0.35),
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
                        color: AdminUiKit.goldAccent.withValues(alpha: 0.12),
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
                        color: Colors.blueAccent.withValues(alpha: 0.1),
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
                              colors: [
                                AdminUiKit.goldAccent,
                                AdminUiKit.goldHighlight
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AdminUiKit.goldAccent
                                    .withValues(alpha: 0.3),
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
                                    color: authProvider.isAdmin
                                        ? AdminUiKit.goldHighlight
                                        : AdminUiKit.royalBlue,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSectionHeader(
                    title: AppLocalizations.of(context)?.quickActions ??
                        'Quick Actions',
                    icon: Icons.bolt_rounded,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount:
                        context.isDesktop ? 4 : (context.isTablet ? 3 : 2),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      _buildQuickActionCard(
                        context,
                        title: AppLocalizations.of(context)?.addArtist ??
                            'Add Artist',
                        subtitle: AppLocalizations.of(context)
                                ?.createProfileSubtitle ??
                            'Create profile',
                        icon: Icons.person_add_alt_1_rounded,
                        accentColor: AdminUiKit.royalBlue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddArtistScreen()),
                        ),
                      ),
                      _buildQuickActionCard(
                        context,
                        title: AppLocalizations.of(context)?.addAlbum ??
                            'Add Album',
                        subtitle: AppLocalizations.of(context)
                                ?.uploadReleaseSubtitle ??
                            'Upload release',
                        icon: Icons.album_rounded,
                        accentColor: AdminUiKit.amberOrange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddAlbumScreen()),
                        ),
                      ),
                      _buildQuickActionCard(
                        context,
                        title:
                            AppLocalizations.of(context)?.addSong ?? 'Add Song',
                        subtitle: AppLocalizations.of(context)
                                ?.lyricsScalesSubtitle ??
                            'Lyrics & scales',
                        icon: Icons.queue_music_rounded,
                        accentColor: AdminUiKit.emeraldGreen,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddSongScreen()),
                        ),
                      ),
                      _buildQuickActionCard(
                        context,
                        title:
                            AppLocalizations.of(context)?.reviewSuggestions ??
                                'Suggestions',
                        subtitle: AppLocalizations.of(context)
                                ?.reviewSubmissionsSubtitle ??
                            'Review submissions',
                        icon: Icons.rate_review_rounded,
                        accentColor: AdminUiKit.violetPurple,
                        badgeStream: firebaseService.getSuggestionsStream().map(
                              (list) => list
                                  .where((s) =>
                                      s.status == SuggestionStatus.pending)
                                  .length,
                            ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReviewSuggestionsScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AdminSectionHeader(
                    title: AppLocalizations.of(context)?.contentManagement ??
                        'Content Management',
                    icon: Icons.folder_copy_rounded,
                  ),
                  const SizedBox(height: 4),
                  _buildModernListTile(
                    context,
                    title: AppLocalizations.of(context)?.manageSongs ??
                        'Manage Songs',
                    subtitle: AppLocalizations.of(context)?.batchEditSubtitle ??
                        'Edit lyrics, scales, rhythms, and batch delete',
                    icon: Icons.queue_music_rounded,
                    accentColor: AdminUiKit.emeraldGreen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageSongsScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: AppLocalizations.of(context)?.manageAlbums ??
                        'Manage Albums',
                    subtitle:
                        AppLocalizations.of(context)?.organizeAlbumsSubtitle ??
                            'Organize albums, covers, and track lists',
                    icon: Icons.library_music_rounded,
                    accentColor: AdminUiKit.amberOrange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageAlbumsScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: AppLocalizations.of(context)?.manageArtists ??
                        'Manage Artists',
                    subtitle:
                        AppLocalizations.of(context)?.updateArtistBioSubtitle ??
                            'Update artist photos, bio, and regions',
                    icon: Icons.people_outline_rounded,
                    accentColor: AdminUiKit.royalBlue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageArtistsScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title: AppLocalizations.of(context)?.manageVocalPlans ??
                        'Manage Vocal Plans',
                    subtitle:
                        AppLocalizations.of(context)?.vocalRoutinesSubtitle ??
                            'Daily, weekly, monthly & quarterly routines',
                    icon: Icons.fitness_center_rounded,
                    accentColor: AdminUiKit.goldAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageVocalPlansScreen()),
                    ),
                  ),
                  _buildModernListTile(
                    context,
                    title:
                        AppLocalizations.of(context)?.generalVocalExercises ??
                            'General Vocal Exercises',
                    subtitle: AppLocalizations.of(context)
                            ?.independentDrillsSubtitle ??
                        'Independent workout audio drills',
                    icon: Icons.graphic_eq_rounded,
                    accentColor: AdminUiKit.violetPurple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageGeneralExercisesScreen()),
                    ),
                  ),
                  if (authProvider.isAdmin) ...[
                    const SizedBox(height: 24),
                    AdminSectionHeader(
                      title:
                          AppLocalizations.of(context)?.adminControlsSecurity ??
                              'Admin Controls & Security',
                      icon: Icons.security_rounded,
                    ),
                    const SizedBox(height: 4),
                    _buildModernListTile(
                      context,
                      title: AppLocalizations.of(context)?.manageModerators ??
                          'Manage Moderators',
                      subtitle:
                          AppLocalizations.of(context)?.deviceAuthSubtitle ??
                              'Device authorizations, role elevation, blocks',
                      icon: Icons.admin_panel_settings_rounded,
                      accentColor: AdminUiKit.goldAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ModeratorsManagementScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title:
                          AppLocalizations.of(context)?.createInvitationCode ??
                              'Create Invitation Code',
                      subtitle: AppLocalizations.of(context)
                              ?.generateCredentialsSubtitle ??
                          'Generate secure single-use access credentials',
                      icon: Icons.send_rounded,
                      accentColor: AdminUiKit.royalBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateInvitationScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title: AppLocalizations.of(context)
                              ?.invitationCodesHistory ??
                          'Invitation Codes History',
                      subtitle: AppLocalizations.of(context)
                              ?.trackInvitationsSubtitle ??
                          'Track claimed, active & pending invitations',
                      icon: Icons.vpn_key_rounded,
                      accentColor: AdminUiKit.amberOrange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageInviteCodesScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title: AppLocalizations.of(context)?.auditActivityLogs ??
                          'Audit Activity Logs',
                      subtitle: AppLocalizations.of(context)
                              ?.actionTimelineSubtitle ??
                          'Real-time moderator action timeline',
                      icon: Icons.history_rounded,
                      accentColor: AdminUiKit.violetPurple,
                      badgeStream: firebaseService.getActivityLogsStream().map(
                          (list) => list.where((log) => !log.isSeen).length),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ActivityScreen()),
                      ),
                    ),
                    _buildModernListTile(
                      context,
                      title:
                          AppLocalizations.of(context)?.appAnalyticsInsights ??
                              'App Analytics & Insights',
                      subtitle:
                          AppLocalizations.of(context)?.liveMetricsSubtitle ??
                              'Live traffic, view charts, and database metrics',
                      icon: Icons.analytics_rounded,
                      accentColor: AdminUiKit.emeraldGreen,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AnalyticsScreen()),
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
                            title:
                                AppLocalizations.of(context)?.appRepairMode ??
                                    'App Repair Mode',
                            subtitle: isRepairMode
                                ? (AppLocalizations.of(context)
                                        ?.repairModeActive ??
                                    'Active • App locked for maintenance')
                                : (AppLocalizations.of(context)
                                        ?.repairModeInactive ??
                                    'Inactive • App is live & accessible'),
                            icon: isRepairMode
                                ? Icons.build_circle_rounded
                                : Icons.build_circle_outlined,
                            accentColor: isRepairMode
                                ? AdminUiKit.roseRed
                                : AdminUiKit.emeraldGreen,
                            onTap: () => _showBeautifulRepairDialog(
                                context, isRepairMode, moderator, authProvider),
                            trailingWidget: Switch.adaptive(
                              value: isRepairMode,
                              onChanged: (val) => _showBeautifulRepairDialog(
                                  context,
                                  isRepairMode,
                                  moderator,
                                  authProvider),
                              activeTrackColor: AdminUiKit.roseRed,
                            ),
                          );
                        }),
                    const SizedBox(height: 12),
                    _buildModernListTile(
                      context,
                      title: 'App Version & APK Release',
                      subtitle:
                          'Upload APK, configure semver releases, force updates & release notes',
                      icon: Icons.rocket_launch_rounded,
                      accentColor: AdminUiKit.royalBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AppReleaseManagementScreen()),
                      ),
                    ),
                  ],
                  const SizedBox(height: 60),
                ]
                    .animate(interval: 50.ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBeautifulRepairDialog(BuildContext context, bool isRepairMode,
      dynamic moderator, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1D33) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isRepairMode
                        ? AdminUiKit.emeraldGreen
                        : AdminUiKit.roseRed)
                    .withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRepairMode
                          ? AdminUiKit.emeraldGreen
                          : AdminUiKit.roseRed)
                      .withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isRepairMode
                            ? AdminUiKit.emeraldGreen
                            : AdminUiKit.roseRed)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRepairMode
                        ? Icons.lock_open_rounded
                        : Icons.build_circle_rounded,
                    color: isRepairMode
                        ? AdminUiKit.emeraldGreen
                        : AdminUiKit.roseRed,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isRepairMode
                      ? (AppLocalizations.of(context)
                              ?.repairModeDialogTitleActive ??
                          'Deactivate Repair Mode?')
                      : (AppLocalizations.of(context)
                              ?.repairModeDialogTitleInactive ??
                          'Activate Repair Mode?'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isRepairMode
                      ? (AppLocalizations.of(context)
                              ?.repairModeDialogDescActive ??
                          'This will deactivate repair mode and unlock the app. All users will regain full access to all features immediately.')
                      : (AppLocalizations.of(context)
                              ?.repairModeDialogDescInactive ??
                          'This will activate repair mode and lock the app for everyone except Admins. Users will see a maintenance screen. Proceed with caution!'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 1.5),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalizations.of(context)?.cancel ?? 'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isRepairMode
                              ? AdminUiKit.emeraldGreen
                              : AdminUiKit.roseRed,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final adminId = moderator?.id ??
                              authProvider.currentUser?.id ??
                              'admin';
                          final adminName = moderator?.fullName ??
                              authProvider.currentUser?.email ??
                              'Admin';
                          try {
                            await SupabaseService().setRepairMode(
                              !isRepairMode,
                              adminId,
                              adminName,
                            );
                            if (context.mounted) {
                              CustomSnackbar.show(
                                context,
                                !isRepairMode
                                    ? 'Repair Mode is now Active (App Locked)'
                                    : 'Repair Mode is now Inactive (App Unlocked)',
                                isError: !isRepairMode,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              CustomSnackbar.show(context, 'Error: $e',
                                  isError: true);
                            }
                          }
                        },
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
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
      ),
    );
  }

  void _showMinVersionDialog(BuildContext context, dynamic moderator,
      AuthProvider authProvider) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentMinVersion = await SupabaseService().getMinRequiredVersion();
    final controller = TextEditingController(text: currentMinVersion ?? '');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1D33) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AdminUiKit.royalBlue.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AdminUiKit.royalBlue.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminUiKit.royalBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AdminUiKit.royalBlue,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Minimum Required Version',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Users with app versions lower than this will be prompted to update. Leave blank or empty to disable force update.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Min Version (e.g. 1.0.0)',
                    hintText: 'Leave empty to disable',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 1.5),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          AppLocalizations.of(context)?.cancel ?? 'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminUiKit.royalBlue,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final adminId = moderator?.id ??
                              authProvider.currentUser?.id ??
                              'admin';
                          final adminName = moderator?.fullName ??
                              authProvider.currentUser?.email ??
                              'Admin';
                          try {
                            await SupabaseService().setMinRequiredVersion(
                              controller.text.trim(),
                              adminId,
                              adminName,
                            );
                            if (context.mounted) {
                              CustomSnackbar.show(
                                context,
                                controller.text.trim().isEmpty
                                    ? 'Force Update requirement disabled'
                                    : 'Minimum version set to ${controller.text.trim()}',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              CustomSnackbar.show(context, 'Error: $e',
                                  isError: true);
                            }
                          }
                        },
                        child: Text(
                          'Save',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminUiKit.roseRed,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AdminUiKit.roseRed.withValues(alpha: 0.4),
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
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.2),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            trailingWidget ??
                Icon(
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
