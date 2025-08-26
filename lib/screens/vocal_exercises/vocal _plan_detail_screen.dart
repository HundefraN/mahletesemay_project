import 'dart:async';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
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
  const VocalPlanDetailScreen({super.key, required this.planId, required this.planTitle});

  @override
  State<VocalPlanDetailScreen> createState() => _VocalPlanDetailScreenState();
}

class _VocalPlanDetailScreenState extends State<VocalPlanDetailScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  late ConfettiController _confettiController;
  int _currentPage = 0;
  List<VocalExerciseDay> _days = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final progressProvider = Provider.of<VocalProgressProvider>(context, listen: false);
    _currentPage = progressProvider.getLastCompletedDay(widget.planId);
    _pageController = PageController(initialPage: _currentPage);
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _scheduleContinuationReminder();
    } else if (state == AppLifecycleState.resumed) {
      _cancelContinuationReminder();
    }
  }

  Future<void> _scheduleContinuationReminder() async {
    final progressProvider = Provider.of<VocalProgressProvider>(context, listen: false);
    final lastCompleted = progressProvider.getLastCompletedDay(widget.planId);
    final totalDays = _days.length;

    if (totalDays > 0 && lastCompleted < totalDays) {
      await NotificationService.scheduleContinuationReminder(
        id: continuationReminderId,
        title: "You're Doing Great! Don't Stop Now.",
        body: "Come back and finish Day ${lastCompleted + 1} to keep your momentum going!",
        delay: const Duration(hours: 1),
      );
    }
  }

  Future<void> _cancelContinuationReminder() async {
    await NotificationService.cancelNotification(continuationReminderId);
  }

  void _onDayCompleted() {
    final dayNumber = _days[_currentPage].dayNumber;
    Provider.of<VocalProgressProvider>(context, listen: false).completeDay(widget.planId, dayNumber);
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

  Future<void> _showStartNextDayDialog(int pageIndex) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start Day ${_days[pageIndex].dayNumber}?'),
        content: const Text('You have completed the previous workout. Are you ready to move on to the next day?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not Yet')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Let\'s Go!')),
        ],
      ),
    );
    if (result == true && mounted) {
      _pageController.animateToPage(pageIndex, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<VocalProgressProvider>(context);
    final lastCompletedDay = progressProvider.getLastCompletedDay(widget.planId);

    return Scaffold(
      appBar: AppBar(title: Text(widget.planTitle)),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          StreamBuilder<List<VocalExerciseDay>>(
            stream: FirebaseService().getVocalPlanDaysStream(widget.planId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _days.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Exercises for this plan are coming soon.'));
              }
              _days = snapshot.data!;

              if (_pageController.hasClients && _pageController.page?.round() != _currentPage) {
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
                      onPageChanged: (page) => setState(() => _currentPage = page),
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
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<VocalExerciseDay> days, int lastCompletedDay) {
    return Container(
      width: 60,
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isCompleted = Provider.of<VocalProgressProvider>(context, listen: false).isDayCompleted(widget.planId, day.dayNumber);
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
                CustomSnackbar.show(context, 'Please complete Day ${lastCompletedDay + 1} to unlock this exercise.', isError: true);
                return;
              }
              if (!isActive && day.dayNumber == lastCompletedDay + 1) {
                _showStartNextDayDialog(index);
              } else {
                if (_pageController.hasClients) {
                  _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                }
              }
            },
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final VocalExerciseDay day;
  final String planId;
  final VoidCallback onCompleted;
  final VoidCallback onNext;
  final bool isLastDay;
  final bool isLocked;
  final int lastCompletedDay;

  const _DayCard({super.key, required this.day, required this.planId, required this.onCompleted, required this.onNext, required this.isLastDay, required this.isLocked, required this.lastCompletedDay});

  Widget _buildContent(BuildContext context, {bool isDisabled = false}) {
    final theme = Theme.of(context);
    final isCompleted = Provider.of<VocalProgressProvider>(context).isDayCompleted(planId, day.dayNumber);
    final disabledColor = Colors.grey.shade500;
    final primaryColor = theme.colorScheme.primary;
    if (day.isRestDay) {
      return Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.self_improvement_rounded, size: 80, color: isDisabled ? disabledColor : primaryColor), const SizedBox(height: 24), Text('Day ${day.dayNumber}: Rest Day', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: isDisabled ? disabledColor : null)), const SizedBox(height: 16), Text(day.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: isDisabled ? disabledColor : null), textAlign: TextAlign.center)]));
    }
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Day ${day.dayNumber}', style: theme.textTheme.titleMedium?.copyWith(color: isDisabled ? disabledColor : primaryColor, fontWeight: FontWeight.bold)),
          Text(day.title, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: isDisabled ? disabledColor : null)),
          const Divider(height: 32),
          Expanded(child: SingleChildScrollView(child: Text(day.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 18, color: isDisabled ? disabledColor : null)))),
          const SizedBox(height: 20),
          if (day.audioUrl != null) AbsorbPointer(absorbing: isDisabled, child: _AudioPlayerWidget(audioUrl: day.audioUrl!, key: ValueKey(day.audioUrl), isDisabled: isDisabled)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isCompleted
                  ? ElevatedButton.icon(key: const ValueKey('next'), onPressed: isLastDay ? null : onNext, icon: const Icon(Icons.arrow_forward), label: const Text('Next Exercise'))
                  : ElevatedButton.icon(key: const ValueKey('complete'), onPressed: isDisabled ? null : onCompleted, icon: const Icon(Icons.check_circle_outline), label: const Text('Mark as Done')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return Stack(
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: _buildContent(context, isDisabled: true),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                CustomSnackbar.show(context, 'Please complete Day ${lastCompletedDay + 1} to unlock this exercise.', isError: true);
              },
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
        ],
      );
    }
    return _buildContent(context);
  }
}

class _TimelineNode extends StatelessWidget {
  final int dayNumber;
  final bool isFirst, isLast, isCompleted, isActive, isRestDay, isLocked;
  final VoidCallback onTap;
  const _TimelineNode({required this.dayNumber, required this.isFirst, required this.isLast, required this.isCompleted, required this.isActive, required this.isRestDay, required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color nodeColor;
    Widget nodeChild;
    if (isLocked) {
      nodeColor = Colors.grey.shade200;
      nodeChild = Icon(Icons.lock, size: 16, color: Colors.grey.shade500);
    } else if (isCompleted) {
      nodeColor = Colors.green;
      nodeChild = const Icon(Icons.check, color: Colors.white, size: 18);
    } else if (isActive) {
      nodeColor = theme.colorScheme.primary;
      nodeChild = Text(dayNumber.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
    } else {
      nodeColor = Colors.grey.shade300;
      nodeChild = Text(dayNumber.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold));
    }
    if (isRestDay && !isActive && !isCompleted && !isLocked) nodeChild = Icon(Icons.self_improvement_rounded, size: 16, color: Colors.grey.shade600);
    return SizedBox(height: 80, child: Column(children: [Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : Colors.grey.shade300)), GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 300), curve: Curves.bounceOut, width: isActive ? 44 : 32, height: isActive ? 44 : 32, decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor, border: isActive ? Border.all(color: theme.colorScheme.secondary, width: 3) : null, boxShadow: isActive ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)] : []), child: Center(child: nodeChild))), Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : Colors.grey.shade300))]));
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isDisabled;
  const _AudioPlayerWidget({super.key, required this.audioUrl, this.isDisabled = false});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription, _positionSubscription, _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    if (!widget.isDisabled) {
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) => setStateIfMounted(() => _playerState = state));
      _durationSubscription = _audioPlayer.onDurationChanged.listen((d) => setStateIfMounted(() => _duration = d));
      _positionSubscription = _audioPlayer.onPositionChanged.listen((p) => setStateIfMounted(() => _position = p));
      _audioPlayer.setSourceUrl(widget.audioUrl);
    }
  }

  void setStateIfMounted(void Function() f) { if (mounted) setState(f); }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0").substring(3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = Colors.grey.shade400;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: widget.isDisabled ? theme.colorScheme.surface.withOpacity(0.5) : theme.colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          IconButton(icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Icon(_playerState == PlayerState.playing && !widget.isDisabled ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, key: ValueKey(_playerState))), iconSize: 48, color: widget.isDisabled ? disabledColor : primaryColor, onPressed: widget.isDisabled ? null : () { if (_playerState == PlayerState.playing) _audioPlayer.pause(); else _audioPlayer.resume(); }),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0), trackHeight: 4.0, activeTrackColor: widget.isDisabled ? disabledColor : primaryColor, inactiveTrackColor: widget.isDisabled ? disabledColor.withOpacity(0.3) : primaryColor.withOpacity(0.3), thumbColor: widget.isDisabled ? disabledColor : primaryColor, disabledThumbColor: disabledColor), child: Slider(min: 0, max: _duration.inSeconds.toDouble(), value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()), onChanged: widget.isDisabled ? null : (value) async { final position = Duration(seconds: value.toInt()); await _audioPlayer.seek(position); if (_playerState != PlayerState.playing) await _audioPlayer.resume(); })),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatDuration(_position), style: TextStyle(color: widget.isDisabled ? disabledColor : null)), Text(_formatDuration(_duration), style: TextStyle(color: widget.isDisabled ? disabledColor : null))])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}