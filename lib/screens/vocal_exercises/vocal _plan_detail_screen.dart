import 'dart:async';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/managers/download_manager.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';

const int continuationReminderId = 200;

class VocalPlanDetailScreen extends StatefulWidget {
  final String planId;
  final String planTitle;
  const VocalPlanDetailScreen(
      {super.key, required this.planId, required this.planTitle});

  @override
  State<VocalPlanDetailScreen> createState() => _VocalPlanDetailScreenState();
}

class _VocalPlanDetailScreenState extends State<VocalPlanDetailScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late ConfettiController _confettiController;
  int _currentPage = 0;
  List<VocalExerciseDay> _days = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final progressProvider =
    Provider.of<VocalProgressProvider>(context, listen: false);
    _currentPage = progressProvider.getLastCompletedDay(widget.planId);
    _pageController = PageController(initialPage: _currentPage);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _cancelContinuationReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _scheduleContinuationReminder();
    } else if (state == AppLifecycleState.resumed) {
      _cancelContinuationReminder();
    }
  }

  Future<void> _scheduleContinuationReminder() async {
    final progressProvider =
    Provider.of<VocalProgressProvider>(context, listen: false);
    final lastCompleted = progressProvider.getLastCompletedDay(widget.planId);
    if (_days.isNotEmpty && lastCompleted < _days.length) {
      await NotificationService.scheduleContinuationReminder(
        id: continuationReminderId,
        title: "You're Doing Great! Don't Stop Now.",
        body:
        "Come back and finish Day ${lastCompleted + 1} to keep your momentum going!",
        delay: const Duration(hours: 1),
      );
    }
  }

  Future<void> _cancelContinuationReminder() async {
    await NotificationService.cancelNotification(continuationReminderId);
  }

  void _onDayCompleted() {
    final dayNumber = _days[_currentPage].dayNumber;
    Provider.of<VocalProgressProvider>(context, listen: false)
        .completeDay(widget.planId, dayNumber);
    _confettiController.play();
    if (_currentPage >= _days.length - 1) {
      _cancelContinuationReminder();
    }
  }

  void _goToNextPage() {
    if (_currentPage < _days.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<VocalProgressProvider>(context);
    final lastCompletedDay = progressProvider.getLastCompletedDay(widget.planId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.planTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [theme.colorScheme.surface, theme.colorScheme.background]
                : [Colors.white, theme.colorScheme.background.withOpacity(0.5)],
          ),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            StreamBuilder<List<VocalExerciseDay>>(
              stream: FirebaseService().getVocalPlanDaysStream(widget.planId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _days.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Exercises coming soon.'));
                }
                _days = snapshot.data!;
                if (_pageController.hasClients &&
                    _pageController.page?.round() != _currentPage) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _currentPage < _days.length) {
                      _pageController.jumpToPage(_currentPage);
                    }
                  });
                }
                return Row(
                  children: [
                    _buildTimeline(_days, lastCompletedDay),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        itemCount: _days.length,
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        itemBuilder: (context, index) {
                          final day = _days[index];
                          return _DayCard(
                            key: ValueKey(day.id),
                            day: day,
                            planId: widget.planId,
                            onCompleted: _onDayCompleted,
                            onNext: _goToNextPage,
                            isLastDay: index == _days.length - 1,
                            isLocked: day.dayNumber > lastCompletedDay + 1,
                            lastCompletedDay: lastCompletedDay,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List<VocalExerciseDay> days, int lastCompletedDay) {
    return Container(
      width: 80,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 56),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isCompleted = Provider.of<VocalProgressProvider>(context,
              listen: false)
              .isDayCompleted(widget.planId, day.dayNumber);
          final isActive = index == _currentPage;
          final isLocked = day.dayNumber > lastCompletedDay + 1;

          return _TimelineNode(
            dayNumber: day.dayNumber,
            isFirst: index == 0,
            isLast: index == days.length - 1,
            isCompleted: isCompleted,
            isActive: isActive,
            isRestDay: day.isRestDay,
            isLocked: isLocked,
            onTap: () {
              if (isLocked) {
                CustomSnackbar.show(context,
                    'Complete Day ${lastCompletedDay + 1} to unlock this exercise.',
                    isError: true);
                return;
              }
              if (_pageController.hasClients) {
                _pageController.animateToPage(index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut);
              }
            },
          );
        },
      ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final VocalExerciseDay day;
  final String planId;
  final VoidCallback onCompleted;
  final VoidCallback onNext;
  final bool isLastDay;
  final bool isLocked;
  final int lastCompletedDay;

  const _DayCard({
    super.key,
    required this.day,
    required this.planId,
    required this.onCompleted,
    required this.onNext,
    required this.isLastDay,
    required this.isLocked,
    required this.lastCompletedDay,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _hasAudioBeenPlayed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return GestureDetector(
        onTap: () => CustomSnackbar.show(context,
            'Complete Day ${widget.lastCompletedDay + 1} to unlock.',
            isError: true),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
              child: _buildContent(context, isDisabled: true),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          ],
        ),
      );
    }
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context, {bool isDisabled = false}) {
    final isCompleted =
    Provider.of<VocalProgressProvider>(context, listen: false)
        .isDayCompleted(widget.planId, widget.day.dayNumber);

    return SafeArea(
      left: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
        child: widget.day.isRestDay
            ? _buildRestDay(context, isDisabled: isDisabled)
            : _buildExerciseDay(context, isCompleted, isDisabled: isDisabled),
      ),
    );
  }

  Widget _buildRestDay(BuildContext context, {bool isDisabled = false}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.self_improvement_rounded,
            size: 100,
            color: isDisabled
                ? theme.disabledColor
                : theme.colorScheme.primary.withOpacity(0.8)),
        const SizedBox(height: 24),
        Text('Day ${widget.day.dayNumber}: Rest Day',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(widget.day.description,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildExerciseDay(BuildContext context, bool isCompleted,
      {bool isDisabled = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Day ${widget.day.dayNumber}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text(widget.day.title,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Divider(height: 32),
        Expanded(
          child: SingleChildScrollView(
            child: Text(widget.day.description,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.day.audioUrl != null)
          AbsorbPointer(
            absorbing: isDisabled,
            child: _AudioPlayerWidget(
                audioUrl: widget.day.audioUrl!,
                key: ValueKey(widget.day.audioUrl),
                onPlaybackComplete: () {
                  if (mounted) {
                    setState(() {
                      _hasAudioBeenPlayed = true;
                    });
                  }
                }),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildActionButton(isCompleted, isDisabled),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(bool isCompleted, bool isDisabled) {
    if (isCompleted && !isDisabled) {
      return FilledButton.tonalIcon(
          key: const ValueKey('next'),
          onPressed: widget.isLastDay ? null : widget.onNext,
          icon: const Icon(Icons.skip_next_rounded),
          label: Text(widget.isLastDay ? 'Plan Complete!' : 'Next Exercise'),
          style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontWeight: FontWeight.bold)));
    }

    if (_hasAudioBeenPlayed && !isDisabled) {
      return FilledButton.icon(
          key: const ValueKey('complete_enabled'),
          onPressed: widget.onCompleted,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Mark as Done'),
          style: FilledButton.styleFrom(
              textStyle:
              const TextStyle(fontWeight: FontWeight.bold)));
    }

    return FilledButton.tonalIcon(
        key: const ValueKey('complete_disabled'),
        onPressed: null,
        icon: const Icon(Icons.play_circle_outline_rounded),
        label: const Text('Do the Exercise First'),
        style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.bold)));
  }
}


class _TimelineNode extends StatelessWidget {
  final int dayNumber;
  final bool isFirst, isLast, isCompleted, isActive, isRestDay, isLocked;
  final VoidCallback onTap;
  const _TimelineNode({
    required this.dayNumber,
    required this.isFirst,
    required this.isLast,
    required this.isCompleted,
    required this.isActive,
    required this.isRestDay,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color nodeColor;
    Color lineColor = theme.dividerColor;
    Widget nodeChild;
    if (isLocked) {
      nodeColor = theme.dividerColor.withOpacity(0.5);
      nodeChild = Icon(Icons.lock, size: 16, color: theme.disabledColor);
    } else if (isCompleted) {
      nodeColor = Colors.green;
      lineColor = Colors.green;
      nodeChild = const Icon(Icons.check, color: Colors.white, size: 18);
    } else if (isActive) {
      nodeColor = theme.colorScheme.primary;
      nodeChild = Text(dayNumber.toString(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold));
    } else {
      nodeColor = theme.dividerColor;
      nodeChild = Text(dayNumber.toString());
    }
    if (isRestDay && !isActive && !isCompleted && !isLocked) {
      nodeChild = Icon(Icons.self_improvement_rounded,
          size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6));
    }
    return SizedBox(
      height: 90,
      child: Column(
        children: [
          Expanded(
              child: Container(
                  width: 3,
                  color: isFirst
                      ? Colors.transparent
                      : (isCompleted ? lineColor : theme.dividerColor))),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 44 : 36,
                height: isActive ? 44 : 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                    border: isActive
                        ? Border.all(
                        color: theme.colorScheme.secondary, width: 3)
                        : null,
                    boxShadow: isActive
                        ? [
                      BoxShadow(
                          color:
                          theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 10)
                    ]
                        : []),
                child: Center(child: nodeChild)),
          ),
          Expanded(
              child: Container(
                  width: 3,
                  color: isLast
                      ? Colors.transparent
                      : (isCompleted ? lineColor : theme.dividerColor))),
        ],
      ),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final VoidCallback onPlaybackComplete;
  const _AudioPlayerWidget({super.key, required this.audioUrl, required this.onPlaybackComplete});
  @override
  State<_AudioPlayerWidget> createState() => __AudioPlayerWidgetState();
}

class __AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerCompleteSubscription;

  String? _localPath;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) => setStateIfMounted(() => _playerState = state));
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) => setStateIfMounted(() => _duration = d));
    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) => setStateIfMounted(() => _position = p));
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      widget.onPlaybackComplete();
    });
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

  void setStateIfMounted(void Function() f) {
    if (mounted) setState(f);
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0").substring(3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _playerState == PlayerState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(_playerState),
                  color: theme.colorScheme.onPrimary,
                  size: 32,
                ),
              ),
              onPressed: () {
                if (_playerState == PlayerState.playing) {
                  _audioPlayer.pause();
                } else {
                  _audioPlayer.resume();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.0,
                    thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14.0),
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble(),
                    value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(position);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position), style: theme.textTheme.labelSmall),
                      Text(_formatDuration(_duration), style: theme.textTheme.labelSmall),
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