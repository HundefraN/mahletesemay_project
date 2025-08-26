import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/vocal_exercises/vocal%20_plan_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'gender_selection_screen.dart';

class VocalExerciseListScreen extends StatelessWidget {
  const VocalExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progressProvider = Provider.of<VocalProgressProvider>(context);
    final firebaseService = FirebaseService();
    final theme = Theme.of(context);

    if (progressProvider.gender == null) {
      return const GenderSelectionScreen();
    }

    final genderPrefix = progressProvider.gender!.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vocalTraining), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.structuredPlans,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPlanCard(
            context,
            title: l10n.dailyWarmUp,
            subtitle: l10n.dailyWarmUpDesc,
            planId: '${genderPrefix}_daily',
          ),
          _buildPlanCard(
            context,
            title: l10n.weeklyWorkout,
            subtitle: l10n.weeklyWorkoutDesc,
            planId: '${genderPrefix}_weekly',
          ),
          _buildPlanCard(
            context,
            title: l10n.monthlyChallenge,
            subtitle: l10n.monthlyChallengeDesc,
            planId: '${genderPrefix}_monthly',
          ),
          _buildPlanCard(
            context,
            title: l10n.threeMonthTransformation,
            subtitle: l10n.threeMonthTransformationDesc,
            planId: '${genderPrefix}_quarterly',
          ),
          const Divider(height: 40),
          Text(
            l10n.generalExercises,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildGeneralExercisesList(context, firebaseService),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String planId,
      }) {
    final theme = Theme.of(context);
    final firebaseService = FirebaseService();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VocalPlanDetailScreen(planId: planId, planTitle: title),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              StreamBuilder(
                stream: firebaseService.getVocalPlanDaysStream(planId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final totalDays = snapshot.data!.length;
                  final completedDays =
                      Provider.of<VocalProgressProvider>(
                        context,
                      ).progress[planId]?.length ??
                          0;
                  final progress = totalDays > 0
                      ? completedDays / totalDays
                      : 0.0;
                  return Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$completedDays / $totalDays',
                        style: theme.textTheme.labelLarge,
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
  }

  Widget _buildGeneralExercisesList(
      BuildContext context,
      FirebaseService firebaseService,
      ) {
    return StreamBuilder<List<VocalExerciseDay>>(
      stream: firebaseService.getGeneralExercisesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTileShimmer();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No general exercises available yet.'),
            ),
          );
        }
        final exercises = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                title: Text(
                  exercise.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.6,
                      maxChildSize: 0.9,
                      builder: (context, scrollController) {
                        return _ExerciseDetailSheet(
                          exercise: exercise,
                          scrollController: scrollController,
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  final VocalExerciseDay exercise;
  final ScrollController scrollController;
  const _ExerciseDetailSheet({
    required this.exercise,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            exercise.title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 32),
          Text(
            exercise.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          if (exercise.audioUrl != null)
            _AudioPlayerWidget(
              audioUrl: exercise.audioUrl!,
              key: ValueKey(exercise.audioUrl),
            ),
        ],
      ),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const _AudioPlayerWidget({super.key, required this.audioUrl});
  @override
  State<_AudioPlayerWidget> createState() => __AudioPlayerWidgetState();
}

class __AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription,
      _positionSubscription,
      _playerStateSubscription;
  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen(
          (state) => setStateIfMounted(() => _playerState = state),
    );
    _durationSubscription = _audioPlayer.onDurationChanged.listen(
          (d) => setStateIfMounted(() => _duration = d),
    );
    _positionSubscription = _audioPlayer.onPositionChanged.listen(
          (p) => setStateIfMounted(() => _position = p),
    );
    _audioPlayer.setSourceUrl(widget.audioUrl);
  }

  void setStateIfMounted(void Function() f) {
    if (mounted) setState(f);
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) =>
      d.toString().split('.').first.padLeft(8, "0").substring(3);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _playerState == PlayerState.playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                key: ValueKey(_playerState),
              ),
            ),
            iconSize: 48,
            color: theme.colorScheme.primary,
            onPressed: () {
              if (_playerState == PlayerState.playing)
                _audioPlayer.pause();
              else
                _audioPlayer.resume();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16.0,
                    ),
                    trackHeight: 4.0,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble(),
                    value: _position.inSeconds.toDouble().clamp(
                      0,
                      _duration.inSeconds.toDouble(),
                    ),
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(position);
                      if (_playerState != PlayerState.playing)
                        await _audioPlayer.resume();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position)),
                      Text(_formatDuration(_duration)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}