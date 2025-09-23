import 'dart:async';
import 'package:animations/animations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/managers/download_manager.dart';
import 'package:mahlete_semay_project/screens/pitch_trainer/pitch_trainer_screen.dart';
import 'package:mahlete_semay_project/screens/vocal_exercises/vocal%20_plan_detail_screen.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import '../../utils/constants.dart';
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
      {'title': l10n.dailyWarmUp, 'subtitle': l10n.dailyWarmUpDesc, 'planId': '${genderPrefix}_daily', 'icon': Icons.wb_sunny_rounded},
      {'title': l10n.weeklyWorkout, 'subtitle': l10n.weeklyWorkoutDesc, 'planId': '${genderPrefix}_weekly', 'icon': Icons.calendar_today_rounded},
      {'title': l10n.monthlyChallenge, 'subtitle': l10n.monthlyChallengeDesc, 'planId': '${genderPrefix}_monthly', 'icon': Icons.military_tech_rounded},
      {'title': l10n.threeMonthTransformation, 'subtitle': l10n.threeMonthTransformationDesc, 'planId': '${genderPrefix}_quarterly', 'icon': Icons.show_chart_rounded},
    ];

    final brandGradients = [
      LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [theme.colorScheme.secondary, Colors.orange.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Colors.purple.shade400, theme.colorScheme.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Colors.teal.shade400, theme.colorScheme.secondary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: context.w(180),
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            actions: [
              _buildDownloadButton(context),
              IconButton(
                icon: Icon(Icons.tune_rounded, size: context.w(24)),
                tooltip: 'Pitch Trainer',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PitchTrainerScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.w(12)),
              centerTitle: false,
              title: Text(l10n.vocalTraining, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(20))),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark ? [Colors.black, theme.colorScheme.primary.withOpacity(0.3)] : [theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.primary.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(context.w(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: kToolbarHeight - context.w(20)),
                        Text("Shape Your Voice,", style: TextStyle(fontSize: context.sp(16))),
                        Text("Master Your Craft.", style: TextStyle(fontSize: context.sp(20), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.w(16), context.w(24), context.w(16), context.w(8)),
              child: Text(l10n.structuredPlans, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(24))),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: context.w(16)),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final plan = planData[index];
                  return _PlanCard(
                    title: plan['title'] as String,
                    subtitle: plan['subtitle'] as String,
                    planId: plan['planId'] as String,
                    icon: plan['icon'] as IconData,
                    gradient: brandGradients[index % brandGradients.length],
                  );
                },
                childCount: planData.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.w(16), context.w(24), context.w(16), context.w(8)),
              child: Text(l10n.generalExercises, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(24))),
            ),
          ),
          _buildGeneralExercisesList(context, firebaseService),
          SliverToBoxAdapter(child: SizedBox(height: context.w(100))),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    return Consumer<DownloadManager>(
      builder: (context, manager, child) {
        switch (manager.status) {
          case DownloadStatus.downloading:
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(value: manager.totalProgress, strokeWidth: 3),
              ),
            );
          case DownloadStatus.downloaded:
            return IconButton(
              icon: Icon(Icons.cloud_done_rounded, color: Colors.green, size: context.w(24)),
              tooltip: 'Delete Offline Exercises',
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Deletion'),
                  content: const Text('Are you sure you want to delete all offline vocal exercises? You will need an internet connection to use them again.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(onPressed: () {
                      Navigator.pop(ctx);
                      manager.deleteAllFiles();
                    }, child: const Text('Delete')),
                  ],
                ),
              ),
            );
          case DownloadStatus.notDownloaded:
          case DownloadStatus.error:
          default:
            return IconButton(
              icon: Icon(manager.status == DownloadStatus.error ? Icons.cloud_off_rounded : Icons.cloud_download_outlined, size: context.w(24)),
              tooltip: manager.status == DownloadStatus.error ? 'Download Failed, Tap to Retry' : 'Download All Exercises for Offline Use',
              onPressed: () => manager.startDownloadAll(),
            );
        }
      },
    );
  }

  Widget _buildGeneralExercisesList(BuildContext context, FirebaseService firebaseService) {
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
                padding: EdgeInsets.all(context.w(16)),
                child: const Text('No general exercises available yet.'),
              ),
            ),
          );
        }
        final exercises = snapshot.data!;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final exercise = exercises[index];
                return OpenContainer(
                  transitionType: ContainerTransitionType.fadeThrough,
                  closedElevation: 0, openElevation: 0,
                  closedColor: Colors.transparent, openColor: Colors.transparent,
                  closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.w(16))),
                  openBuilder: (ctx, action) => _ExerciseDetailSheet(exercise: exercise),
                  closedBuilder: (ctx, openContainer) {
                    return Card(
                      margin: EdgeInsets.only(bottom: context.w(12)),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.w(16))),
                      child: ListTile(
                        onTap: openContainer,
                        leading: CircleAvatar(
                            radius: context.w(24),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(Icons.fitness_center, size: context.w(24), color: Theme.of(context).colorScheme.onPrimaryContainer)),
                        title: Text(exercise.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.sp(16))),
                        trailing: Icon(Icons.keyboard_arrow_right, size: context.w(24)),
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

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String planId;
  final IconData icon;
  final Gradient gradient;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.planId,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebaseService = FirebaseService();
    final cardColor = (gradient as LinearGradient).colors.first;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0, openElevation: 0,
      closedColor: Colors.transparent, openColor: Colors.transparent,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.w(20))),
      openBuilder: (ctx, action) => VocalPlanDetailScreen(planId: planId, planTitle: title),
      closedBuilder: (ctx, openContainer) {
        return GestureDetector(
          onTap: openContainer,
          child: Container(
            margin: EdgeInsets.only(bottom: context.w(16)),
            padding: EdgeInsets.all(context.w(20)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.w(20)),
              gradient: gradient,
              boxShadow: [BoxShadow(color: cardColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.w(8)),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(context.w(12))),
                      child: Icon(icon, color: Colors.white, size: context.w(24)),
                    ),
                    SizedBox(width: context.w(12)),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(18), color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.w(8)),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8), fontSize: context.sp(14))),
                SizedBox(height: context.w(16)),
                StreamBuilder(
                  stream: firebaseService.getVocalPlanDaysStream(planId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    final totalDays = snapshot.data!.length;
                    final completedDays = Provider.of<VocalProgressProvider>(context).progress[planId]?.length ?? 0;
                    final progress = totalDays > 0 ? completedDays / totalDays : 0.0;
                    return Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: context.w(8),
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: context.w(12)),
                        Text(
                          '$completedDays / $totalDays',
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(14), color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ],
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: context.w(200),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(exercise.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.sp(18), shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))])),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.music_note_rounded, size: context.w(80), color: Colors.white.withOpacity(0.3)),
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
                    exercise.description,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: context.sp(16)),
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

class __ModernAudioPlayerState extends State<_ModernAudioPlayer> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  late AnimationController _animationController;

  String? _localPath;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
      if (state == PlayerState.playing) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    },
    );
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
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

  String _formatDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0").substring(3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(context.w(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_formatDuration(_position), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: context.sp(14))),
              const Spacer(),
              SizedBox(
                width: context.w(64),
                height: context.w(64),
                child: FloatingActionButton(
                  onPressed: () {
                    if (_playerState == PlayerState.playing) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.resume();
                    }
                  },
                  elevation: 4,
                  highlightElevation: 8,
                  child: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _animationController,
                    size: context.w(32),
                  ),
                ),
              ),
              const Spacer(),
              Text(_formatDuration(_duration), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: context.sp(14))),
            ],
          ),
          SizedBox(height: context.w(8)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: context.w(6),
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: context.w(8)),
              overlayShape: RoundSliderOverlayShape(overlayRadius: context.w(16)),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.3),
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              min: 0,
              max: _duration.inSeconds.toDouble(),
              value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
                if (_playerState != PlayerState.playing) {
                  await _audioPlayer.resume();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}