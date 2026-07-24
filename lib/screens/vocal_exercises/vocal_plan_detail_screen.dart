import 'dart:async';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mahlete_semay_project/managers/download_manager.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';

const int continuationReminderId = 200;

class VocalPlanDetailScreen extends StatefulWidget {
  final String planId;
  final String planTitle;

  const VocalPlanDetailScreen({
    super.key,
    required this.planId,
    required this.planTitle,
  });

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
        ConfettiController(duration: const Duration(seconds: 2));
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
        title: "Keep Up Your Vocal Progress!",
        body:
            "Return to complete Day ${lastCompleted + 1} and strengthen your voice today!",
        delay: const Duration(hours: 1),
      );
    }
  }

  Future<void> _cancelContinuationReminder() async {
    await NotificationService.cancelNotification(continuationReminderId);
  }

  void _onDayCompleted() {
    if (_currentPage >= _days.length) return;
    HapticFeedback.mediumImpact();
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
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<VocalProgressProvider>(context);
    final lastCompletedDay =
        progressProvider.getLastCompletedDay(widget.planId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: EdgeInsets.only(left: context.w(12)),
          child: IconButton.filledTonal(
            icon: Icon(Icons.arrow_back_rounded, size: context.w(20)),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.w(14))),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          widget.planTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: context.sp(18),
            letterSpacing: -0.3,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface.withOpacity(0.4),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Radial Background Glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.6),
                radius: 1.3,
                colors: isDark
                    ? [
                        theme.colorScheme.primary.withOpacity(0.22),
                        const Color(0xFF090D16),
                      ]
                    : [
                        theme.colorScheme.primary.withOpacity(0.12),
                        theme.colorScheme.surface,
                      ],
              ),
            ),
          ),

          // Secondary Subtle Ambient Accent
          Positioned(
            bottom: -context.w(100),
            left: -context.w(80),
            child: Container(
              width: context.w(300),
              height: context.w(300),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary
                    .withOpacity(isDark ? 0.15 : 0.08),
              ),
            ),
          ),

          // Stream Content
          StreamBuilder<List<VocalExerciseDay>>(
            stream: FirebaseService().getVocalPlanDaysStream(widget.planId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _days.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.w(32)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.w(20)),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.3),
                          ),
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            size: context.w(48),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: context.w(20)),
                        Text(
                          'Exercises coming soon for this plan.',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: context.sp(16),
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
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

              return SafeArea(
                child: Row(
                  children: [
                    _buildTimeline(_days, lastCompletedDay),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
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
                ),
              );
            },
          ),

          // Confetti Celebration
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF6366F1),
                Color(0xFF10B981),
                Color(0xFFF59E0B),
                Color(0xFFEC4899),
                Color(0xFF3B82F6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<VocalExerciseDay> days, int lastCompletedDay) {
    return SizedBox(
      width: context.w(76),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: context.w(16)),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isCompleted =
              Provider.of<VocalProgressProvider>(context, listen: false)
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
              HapticFeedback.selectionClick();
              if (isLocked) {
                CustomSnackbar.show(
                  context,
                  'Complete Day ${lastCompletedDay + 1} to unlock this lesson.',
                  isError: true,
                );
                return;
              }
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                );
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
        onTap: () {
          HapticFeedback.vibrate();
          CustomSnackbar.show(
            context,
            'Complete Day ${widget.lastCompletedDay + 1} to unlock this lesson.',
            isError: true,
          );
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              0, context.w(10), context.w(20), context.w(20)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardContainer(context, isDisabled: true),
              ClipRRect(
                borderRadius: BorderRadius.circular(context.w(28)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.w(20)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.65),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: context.w(36),
                      ),
                    )
                        .animate()
                        .scale(curve: Curves.easeOutBack, duration: 400.ms),
                    SizedBox(height: context.w(14)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(16),
                        vertical: context.w(8),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(context.w(20)),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        "Locked Lesson",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding:
          EdgeInsets.fromLTRB(0, context.w(10), context.w(20), context.w(20)),
      child: _buildCardContainer(context),
    );
  }

  Widget _buildCardContainer(BuildContext context, {bool isDisabled = false}) {
    final theme = Theme.of(context);
    final isCompleted =
        Provider.of<VocalProgressProvider>(context, listen: false)
            .isDayCompleted(widget.planId, widget.day.dayNumber);

    return Container(
      padding: EdgeInsets.all(context.w(22)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.75),
        borderRadius: BorderRadius.circular(context.w(28)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: widget.day.isRestDay
          ? _buildRestDay(context, isDisabled: isDisabled)
          : _buildExerciseDay(context, isCompleted, isDisabled: isDisabled),
    );
  }

  Widget _buildRestDay(BuildContext context, {bool isDisabled = false}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(context.w(28)),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Icon(
            Icons.self_improvement_rounded,
            size: context.w(68),
            color: isDisabled ? theme.disabledColor : theme.colorScheme.primary,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        SizedBox(height: context.w(24)),
        Text(
          'Day ${widget.day.dayNumber}: Vocal Rest',
          style: GoogleFonts.poppins(
            fontSize: context.sp(22),
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: context.w(12)),
        Text(
          widget.day.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.6,
            fontSize: context.sp(14),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExerciseDay(BuildContext context, bool isCompleted,
      {bool isDisabled = false}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.w(12),
                vertical: context.w(6),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(context.w(16)),
              ),
              child: Text(
                'DAY ${widget.day.dayNumber}',
                style: GoogleFonts.poppins(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  fontSize: context.sp(11),
                ),
              ),
            ),
            if (isCompleted)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(10),
                  vertical: context.w(4),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.w(16)),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: const Color(0xFF10B981), size: context.w(16)),
                    SizedBox(width: context.w(4)),
                    Text(
                      'Completed',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: context.sp(11),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: context.w(12)),
        Text(
          widget.day.title,
          style: GoogleFonts.poppins(
            fontSize: context.sp(20),
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: context.w(10)),
        Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        SizedBox(height: context.w(6)),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              widget.day.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
                fontSize: context.sp(14),
              ),
            ),
          ),
        ),
        SizedBox(height: context.w(14)),
        if (widget.day.audioUrl != null)
          AbsorbPointer(
            absorbing: isDisabled,
            child: _ModernAudioPlayer(
              audioUrl: widget.day.audioUrl!,
              key: ValueKey(widget.day.audioUrl),
              onPlaybackComplete: () {
                if (mounted) {
                  setState(() {
                    _hasAudioBeenPlayed = true;
                  });
                }
              },
            ),
          ),
        SizedBox(height: context.w(16)),
        SizedBox(
          width: double.infinity,
          height: context.w(52),
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
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: FilledButton.tonalIcon(
          key: const ValueKey('next'),
          onPressed: widget.isLastDay ? null : widget.onNext,
          icon: Icon(Icons.skip_next_rounded, size: context.w(22)),
          label: Text(widget.isLastDay ? 'Plan Complete!' : 'Next Exercise'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.w(18))),
            textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: context.sp(15)),
          ),
        ),
      );
    }

    if ((_hasAudioBeenPlayed || widget.day.audioUrl == null) && !isDisabled) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('complete_enabled'),
          onPressed: widget.onCompleted,
          icon: Icon(Icons.check_circle_rounded, size: context.w(22)),
          label: const Text('Mark as Done'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF10B981).withOpacity(0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.w(18))),
            textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: context.sp(15)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FilledButton.tonalIcon(
        key: const ValueKey('complete_disabled'),
        onPressed: null,
        icon: Icon(Icons.play_circle_outline_rounded, size: context.w(22)),
        label: const Text('Listen to Exercise First'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.w(18))),
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: context.sp(14)),
        ),
      ),
    );
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
    Color lineColor = const Color(0xFF10B981);
    Widget nodeChild;

    if (isLocked) {
      nodeColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.6);
      nodeChild = Icon(Icons.lock_rounded,
          size: context.w(14),
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5));
    } else if (isCompleted) {
      nodeColor = const Color(0xFF10B981);
      nodeChild =
          Icon(Icons.check_rounded, color: Colors.white, size: context.w(18));
    } else if (isActive) {
      nodeColor = theme.colorScheme.primary;
      nodeChild = Text(
        dayNumber.toString(),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: context.sp(14),
        ),
      );
    } else {
      nodeColor = theme.colorScheme.surfaceContainerHigh;
      nodeChild = Text(
        dayNumber.toString(),
        style: GoogleFonts.poppins(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: context.sp(13),
        ),
      );
    }

    if (isRestDay && !isActive && !isCompleted && !isLocked) {
      nodeChild = Icon(
        Icons.self_improvement_rounded,
        size: context.w(16),
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    return SizedBox(
      height: context.w(86),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: isFirst
                    ? Colors.transparent
                    : (isCompleted
                        ? lineColor
                        : theme.colorScheme.outlineVariant.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(context.w(24)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isActive ? context.w(44) : context.w(36),
              height: isActive ? context.w(44) : context.w(36),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nodeColor,
                border: isActive
                    ? Border.all(color: theme.colorScheme.surface, width: 3)
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.45),
                          blurRadius: 14,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: Center(child: nodeChild),
            ),
          ),
          Expanded(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: isLast
                    ? Colors.transparent
                    : (isCompleted
                        ? lineColor
                        : theme.colorScheme.outlineVariant.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(2),
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
  final VoidCallback onPlaybackComplete;

  const _ModernAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.onPlaybackComplete,
  });

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
  StreamSubscription? _playerCompleteSubscription;

  late AnimationController _animController;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
      if (state == PlayerState.playing) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged
        .listen((d) => setStateIfMounted(() => _duration = d));
    _positionSubscription = _audioPlayer.onPositionChanged
        .listen((p) => setStateIfMounted(() => _position = p));
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
    _animController.dispose();
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
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(context.w(22)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Audio Dynamic Waveform Equalizer
          SizedBox(
            height: context.w(28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(24, (index) {
                final height = isPlaying
                    ? context.w(6 + (16.0 * (1.0 + (index % 5 - 2) * 0.25)))
                    : context.w(5);

                return AnimatedContainer(
                  duration: Duration(milliseconds: 180 + (index % 4) * 60),
                  width: context.w(3.5),
                  height: height,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(context.w(4)),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: context.w(8)),

          // Slider Timeline
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: context.w(4),
              thumbShape:
                  RoundSliderThumbShape(enabledThumbRadius: context.w(6)),
              overlayShape:
                  RoundSliderOverlayShape(overlayRadius: context.w(12)),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.15),
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.w(10)),

          // Player Control Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed Chip
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(context.w(12)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(10),
                    vertical: context.w(6),
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
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

              // Play / Pause Central Fab
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_playerState == PlayerState.playing) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.resume();
                  }
                },
                child: Container(
                  width: context.w(52),
                  height: context.w(52),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: AnimatedIcon(
                      icon: AnimatedIcons.play_pause,
                      progress: _animController,
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

              // Offline Sync Indicator
              Icon(
                _localPath != null
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_download_outlined,
                size: context.w(20),
                color: _localPath != null
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
