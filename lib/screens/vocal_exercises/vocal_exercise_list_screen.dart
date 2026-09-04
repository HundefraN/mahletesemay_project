import 'dart:async';
import 'dart:ui' as ui;
import 'package:animations/animations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/managers/download_manager.dart';
import 'package:mahlete_semay_project/screens/pitch_trainer/pitch_trainer_screen.dart';
import 'package:mahlete_semay_project/screens/lessons/lessons_screen.dart';
import 'package:mahlete_semay_project/screens/vocal_exercises/vocal_plan_detail_screen.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:mahlete_semay_project/widgets/real_audio_waveform_visualizer.dart';
import '../../widgets/web_content_wrapper.dart';
import 'gender_selection_screen.dart';

class VocalExerciseListScreen extends StatelessWidget {
  const VocalExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progressProvider = Provider.of<VocalProgressProvider>(context);
    final firebaseService = FirebaseService();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (progressProvider.gender == null) {
      return const GenderSelectionScreen();
    }

    final genderPrefix = progressProvider.gender!.toLowerCase();
    final planData = [
      {
        'title': l10n.dailyWarmUp,
        'subtitle': l10n.dailyWarmUpDesc,
        'planId': '${genderPrefix}_daily',
        'icon': Icons.wb_sunny_rounded,
        'gradient': const [Color(0xFFFF5E62), Color(0xFFFF9966)],
      },
      {
        'title': l10n.weeklyWorkout,
        'subtitle': l10n.weeklyWorkoutDesc,
        'planId': '${genderPrefix}_weekly',
        'icon': Icons.bolt_rounded,
        'gradient': const [Color(0xFF6A11CB), Color(0xFF2575FC)],
      },
      {
        'title': l10n.monthlyChallenge,
        'subtitle': l10n.monthlyChallengeDesc,
        'planId': '${genderPrefix}_monthly',
        'icon': Icons.workspace_premium_rounded,
        'gradient': const [Color(0xFF00C6FF), Color(0xFF0072FF)],
      },
      {
        'title': l10n.threeMonthTransformation,
        'subtitle': l10n.threeMonthTransformationDesc,
        'planId': '${genderPrefix}_quarterly',
        'icon': Icons.auto_graph_rounded,
        'gradient': const [Color(0xFFF857A6), Color(0xFFFF5858)],
      },
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Glassmorphic Atmospheric Floating Header
          SliverAppBar(
            expandedHeight: context.w(210),
            pinned: true,
            stretch: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.75),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Ambient Radial Glow Background
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.6, -0.4),
                            radius: 1.2,
                            colors: isDark
                                ? [
                                    theme.colorScheme.primary.withValues(alpha: 0.35),
                                    theme.colorScheme.surface,
                                  ]
                                : [
                                    theme.colorScheme.primary.withValues(alpha: 0.18),
                                    theme.colorScheme.surface,
                                  ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -context.w(30),
                        right: -context.w(30),
                        child: Container(
                          width: context.w(180),
                          height: context.w(180),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                theme.colorScheme.secondary.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.w(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: context.w(16)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.w(12),
                                  vertical: context.w(5),
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(context.w(20)),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  l10n.vocalCoaching,
                                  style: GoogleFonts.poppins(
                                    fontSize: context.sp(10),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              SizedBox(height: context.w(8)),
                              Text(
                                l10n.shapeYourVoice,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w400,
                                  fontSize: context.sp(20),
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                l10n.masterYourCraft,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w900,
                                  fontSize: context.sp(26),
                                  letterSpacing: -0.5,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              _buildLessonsButton(context),
              Padding(
                padding: EdgeInsets.only(right: context.w(16)),
                child: IconButton.filledTonal(
                  icon: Icon(Icons.tune_rounded, size: context.w(20)),
                  tooltip: l10n.pitchTrainer,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.w(14))),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PitchTrainerScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          // Section Title: Structured Plans
          SliverWebContentWrapper(
            maxWidth: 1000,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    context.w(20), context.w(24), context.w(20), context.w(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.structuredPlans,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: context.sp(19),
                        letterSpacing: -0.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(context.w(6)),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome_rounded,
                          size: context.w(16), color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Vocal Plans Grid / List
          SliverWebContentWrapper(
            maxWidth: 1000,
            sliver: SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.w(20)),
              sliver: !context.isPhone
                  ? SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.isDesktop ? 3 : 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.6,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final plan = planData[index];
                          final colors = plan['gradient'] as List<Color>;
                          return _ModernPlanCard(
                            title: plan['title'] as String,
                            subtitle: plan['subtitle'] as String,
                            planId: plan['planId'] as String,
                            icon: plan['icon'] as IconData,
                            colors: colors,
                          );
                        },
                        childCount: planData.length,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final plan = planData[index];
                          final colors = plan['gradient'] as List<Color>;
                          return _ModernPlanCard(
                            title: plan['title'] as String,
                            subtitle: plan['subtitle'] as String,
                            planId: plan['planId'] as String,
                            icon: plan['icon'] as IconData,
                            colors: colors,
                          );
                        },
                        childCount: planData.length,
                      ),
                    ),
            ),
          ),

          // Section Title: General Exercises
          SliverWebContentWrapper(
            maxWidth: 1000,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    context.w(20), context.w(28), context.w(20), context.w(14)),
                child: Text(
                  l10n.generalExercises,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: context.sp(19),
                    letterSpacing: -0.3,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

          SliverWebContentWrapper(
            maxWidth: 1000,
            sliver: _buildGeneralExercisesList(context, firebaseService),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.w(120))),
        ],
      ),
    );
  }

  Widget _buildLessonsButton(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(right: context.w(8)),
      child: IconButton.filledTonal(
        icon: Icon(Icons.school_outlined, size: context.w(20)),
        tooltip: AppLocalizations.of(context)?.lessonsAndTutorials ?? 'Lessons & Tutorials',
        style: IconButton.styleFrom(
          backgroundColor:
              theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.w(14))),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LessonsScreen()),
          );
        },
      ),
    );
  }



  Widget _buildGeneralExercisesList(
      BuildContext context, FirebaseService firebaseService) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<VocalExerciseDay>>(
      stream: firebaseService.getGeneralExercisesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: ListTileShimmer());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(context.w(24)),
                child: Text(
                  l10n.noGeneralExercises,
                  style: GoogleFonts.poppins(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }
        final exercises = snapshot.data!;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.w(20)),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final exercise = exercises[index];
                return OpenContainer(
                  transitionType: ContainerTransitionType.fadeThrough,
                  closedElevation: 0,
                  openElevation: 0,
                  closedColor: Colors.transparent,
                  openColor: Colors.transparent,
                  closedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.w(20))),
                  openBuilder: (ctx, action) =>
                      _ExerciseDetailSheet(exercise: exercise),
                  closedBuilder: (ctx, openContainer) {
                    return Container(
                      margin: EdgeInsets.only(bottom: context.w(12)),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(context.w(20)),
                        border: Border.all(
                          color:
                              theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(context.w(20)),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            openContainer();
                          },
                          borderRadius: BorderRadius.circular(context.w(20)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.w(16),
                              vertical: context.w(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(context.w(12)),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primaryContainer,
                                        theme.colorScheme.primary
                                            .withValues(alpha: 0.2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(context.w(16)),
                                  ),
                                  child: Icon(
                                    Icons.graphic_eq_rounded,
                                    size: context.w(22),
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                SizedBox(width: context.w(14)),
                                Expanded(
                                  child: Text(
                                    exercise.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: context.sp(14),
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(context.w(8)),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.surface,
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: context.w(12),
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: exercises.length,
            ),
          ),
        );
      },
    );
  }
}

class _ModernPlanCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String planId;
  final IconData icon;
  final List<Color> colors;

  const _ModernPlanCard({
    required this.title,
    required this.subtitle,
    required this.planId,
    required this.icon,
    required this.colors,
  });

  @override
  State<_ModernPlanCard> createState() => _ModernPlanCardState();
}

class _ModernPlanCardState extends State<_ModernPlanCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.w(24))),
      openBuilder: (ctx, action) =>
          VocalPlanDetailScreen(planId: widget.planId, planTitle: widget.title),
      closedBuilder: (ctx, openContainer) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            openContainer();
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Container(
              margin: EdgeInsets.only(bottom: context.w(16)),
              padding: EdgeInsets.all(context.w(20)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.w(24)),
                gradient: LinearGradient(
                  colors: widget.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.colors.first.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.w(10)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(context.w(16)),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.5),
                        ),
                        child: Icon(widget.icon,
                            color: Colors.white, size: context.w(22)),
                      ),
                      SizedBox(width: context.w(14)),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: context.sp(17),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(context.w(6)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.north_east_rounded,
                          color: Colors.white,
                          size: context.w(16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.w(12)),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: context.sp(12.5),
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: context.w(18)),
                  StreamBuilder(
                    stream:
                        firebaseService.getVocalPlanDaysStream(widget.planId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: context.w(6),
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        );
                      }
                      final totalDays = snapshot.data!.length;
                      final completedDays =
                          Provider.of<VocalProgressProvider>(context)
                                  .progress[widget.planId]
                                  ?.length ??
                              0;
                      final progress =
                          totalDays > 0 ? completedDays / totalDays : 0.0;
                      return Row(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: context.w(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                AnimatedFractionallySizedBox(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.fastOutSlowIn,
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    height: context.w(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: context.w(14)),
                          Text(
                            '$completedDays / $totalDays',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: context.sp(12),
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  final VocalExerciseDay exercise;
  const _ExerciseDetailSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: context.w(220),
            backgroundColor: theme.colorScheme.primaryContainer,
            leading: Padding(
              padding: EdgeInsets.all(context.w(8)),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.fromLTRB(
                  context.w(20), 0, context.w(20), context.w(16)),
              title: Text(
                exercise.title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: context.sp(16),
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: context.w(110),
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(context.w(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.aboutExercise ?? "About Exercise",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: context.sp(15),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: context.w(8)),
                  Text(
                    exercise.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      fontSize: context.sp(14.5),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  SizedBox(height: context.w(32)),
                  if (exercise.audioUrl != null)
                    _ModernAudioPlayer(
                      audioUrl: exercise.audioUrl!,
                      key: ValueKey(exercise.audioUrl),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernAudioPlayer extends StatefulWidget {
  final String audioUrl;
  const _ModernAudioPlayer({super.key, required this.audioUrl});

  @override
  State<_ModernAudioPlayer> createState() => __ModernAudioPlayerState();
}

class __ModernAudioPlayerState extends State<_ModernAudioPlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  late AnimationController _animationController;

  String? _localPath;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
      if (state == PlayerState.playing) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    _durationSubscription = _audioPlayer.onDurationChanged
        .listen((d) => setState(() => _duration = d));
    _positionSubscription = _audioPlayer.onPositionChanged
        .listen((p) => setState(() => _position = p));
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final manager = Provider.of<DownloadManager>(context, listen: false);
    _localPath = await manager.getLocalPath(widget.audioUrl);
    if (_localPath != null) {
      await _audioPlayer.setSourceDeviceFile(_localPath!);
    } else {
      await _audioPlayer.setSourceUrl(widget.audioUrl);
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    final speeds = [0.8, 1.0, 1.25, 1.5];
    final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    setState(() => _playbackSpeed = speeds[nextIndex]);
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  String _formatDuration(Duration d) =>
      d.toString().split('.').first.padLeft(8, "0").substring(3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaying = _playerState == PlayerState.playing;

    return Container(
      padding: EdgeInsets.all(context.w(18)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(context.w(24)),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Real Physical Audio Waveform Visualizer
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(4)),
            child: RealAudioWaveformVisualizer(
              audioUrl: widget.audioUrl,
              localFilePath: _localPath,
              currentPosition: _position,
              totalDuration: _duration,
              isPlaying: isPlaying,
              height: context.w(36),
              barCount: 44,
              onSeek: (position) async {
                await _audioPlayer.seek(position);
                if (_playerState != PlayerState.playing) {
                  await _audioPlayer.resume();
                }
              },
            ),
          ),
          SizedBox(height: context.w(8)),

          // Timeline Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: context.w(4),
              thumbShape:
                  RoundSliderThumbShape(enabledThumbRadius: context.w(6)),
              overlayShape:
                  RoundSliderOverlayShape(overlayRadius: context.w(12)),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              min: 0,
              max: _duration.inSeconds.toDouble(),
              value: _position.inSeconds
                  .toDouble()
                  .clamp(0, _duration.inSeconds.toDouble()),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
                if (_playerState != PlayerState.playing) {
                  await _audioPlayer.resume();
                }
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.w(12)),

          // Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed Pill Toggle
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(context.w(12)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(10),
                    vertical: context.w(5),
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(context.w(12)),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(11),
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

              // Rewind 10s
              IconButton(
                icon: Icon(Icons.replay_10_rounded, size: context.w(22)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final newPos = _position - const Duration(seconds: 10);
                  _audioPlayer
                      .seek(newPos < Duration.zero ? Duration.zero : newPos);
                },
              ),

              // Play / Pause FAB Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_playerState == PlayerState.playing) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.resume();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: context.w(52),
                  height: context.w(52),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedIcon(
                      icon: AnimatedIcons.play_pause,
                      progress: _animationController,
                      color: theme.colorScheme.onPrimary,
                      size: context.w(26),
                    ),
                  ),
                ),
              ),

              // Forward 10s
              IconButton(
                icon: Icon(Icons.forward_10_rounded, size: context.w(22)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final newPos = _position + const Duration(seconds: 10);
                  _audioPlayer.seek(newPos > _duration ? _duration : newPos);
                },
              ),

              // Offline Status Icon
              Icon(
                _localPath != null
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_download_outlined,
                size: context.w(20),
                color: _localPath != null
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
