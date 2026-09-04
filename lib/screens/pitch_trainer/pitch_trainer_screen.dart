import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mahlete_semay_project/services/pitch_service.dart';
import 'package:mahlete_semay_project/utils/generated_tones.dart';
import 'package:mahlete_semay_project/utils/permission_helper.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/audio_waveform_visualizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:mahlete_semay_project/widgets/vocal_piano_roll.dart';
import 'package:mahlete_semay_project/widgets/web_content_wrapper.dart';

enum TrainerState { idle, playing, listening, finished }

class PitchPoint {
  final double cents;
  final double pitch;
  final bool hasPitch;
  final DateTime time;
  PitchPoint({required this.cents, required this.pitch, required this.hasPitch, required this.time});
}

class PitchTrainerScreen extends StatefulWidget {
  const PitchTrainerScreen({super.key});

  @override
  State<PitchTrainerScreen> createState() => _PitchTrainerScreenState();
}

class _PitchTrainerScreenState extends State<PitchTrainerScreen>
    with TickerProviderStateMixin {
  late final PitchService _pitchService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final ConfettiController _confettiController;

  TrainerState _state = TrainerState.idle;
  final List<String> _targetNotes = [
    'C3', 'D3', 'E3', 'F3', 'G3', 'A3', 'B3',
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4',
    'C5', 'D5', 'E5', 'G5'
  ];
  int _currentNoteIndex = 7; // Default to C4
  String get _targetNote => _targetNotes[_currentNoteIndex];

  bool _autoTransposeOctaves = true;
  double _centsDifference = 0.0;
  String _effectiveSungNote = '';
  int _detectedOctaveOffset = 0;

  Timer? _inTuneTimer;
  double _inTuneProgress = 0.0;
  int _streakCount = 0;

  final List<PitchPoint> _pitchFlowHistory = [];
  static const int _maxPitchHistory = 120;

  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pitchService = Provider.of<PitchService>(context, listen: false);
    _pitchService.addListener(_onPitchChanged);

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && _state == TrainerState.playing) {
        _startListeningForMatch();
      }
    });
  }

  @override
  void dispose() {
    _pitchService.removeListener(_onPitchChanged);
    if (_state == TrainerState.listening) {
      _pitchService.stopListening();
    }
    _audioPlayer.dispose();
    _inTuneTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onPitchChanged() {
    if (!mounted || _state != TrainerState.listening) return;

    final pitchData = _pitchService.pitchData;
    if (pitchData.pitch <= 0.0) {
      _addPitchPoint(0.0, 0.0, false);
      if (_centsDifference != 0.0) {
        setState(() {
          _centsDifference = 0.0;
          _effectiveSungNote = '';
          _detectedOctaveOffset = 0;
        });
      }
      return;
    }

    final targetPitch = _pitchService.getPitchFromNote(_targetNote);
    double cents = 0.0;
    int octaveOffset = 0;

    if (_autoTransposeOctaves) {
      // Auto-transpose to comfortable singer octave
      cents = _pitchService.getOctaveWrappedCentsDifference(targetPitch, pitchData.pitch);
      final rawCents = _pitchService.getCentsDifference(targetPitch, pitchData.pitch);
      octaveOffset = ((rawCents - cents) / 1200.0).round();
    } else {
      // Exact octave required
      cents = _pitchService.getCentsDifference(targetPitch, pitchData.pitch);
      octaveOffset = 0;
    }

    _addPitchPoint(cents, pitchData.pitch, true);

    setState(() {
      _centsDifference = cents;
      _effectiveSungNote = pitchData.note;
      _detectedOctaveOffset = octaveOffset;
    });

    // Pitch match accuracy tolerance: +-20 cents for natural vocal vibrato
    if (cents.abs() <= 20) {
      if (_inTuneTimer == null || !_inTuneTimer!.isActive) {
        _inTuneTimer =
            Timer.periodic(const Duration(milliseconds: 35), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _inTuneProgress = (_inTuneProgress + 0.035).clamp(0.0, 1.0);
          });

          if (_inTuneProgress >= 1.0) {
            _finishPractice();
          }
        });
      }
    } else {
      _inTuneTimer?.cancel();
      if (mounted && _inTuneProgress > 0) {
        setState(() {
          _inTuneProgress = (_inTuneProgress - 0.045).clamp(0.0, 1.0);
        });
      }
    }
  }

  void _addPitchPoint(double cents, double pitch, bool hasPitch) {
    _pitchFlowHistory.add(PitchPoint(
      cents: cents,
      pitch: pitch,
      hasPitch: hasPitch,
      time: DateTime.now(),
    ));
    if (_pitchFlowHistory.length > _maxPitchHistory) {
      _pitchFlowHistory.removeAt(0);
    }
  }

  void _startPractice() async {
    _reset(keepState: true);
    _pitchFlowHistory.clear();
    setState(() => _state = TrainerState.playing);
    _pulseController.repeat(reverse: true);

    final toneData = GeneratedTones.getTone(_targetNote);
    if (toneData != null) {
      try {
        await _audioPlayer.play(BytesSource(toneData));
      } catch (e) {
        debugPrint("PitchTrainer: Audio player error: $e");
        _startListeningForMatch();
      }
    } else {
      _startListeningForMatch();
    }
  }

  void _playReferenceToneOnly() async {
    final toneData = GeneratedTones.getTone(_targetNote);
    if (toneData != null) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(toneData));
      } catch (e) {
        debugPrint("PitchTrainer: Reference tone error: $e");
      }
    }
  }

  void _startListeningForMatch() async {
    final hasMicPermission = await PermissionHelper.requestMicrophone(context);
    if (!hasMicPermission) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Microphone permission is required for pitch training.',
          isError: true,
        );
        _reset();
      }
      return;
    }

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    setState(() => _state = TrainerState.listening);
    final started = await _pitchService.startListening();
    if (!started && mounted) {
      CustomSnackbar.show(
        context,
        'Unable to initialize microphone stream.',
        isError: true,
      );
      _reset();
    }
  }

  void _finishPractice() {
    _inTuneTimer?.cancel();
    _pitchService.stopListening();
    _pulseController.stop();
    _confettiController.play();
    _pitchService.playSuccessBeep();
    if (mounted) {
      setState(() {
        _state = TrainerState.finished;
        _streakCount += 1;
      });
    }
  }

  void _reset({bool keepState = false}) {
    _inTuneTimer?.cancel();
    _pitchService.stopListening();
    _audioPlayer.stop();
    _pulseController.stop();
    if (mounted) {
      setState(() {
        if (!keepState) _state = TrainerState.idle;
        _centsDifference = 0;
        _inTuneProgress = 0;
        _effectiveSungNote = '';
        _detectedOctaveOffset = 0;
      });
    }
  }

  void _selectNote(int index) {
    if (_state == TrainerState.idle) {
      setState(() {
        _currentNoteIndex = index;
        _pitchFlowHistory.clear();
      });
      _playReferenceToneOnly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final targetPitch = _pitchService.getPitchFromNote(_targetNote);
    final detectedPitch = _pitchService.pitchData.pitch;
    final detectedNote = _pitchService.pitchData.note;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pitch Trainer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: context.sp(20),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_streakCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_streakCount',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: WebContentWrapper(
              maxWidth: 750,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.w(18),
                          vertical: context.w(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Status Card Banner
                            _buildHeaderStatusCard(theme, isDark),
                            SizedBox(height: context.w(14)),

                            // Target Note Card & Octave Controls
                            _buildTargetNoteSelector(
                              theme,
                              targetPitch: targetPitch,
                              detectedPitch: detectedPitch,
                              detectedNote: detectedNote,
                            ),
                            SizedBox(height: context.w(14)),

                            // Real-time Pitch Flow Roll (Yousician Style)
                            _buildLivePitchFlowCard(theme, isDark),
                            SizedBox(height: context.w(14)),

                            // Interactive Cents Arc Gauge Visualizer
                            _buildVisualizerGaugeCard(theme, isDark),
                            SizedBox(height: context.w(14)),

                            // Vocal Piano Roll Live Keyboard Feedback
                            VocalPianoRoll(
                              lowestNote: null,
                              highestNote: null,
                              currentNote: _state == TrainerState.listening &&
                                      detectedNote.isNotEmpty
                                  ? detectedNote
                                  : _targetNote,
                            ),
                            SizedBox(height: context.w(14)),

                            // Note Selector Carousel Chips
                            _buildNoteChipsPicker(theme),

                            SizedBox(height: context.w(20)),

                            // Main Control Action Button
                            SizedBox(height: context.w(16)),
                            _buildMainActionButton(theme),
                            SizedBox(height: context.w(12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

          // Confetti Particle Explosion on Bullseye Match
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.amber,
              Colors.blue,
              Colors.purple,
              Colors.pink,
            ],
          ),
        ],
      ),
    );
  }

  /// Top Status Banner Card
  Widget _buildHeaderStatusCard(ThemeData theme, bool isDark) {
    String text;
    String subtext;
    IconData icon;
    Color accentColor;

    switch (_state) {
      case TrainerState.playing:
        text = 'Listen Closely...';
        subtext = 'Playing reference audio note';
        icon = Icons.volume_up_rounded;
        accentColor = Colors.blueAccent;
        break;
      case TrainerState.listening:
        text = 'Sing into Microphone';
        subtext = _detectedOctaveOffset != 0
            ? 'Singing in Octave with pitch transposition'
            : 'Adjust your voice pitch to match target';
        icon = Icons.mic_rounded;
        accentColor = Colors.amber.shade700;
        break;
      case TrainerState.finished:
        text = 'Excellent! Perfect Pitch!';
        subtext = 'You held the pitch steady in tune!';
        icon = Icons.workspace_premium_rounded;
        accentColor = const Color(0xFF10B981);
        break;
      case TrainerState.idle:
      default:
        text = 'Pitch Match Trainer';
        subtext = 'Select a note, tap Start, and match reference pitch';
        icon = Icons.graphic_eq_rounded;
        accentColor = theme.colorScheme.primary;
        break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _state == TrainerState.listening ||
                      _state == TrainerState.playing
                  ? 1.0 + (_pulseController.value * 0.15)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  /// Big Display Target Note with Next/Previous Controls & Octave Transposition Toggle
  Widget _buildTargetNoteSelector(
    ThemeData theme, {
    required double targetPitch,
    required double detectedPitch,
    required String detectedNote,
  }) {
    final canChange = _state == TrainerState.idle;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: canChange && _currentNoteIndex > 0
                    ? () => _selectNote(_currentNoteIndex - 1)
                    : null,
              ),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TARGET NOTE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _playReferenceToneOnly,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.volume_up_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _targetNote,
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${targetPitch.toStringAsFixed(1)} Hz',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed:
                    canChange && _currentNoteIndex < _targetNotes.length - 1
                        ? () => _selectNote(_currentNoteIndex + 1)
                        : null,
              ),
            ],
          ),

          // Transposition Mode & Metric column
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => _autoTransposeOctaves = !_autoTransposeOctaves);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _autoTransposeOctaves
                            ? Icons.tune_rounded
                            : Icons.lock_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _autoTransposeOctaves ? 'Any Octave (Auto)' : 'Exact Octave',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_state == TrainerState.listening && detectedPitch > 0)
                Text(
                  _detectedOctaveOffset == 0
                      ? 'Exact Octave Match'
                      : 'Octave ${_detectedOctaveOffset > 0 ? "+$_detectedOctaveOffset" : "$_detectedOctaveOffset"} Match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Live Scrolling Vocal Pitch Flow & Real-Time Audio Frequency Waveform Visualizer
  Widget _buildLivePitchFlowCard(ThemeData theme, bool isDark) {
    final pitchData = _pitchService.pitchData;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'REAL-TIME PITCH & AUDIO WAVE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_state == TrainerState.listening
                            ? Colors.green
                            : Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _state == TrainerState.listening
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _state == TrainerState.listening ? 'LIVE MIC' : 'STANDBY',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _state == TrainerState.listening
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Real Live Audio PCM Waveform Visualizer
            AudioWaveformVisualizer(
              waveform: pitchData.waveform,
              rms: pitchData.rms,
              pitch: pitchData.pitch,
              isListening: _state == TrainerState.listening,
              height: 48.0,
              primaryColor: theme.colorScheme.primary,
              secondaryColor: const Color(0xFF00E676),
            ),
            const SizedBox(height: 8),

            // Continuous Scrolling Vocal Pitch Corridor
            SizedBox(
              height: 105,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _PitchFlowPainter(
                    history: _pitchFlowHistory,
                    isListening: _state == TrainerState.listening,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Precision Gauge Card displaying Cents, Arc Needle, and Hold Progress
  Widget _buildVisualizerGaugeCard(ThemeData theme, bool isDark) {
    final absCents = _centsDifference.abs();
    final isInTune = absCents <= 20 && _state == TrainerState.listening;

    String hintMessage = 'READY';
    Color hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    if (_state == TrainerState.listening) {
      if (_pitchService.pitchData.pitch <= 0) {
        hintMessage = 'SING NOW...';
        hintColor = Colors.amber.shade700;
      } else if (isInTune) {
        hintMessage = 'PERFECT! HOLD PITCH...';
        hintColor = Colors.green;
      } else if (_centsDifference < 0) {
        hintMessage = 'PITCH FLAT (TOO LOW) ↑';
        hintColor = Colors.orange;
      } else {
        hintMessage = 'PITCH SHARP (TOO HIGH) ↓';
        hintColor = Colors.orange;
      }
    } else if (_state == TrainerState.finished) {
      hintMessage = 'MATCH COMPLETED!';
      hintColor = Colors.green;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          children: [
            // Status Feedback Tag
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: hintColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                hintMessage,
                style: TextStyle(
                  color: hintColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Canvas Dynamic Meter Painter
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: _GaugeVisualizerPainter(
                  centsDifference: _centsDifference,
                  inTuneProgress: _inTuneProgress,
                  state: _state,
                  theme: theme,
                  waveAnimationValue: _waveController.value,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Cents Off Readout
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _state == TrainerState.listening &&
                          _pitchService.pitchData.pitch > 0
                      ? '${_centsDifference > 0 ? "+" : ""}${_centsDifference.toStringAsFixed(1)}'
                      : '0.0',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                        isInTune ? Colors.green : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'cents',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hold Pitch Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pitch Hold Progress',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${(_inTuneProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _inTuneProgress >= 1.0
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _inTuneProgress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _inTuneProgress >= 1.0 ? Colors.green : Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Note Selection Chips Scrollbar Carousel
  Widget _buildNoteChipsPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            'SELECT PRACTICE NOTE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(_targetNotes.length, (index) {
              final note = _targetNotes[index];
              final isSelected = index == _currentNoteIndex;
              final isEnabled = _state == TrainerState.idle;

              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(note),
                  selected: isSelected,
                  onSelected: isEnabled ? (_) => _selectNote(index) : null,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Primary Bottom Action Button
  Widget _buildMainActionButton(ThemeData theme) {
    String text;
    IconData icon;
    VoidCallback? onPressed;
    Color buttonColor;

    switch (_state) {
      case TrainerState.idle:
        text = 'Start Pitch Practice';
        icon = Icons.play_arrow_rounded;
        onPressed = _startPractice;
        buttonColor = theme.colorScheme.primary;
        break;
      case TrainerState.playing:
      case TrainerState.listening:
        text = 'Stop Practice';
        icon = Icons.stop_rounded;
        onPressed = _reset;
        buttonColor = Colors.redAccent;
        break;
      case TrainerState.finished:
        text = 'Practice Next Note';
        icon = Icons.refresh_rounded;
        onPressed = () {
          _reset();
          if (_currentNoteIndex < _targetNotes.length - 1) {
            _selectNote(_currentNoteIndex + 1);
          }
        };
        buttonColor = Colors.green;
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: buttonColor.withValues(alpha: 0.4),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

/// Real-Time Scrolling Vocal Pitch Curve Painter (Yousician Flow Style)
class _PitchFlowPainter extends CustomPainter {
  final List<PitchPoint> history;
  final bool isListening;
  final bool isDark;

  _PitchFlowPainter({
    required this.history,
    required this.isListening,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F131D) : const Color(0xFFF1F4F9);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final midY = size.height / 2;

    // In-tune target corridor (corresponds to +-20 cents)
    final corridorHalfHeight = (20 / 50.0) * (size.height / 2);
    final targetCorridorPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(0, midY - corridorHalfHeight, size.width, midY + corridorHalfHeight),
      targetCorridorPaint,
    );

    // Target Center Line
    final centerLinePaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centerLinePaint);

    if (history.isEmpty) return;

    // Draw user pitch curve
    final path = Path();
    final pointCount = history.length;
    final stepX = size.width / 120.0;
    bool hasStarted = false;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.8)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < pointCount; i++) {
      final pt = history[i];
      if (!pt.hasPitch) {
        hasStarted = false;
        continue;
      }

      final x = size.width - ((pointCount - 1 - i) * stepX);
      final clampedCents = pt.cents.clamp(-50.0, 50.0);
      // Invert Y so positive cents (sharp) is higher up
      final y = midY - (clampedCents / 50.0) * (size.height / 2 - 8);

      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }

      // Draw active head cursor
      if (i == pointCount - 1) {
        final headColor = pt.cents.abs() <= 20 ? const Color(0xFF00E676) : const Color(0xFFFFB300);
        canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = headColor);
        canvas.drawCircle(Offset(x, y), 8.0, Paint()..color = headColor.withValues(alpha: 0.35));
      }
    }

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _PitchFlowPainter oldDelegate) => true;
}

/// Dynamic Custom Painter for Pitch Gauge and Soundwave Spectrum
class _GaugeVisualizerPainter extends CustomPainter {
  final double centsDifference;
  final double inTuneProgress;
  final TrainerState state;
  final ThemeData theme;
  final double waveAnimationValue;

  _GaugeVisualizerPainter({
    required this.centsDifference,
    required this.inTuneProgress,
    required this.state,
    required this.theme,
    required this.waveAnimationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Track Background Container
    final trackPaint = Paint()
      ..color = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(18),
      ),
      trackPaint,
    );

    // In-Tune Sweet Spot Zone Window (+-20 Cents)
    final sweetSpotWidth = (40 / 100.0) * size.width;
    final sweetSpotPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: sweetSpotWidth,
          height: size.height,
        ),
        const Radius.circular(12),
      ),
      sweetSpotPaint,
    );

    // Tick Marks Paint
    final tickPaint = Paint()
      ..color = theme.colorScheme.onSurface.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;

    for (int cents = -50; cents <= 50; cents += 10) {
      final x = center.dx + (cents / 50.0) * (size.width / 2 - 20);
      final isCenter = cents == 0;
      final tickHeight = isCenter ? 28.0 : (cents % 20 == 0 ? 18.0 : 10.0);

      canvas.drawLine(
        Offset(x, center.dy - tickHeight / 2),
        Offset(x, center.dy + tickHeight / 2),
        isCenter
            ? (Paint()
              ..color = Colors.green
              ..strokeWidth = 3.0)
            : tickPaint,
      );
    }

    // Dynamic Pointer Needle Indicator
    if (state == TrainerState.listening || state == TrainerState.finished) {
      final clampedCents = centsDifference.clamp(-50.0, 50.0);
      final indicatorX =
          center.dx + (clampedCents / 50.0) * (size.width / 2 - 20);

      final isMatched = centsDifference.abs() <= 20;
      final pointerColor = isMatched ? Colors.green : Colors.amber.shade800;

      // Glowing Needle Line
      canvas.drawLine(
        Offset(indicatorX, 6),
        Offset(indicatorX, size.height - 6),
        Paint()
          ..color = pointerColor
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );

      // Needle Top Diamond
      final pointerPaint = Paint()
        ..color = pointerColor
        ..style = PaintingStyle.fill;

      final diamondPath = Path()
        ..moveTo(indicatorX, 2)
        ..lineTo(indicatorX - 7, 12)
        ..lineTo(indicatorX + 7, 12)
        ..close();
      canvas.drawPath(diamondPath, pointerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeVisualizerPainter oldDelegate) {
    return oldDelegate.centsDifference != centsDifference ||
        oldDelegate.inTuneProgress != inTuneProgress ||
        oldDelegate.state != state ||
        oldDelegate.waveAnimationValue != waveAnimationValue;
  }
}
