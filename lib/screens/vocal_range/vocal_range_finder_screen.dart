import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/pitch_trainer/pitch_trainer_screen.dart';
import 'package:mahlete_semay_project/services/pitch_service.dart';
import 'package:mahlete_semay_project/widgets/audio_waveform_visualizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:mahlete_semay_project/widgets/vocal_piano_roll.dart';
import 'package:mahlete_semay_project/utils/permission_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mahlete_semay_project/widgets/web_content_wrapper.dart';

enum GuidedStep {
  intro,
  lowCountdown,
  lowNote,
  lowNoteConfirmed,
  highCountdown,
  highNote,
  results,
}

class VocalRangeFinderScreen extends StatefulWidget {
  const VocalRangeFinderScreen({super.key});

  @override
  State<VocalRangeFinderScreen> createState() => _VocalRangeFinderScreenState();
}

class _VocalRangeFinderScreenState extends State<VocalRangeFinderScreen>
    with SingleTickerProviderStateMixin {
  late final PitchService _pitchService;
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));

  GuidedStep _currentStep = GuidedStep.intro;

  double? _lowestPitchFound;
  String _lowestNoteFound = '';
  double? _highestPitchFound;
  String _highestNoteFound = '';

  // Real-time dynamic vocal sustain tracking
  String _candidateNote = '';
  double _candidatePitch = 0.0;
  int _stableFrames = 0;
  // ~1.15s of steady vocal sustain required for confident Yousician-style lock
  // With 23.2ms audio hop size, 36 frames represents ~835ms of solid sustained vocal phonation
  static const int _requiredStableFrames = 36;
  double _stabilityProgress = 0.0;

  // Countdown State (3... 2... 1... SING!)
  Timer? _countdownTimer;
  int _countdownNumber = 3;
  bool _isCountdownGo = false;

  @override
  void initState() {
    super.initState();
    _pitchService = Provider.of<PitchService>(context, listen: false);
    _pitchService.addListener(_onPitchChanged);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pitchService.removeListener(_onPitchChanged);
    _pitchService.stopListening();
    _confettiController.dispose();
    super.dispose();
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownNumber = 3;
    _isCountdownGo = false;
  }

  void _startLowNoteCountdown() {
    _resetCountdown();
    setState(() {
      _currentStep = GuidedStep.lowCountdown;
      _countdownNumber = 3;
      _isCountdownGo = false;
    });
    _pitchService.playCountdownTick();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
        _pitchService.playCountdownTick();
      } else if (_countdownNumber == 1) {
        setState(() {
          _countdownNumber = 0;
          _isCountdownGo = true;
        });
        _pitchService.playCountdownGo();
      } else {
        timer.cancel();
        _startLowNoteListening();
      }
    });
  }

  void _startHighNoteCountdown() {
    _resetCountdown();
    setState(() {
      _currentStep = GuidedStep.highCountdown;
      _countdownNumber = 3;
      _isCountdownGo = false;
    });
    _pitchService.playCountdownTick();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
        _pitchService.playCountdownTick();
      } else if (_countdownNumber == 1) {
        setState(() {
          _countdownNumber = 0;
          _isCountdownGo = true;
        });
        _pitchService.playCountdownGo();
      } else {
        timer.cancel();
        _startHighNoteListening();
      }
    });
  }

  Future<void> _startLowNoteListening() async {
    _candidateNote = '';
    _candidatePitch = 0.0;
    _stableFrames = 0;
    _stabilityProgress = 0.0;

    final started = await _pitchService.startListening();
    if (!mounted) return;
    if (started) {
      setState(() {
        _currentStep = GuidedStep.lowNote;
      });
    } else {
      CustomSnackbar.show(
        context,
        AppLocalizations.of(context)?.micPermissionRequired ??
            'Could not access microphone input.',
        isError: true,
      );
    }
  }

  Future<void> _startHighNoteListening() async {
    _candidateNote = '';
    _candidatePitch = 0.0;
    _stableFrames = 0;
    _stabilityProgress = 0.0;

    final started = await _pitchService.startListening();
    if (!mounted) return;
    if (started) {
      setState(() {
        _currentStep = GuidedStep.highNote;
      });
    } else {
      CustomSnackbar.show(
        context,
        AppLocalizations.of(context)?.micPermissionRequired ??
            'Could not access microphone input.',
        isError: true,
      );
    }
  }

  void _onPitchChanged() {
    if (!mounted) return;
    if (_currentStep != GuidedStep.lowNote &&
        _currentStep != GuidedStep.highNote) {
      return;
    }

    final pitchData = _pitchService.pitchData;
    // Discard silence, noise, or unvoiced breath onsets
    if (pitchData.pitch <= 0.0 || pitchData.note.isEmpty || pitchData.clarity < 0.40) {
      if (_stableFrames > 0) {
        setState(() {
          _stableFrames = max(0, _stableFrames - 1);
          _stabilityProgress =
              (_stableFrames / _requiredStableFrames).clamp(0.0, 1.0);
        });
      }
      return;
    }

    final detectedPitch = pitchData.pitch;
    final detectedNote = pitchData.note;

    if (_candidateNote.isEmpty || _candidatePitch <= 0) {
      _candidateNote = detectedNote;
      _candidatePitch = detectedPitch;
      _stableFrames = 1;
    } else {
      // Check if user is sustaining within the same musical semitone or within ±45 cents
      final centsDiff =
          _pitchService.getCentsDifference(_candidatePitch, detectedPitch).abs();
      final bool isSameNote =
          (detectedNote == _candidateNote) || (centsDiff <= 45.0);

      if (_currentStep == GuidedStep.lowNote) {
        // Dynamically track even lower notes as user hums/glides down
        if (detectedPitch < _candidatePitch * 0.96) {
          _candidateNote = detectedNote;
          _candidatePitch = detectedPitch;
          _stableFrames = 1;
        } else if (isSameNote) {
          _stableFrames++;
          // Rolling center average for accurate cent precision
          _candidatePitch = _candidatePitch * 0.85 + detectedPitch * 0.15;
        } else {
          // Brief pitch jitter: decay gently without abrupt reset
          _stableFrames = max(0, _stableFrames - 2);
        }
      } else if (_currentStep == GuidedStep.highNote) {
        // Dynamically track higher notes as user glides up
        if (detectedPitch > _candidatePitch * 1.04) {
          _candidateNote = detectedNote;
          _candidatePitch = detectedPitch;
          _stableFrames = 1;
        } else if (isSameNote) {
          _stableFrames++;
          _candidatePitch = _candidatePitch * 0.85 + detectedPitch * 0.15;
        } else {
          _stableFrames = max(0, _stableFrames - 2);
        }
      }
    }

    final progress = (_stableFrames / _requiredStableFrames).clamp(0.0, 1.0);
    setState(() {
      _stabilityProgress = progress;
    });

    // Auto-lock when sustained steadily with high confidence
    if (_stableFrames >= _requiredStableFrames) {
      _lockNote(_candidateNote, _candidatePitch);
    }
  }

  void _lockNote(String note, double pitch) {
    if (note.isEmpty || pitch <= 0) return;

    if (_currentStep == GuidedStep.lowNote) {
      _pitchService.playLockNoteBeep();
      _pitchService.stopListening();
      setState(() {
        _lowestNoteFound = note;
        _lowestPitchFound = pitch;
        _candidateNote = '';
        _candidatePitch = 0.0;
        _stableFrames = 0;
        _stabilityProgress = 0.0;
        _currentStep = GuidedStep.lowNoteConfirmed;
      });
      CustomSnackbar.show(
        context,
        'Lowest key locked: $note (${pitch.toStringAsFixed(1)} Hz)!',
        isError: false,
      );
    } else if (_currentStep == GuidedStep.highNote) {
      _pitchService.playLockNoteBeep();
      _pitchService.stopListening();
      setState(() {
        _highestNoteFound = note;
        _highestPitchFound = pitch;
        _candidateNote = '';
        _candidatePitch = 0.0;
        _stableFrames = 0;
        _stabilityProgress = 0.0;
        _currentStep = GuidedStep.results;
      });
      _confettiController.play();
      _pitchService.playSuccessBeep();
      CustomSnackbar.show(
        context,
        'Highest key locked: $note (${pitch.toStringAsFixed(1)} Hz)! Range Complete.',
        isError: false,
      );
    }
  }

  void _startGuidedTest() async {
    final hasPermission = await PermissionHelper.requestMicrophone(context);
    if (!hasPermission) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          AppLocalizations.of(context)?.micPermissionRequired ??
              'Microphone permission is required to test your vocal range.',
          isError: true,
        );
      }
      return;
    }

    _resetState(keepIntro: false);
    _startLowNoteCountdown();
  }

  void _resetState({bool keepIntro = true}) {
    _resetCountdown();
    _pitchService.stopListening();
    setState(() {
      if (keepIntro) _currentStep = GuidedStep.intro;
      _lowestPitchFound = null;
      _lowestNoteFound = '';
      _highestPitchFound = null;
      _highestNoteFound = '';
      _candidateNote = '';
      _candidatePitch = 0.0;
      _stableFrames = 0;
      _stabilityProgress = 0.0;
    });
  }

  void _shareResults() {
    if (_lowestNoteFound.isEmpty || _highestNoteFound.isEmpty) return;
    final voiceType =
        _pitchService.getVoiceType(_lowestNoteFound, _highestNoteFound);
    final span =
        _pitchService.getVocalRangeSpan(_lowestNoteFound, _highestNoteFound);

    SharePlus.instance.share(ShareParams(
      text: '🎤 My Vocal Range: $_lowestNoteFound - $_highestNoteFound ($span)\n'
          '🎼 Voice Classification: $voiceType\n'
          'Analyzed with Mahlete Semay Studio App!',
      subject: 'My Vocal Range Test Results',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.vocalRangeFinder,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_currentStep != GuidedStep.intro)
            IconButton(
              onPressed: () => _resetState(keepIntro: true),
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: AppLocalizations.of(context)?.startOver ?? 'Start Over',
            ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_currentStep),
              child: WebContentWrapper(
                maxWidth: 720,
                child: _buildCurrentStepView(theme),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                Colors.amber,
                Colors.greenAccent,
                Colors.purpleAccent
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView(ThemeData theme) {
    switch (_currentStep) {
      case GuidedStep.intro:
        return _buildIntroView(theme);

      case GuidedStep.lowCountdown:
        return _CountdownView(
          stepTitle: AppLocalizations.of(context)?.step1FindLowest ??
              "Step 1: Lowest Key",
          stepSubtitle:
              "Take a breath and get ready to hum or sing your lowest comfortable note.",
          countdownNumber: _countdownNumber,
          isGo: _isCountdownGo,
          accentColor: const Color(0xFF00E5FF),
          onSkip: () {
            _resetCountdown();
            _startLowNoteListening();
          },
        );

      case GuidedStep.lowNote:
        return _buildStepCaptureView(
          theme: theme,
          isHighNoteTest: false,
          stepTitle: AppLocalizations.of(context)?.step1FindLowest ??
              "Step 1: Find Your Lowest Key",
          stepInstruction: AppLocalizations.of(context)?.step1FindLowestDesc ??
              "Hum or sing downwards to your lowest comfortable pitch and hold it steady.",
          currentLowest: _lowestNoteFound,
          currentHighest: _highestNoteFound,
          accentColor: const Color(0xFF00E5FF),
          onLockManual: () {
            final pitchData = _pitchService.pitchData;
            final noteToLock =
                _candidateNote.isNotEmpty ? _candidateNote : pitchData.note;
            final pitchToLock =
                _candidatePitch > 0 ? _candidatePitch : pitchData.pitch;

            if (noteToLock.isNotEmpty && pitchToLock > 0) {
              _lockNote(noteToLock, pitchToLock);
            } else {
              CustomSnackbar.show(
                context,
                AppLocalizations.of(context)?.singNotePrompt ??
                    'Sing a note into the microphone first!',
                isError: true,
              );
            }
          },
        );

      case GuidedStep.lowNoteConfirmed:
        return _buildLowNoteConfirmedView(theme);

      case GuidedStep.highCountdown:
        return _CountdownView(
          stepTitle: AppLocalizations.of(context)?.step2FindHighest ??
              "Step 2: Highest Key",
          stepSubtitle:
              "Take a deep breath and get ready to glide up to your highest comfortable note.",
          countdownNumber: _countdownNumber,
          isGo: _isCountdownGo,
          accentColor: const Color(0xFFD500F9),
          onSkip: () {
            _resetCountdown();
            _startHighNoteListening();
          },
        );

      case GuidedStep.highNote:
        return _buildStepCaptureView(
          theme: theme,
          isHighNoteTest: true,
          stepTitle: AppLocalizations.of(context)?.step2FindHighest ??
              "Step 2: Find Your Highest Key",
          stepInstruction: AppLocalizations.of(context)?.step2FindHighestDesc ??
              "Glide upwards to your highest comfortable note (chest or head voice) and hold it steady.",
          currentLowest: _lowestNoteFound,
          currentHighest: _highestNoteFound,
          accentColor: const Color(0xFFD500F9),
          onLockManual: () {
            final pitchData = _pitchService.pitchData;
            final noteToLock =
                _candidateNote.isNotEmpty ? _candidateNote : pitchData.note;
            final pitchToLock =
                _candidatePitch > 0 ? _candidatePitch : pitchData.pitch;

            if (noteToLock.isNotEmpty && pitchToLock > 0) {
              _lockNote(noteToLock, pitchToLock);
            } else {
              CustomSnackbar.show(
                context,
                AppLocalizations.of(context)?.singHighNotePrompt ??
                    'Sing a high note into the microphone first!',
                isError: true,
              );
            }
          },
        );

      case GuidedStep.results:
        return _buildResultsView(theme);
    }
  }

  Widget _buildIntroView(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 64,
                color: Colors.white,
              ),
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(end: 1.06, duration: 1200.ms, curve: Curves.easeInOut),
            const SizedBox(height: 28),
            Text(
              l10n.vocalRangeFinder,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 12),
            Text(
              "Discover your exact vocal range and voice type with precision audio detection and interactive sustain tracking.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              color:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  children: [
                    _StepInfoRow(
                      number: '1',
                      title: l10n.findLowestNote,
                      subtitle:
                          "Hear countdown 3...2...1, then hum or sing your lowest comfortable pitch and hold it steady.",
                      color: const Color(0xFF00E5FF),
                    ),
                    const Divider(height: 28),
                    _StepInfoRow(
                      number: '2',
                      title: l10n.findHighestNote,
                      subtitle:
                          "Hear countdown 3...2...1, then glide up to your highest comfortable note and hold it steady.",
                      color: const Color(0xFFD500F9),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startGuidedTest,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: Text(
                  l10n.startFindingLowest,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCaptureView({
    required ThemeData theme,
    required bool isHighNoteTest,
    required String stepTitle,
    required String stepInstruction,
    required String currentLowest,
    required String currentHighest,
    required Color accentColor,
    required VoidCallback onLockManual,
  }) {
    return Consumer<PitchService>(
      builder: (context, pitchService, child) {
        final pitchData = pitchService.pitchData;
        final currentPitch = pitchData.pitch;
        final currentNote = pitchData.note;

        final displayNote =
            _candidateNote.isNotEmpty ? _candidateNote : currentNote;
        final displayPitch =
            _candidatePitch > 0 ? _candidatePitch : currentPitch;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              // Header Step Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHighNoteTest
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stepTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stepInstruction,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 20),

              // Yousician-Style Circular Sustain Gauge
              _YousicianSustainGauge(
                note: displayNote,
                pitch: displayPitch,
                cents: pitchData.cents,
                progress: _stabilityProgress,
                accentColor: accentColor,
                waveform: pitchData.waveform,
                rms: pitchData.rms,
                isListening: _pitchService.isListening,
              ),

              const SizedBox(height: 18),

              // Live Piano Roll Feedback
              VocalPianoRoll(
                lowestNote: currentLowest.isNotEmpty ? currentLowest : null,
                highestNote: currentHighest.isNotEmpty ? currentHighest : null,
                currentNote: displayNote.isNotEmpty ? displayNote : null,
              ),

              const SizedBox(height: 18),

              // Captured Notes Badges
              Row(
                children: [
                  Expanded(
                    child: _CapturedNoteCard(
                      label: AppLocalizations.of(context)?.lowestNote ??
                          "Lowest Key",
                      note: currentLowest.isNotEmpty
                          ? currentLowest
                          : (!isHighNoteTest && displayNote.isNotEmpty
                              ? displayNote
                              : '--'),
                      color: const Color(0xFF00E5FF),
                      isLocked: currentLowest.isNotEmpty,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CapturedNoteCard(
                      label: AppLocalizations.of(context)?.highestNote ??
                          "Highest Key",
                      note: currentHighest.isNotEmpty
                          ? currentHighest
                          : (isHighNoteTest && displayNote.isNotEmpty
                              ? displayNote
                              : '--'),
                      color: const Color(0xFFD500F9),
                      isLocked: currentHighest.isNotEmpty,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Actions: Listen Tone and Manual Lock Button
              Row(
                children: [
                  if (displayNote.isNotEmpty) ...[
                    IconButton.filledTonal(
                      tooltip: 'Listen to Reference Note',
                      icon: const Icon(Icons.volume_up_rounded),
                      onPressed: () => _pitchService.playNoteBeep(displayNote),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: displayNote.isNotEmpty ? onLockManual : null,
                        icon: const Icon(Icons.lock_clock_rounded),
                        label: Text(
                          displayNote.isNotEmpty
                              ? 'Lock Key ($displayNote)'
                              : 'Sing into Microphone...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor:
                              displayNote.isNotEmpty ? accentColor : null,
                          foregroundColor: displayNote.isNotEmpty
                              ? Colors.black
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowNoteConfirmedView(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Celebratory Check Badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.black, size: 48),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),

            Text(
              "Lowest Key Locked!",
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0A1E3F),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn().slideY(begin: 0.2),

            const SizedBox(height: 8),

            Text(
              "Your lowest vocal note has been measured and sustained successfully.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Note Card with Pitch and Tone Playback
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _lowestNoteFound,
                        style: GoogleFonts.poppins(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${_lowestPitchFound?.toStringAsFixed(1) ?? '0.0'} Hz",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (_lowestPitchFound != null) {
                        _pitchService.playPitchBeep(_lowestPitchFound!);
                      }
                    },
                    icon: const Icon(Icons.volume_up_rounded, size: 20),
                    label: const Text("Listen to Tone"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15),

            const SizedBox(height: 20),

            // Live Piano Roll highlight for lowest note
            VocalPianoRoll(
              lowestNote: _lowestNoteFound,
              highestNote: null,
              currentNote: _lowestNoteFound,
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // Next step instruction prompt
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Ready for Step 2? We'll count down 3...2...1, then you glide upwards to your highest comfortable note.",
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms),

            const SizedBox(height: 28),

            // Actions: Retest or Continue to High Note
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _startLowNoteCountdown,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Retest"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _startHighNoteCountdown,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      "Continue to High Key",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final voiceRangeInfo = _pitchService.getVoiceTypeRange(
      _lowestNoteFound,
      _highestNoteFound,
    );
    final voiceTypeName = voiceRangeInfo?.name ?? l10n.uniqueRange;
    final rangeSpan = _pitchService.getVocalRangeSpan(
      _lowestNoteFound,
      _highestNoteFound,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    "YOUR VOCAL PROFILE".toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD500F9).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      voiceTypeName,
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                  if (voiceRangeInfo != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      voiceRangeInfo.category,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  const Divider(height: 36),

                  // Fixed layout using FittedBox to prevent overflows
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NoteBadge(
                          label: "LOWEST",
                          note: _lowestNoteFound,
                          hz: _lowestPitchFound != null
                              ? '${_lowestPitchFound!.toStringAsFixed(1)} Hz'
                              : '',
                          color: const Color(0xFF00E5FF),
                          onPlay: () {
                            if (_lowestPitchFound != null) {
                              _pitchService.playPitchBeep(_lowestPitchFound!);
                            }
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 28, color: Colors.grey),
                        ),
                        _NoteBadge(
                          label: "HIGHEST",
                          note: _highestNoteFound,
                          hz: _highestPitchFound != null
                              ? '${_highestPitchFound!.toStringAsFixed(1)} Hz'
                              : '',
                          color: const Color(0xFFD500F9),
                          onPlay: () {
                            if (_highestPitchFound != null) {
                              _pitchService.playPitchBeep(_highestPitchFound!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    rangeSpan,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (voiceRangeInfo != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      voiceRangeInfo.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    if (voiceRangeInfo.famousExamples.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Famous Singers: ${voiceRangeInfo.famousExamples.join(", ")}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 20),

          VocalPianoRoll(
            lowestNote: _lowestNoteFound,
            highestNote: _highestNoteFound,
            voiceTypeRange: voiceRangeInfo,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),

          // Training Recommendation Card
          Card(
            elevation: 1,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child:
                    const Icon(Icons.music_note_rounded, color: Colors.white),
              ),
              title: Text(
                l10n.trainYourVoicePitch,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(l10n.practiceHittingNotes),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PitchTrainerScreen(),
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _resetState(keepIntro: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retestRange),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareResults,
                  icon: const Icon(Icons.share_rounded),
                  label: Text(l10n.shareResults),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Yousician-Style Animated Countdown Overlay Component
// -------------------------------------------------------------
class _CountdownView extends StatelessWidget {
  final String stepTitle;
  final String stepSubtitle;
  final int countdownNumber;
  final bool isGo;
  final Color accentColor;
  final VoidCallback onSkip;

  const _CountdownView({
    required this.stepTitle,
    required this.stepSubtitle,
    required this.countdownNumber,
    required this.isGo,
    required this.accentColor,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                stepTitle,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              stepSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 48),

            // Giant Pulsing Countdown Number (3... 2... 1... SING!)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: isGo ? 0.35 : 0.15),
                    accentColor.withValues(alpha: 0.0),
                  ],
                ),
                border: Border.all(
                  color: accentColor.withValues(alpha: isGo ? 0.8 : 0.35),
                  width: isGo ? 4 : 2,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.4, end: 1.0).animate(
                        CurvedAnimation(
                            parent: anim, curve: Curves.easeOutBack),
                      ),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: isGo
                      ? Text(
                          "SING!",
                          key: const ValueKey("go"),
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: accentColor,
                            shadows: [
                              Shadow(
                                color: accentColor.withValues(alpha: 0.8),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        )
                      : Text(
                          "$countdownNumber",
                          key: ValueKey(countdownNumber),
                          style: GoogleFonts.poppins(
                            fontSize: 88,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: accentColor.withValues(alpha: 0.6),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 48),

            TextButton.icon(
              onPressed: onSkip,
              icon: const Icon(Icons.fast_forward_rounded, size: 20),
              label: const Text("Skip Countdown"),
              style: TextButton.styleFrom(
                foregroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Yousician-Style Circular Sustain Gauge Component
// -------------------------------------------------------------
class _YousicianSustainGauge extends StatelessWidget {
  final String note;
  final double pitch;
  final double cents;
  final double progress;
  final Color accentColor;
  final Float64List? waveform;
  final double rms;
  final bool isListening;

  const _YousicianSustainGauge({
    required this.note,
    required this.pitch,
    required this.cents,
    required this.progress,
    required this.accentColor,
    this.waveform,
    this.rms = 0.0,
    this.isListening = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = pitch > 0 && note.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.4)
              : theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          // Circular Sustain Ring with Center Note & Live Needle
          SizedBox(
            width: 210,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Radial Sustain Painter
                CustomPaint(
                  size: const Size(210, 210),
                  painter: _SustainRadialPainter(
                    progress: progress,
                    accentColor: accentColor,
                    trackColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.8),
                    isActive: isActive,
                  ),
                ),

                // Note Letter & Exact Hz Display
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        isActive ? note : '--',
                        key: ValueKey(note.isEmpty ? '--' : note),
                        style: GoogleFonts.poppins(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          color: isActive
                              ? accentColor
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                          shadows: isActive
                              ? [
                                  Shadow(
                                    color: accentColor.withValues(alpha: 0.6),
                                    blurRadius: 16,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pitch > 0 ? '${pitch.toStringAsFixed(1)} Hz' : '0.0 Hz',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cents In-Tune Ribbon
                    _MiniCentsBar(
                      cents: cents,
                      isActive: isActive,
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dynamic Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: progress >= 1.0
                  ? Colors.greenAccent.withValues(alpha: 0.2)
                  : (progress > 0
                      ? accentColor.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  progress >= 1.0
                      ? Icons.check_circle_rounded
                      : (progress > 0
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_rounded),
                  size: 16,
                  color: progress >= 1.0
                      ? Colors.greenAccent
                      : (progress > 0
                          ? accentColor
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 8),
                Text(
                  progress >= 1.0
                      ? "Key Locked!"
                      : (progress > 0
                          ? "Sustaining key... ${(progress * 100).toInt()}%"
                          : "Sing or hum into microphone..."),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0
                        ? Colors.greenAccent
                        : (progress > 0
                            ? accentColor
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Real Live Audio PCM Waveform Visualizer
          AudioWaveformVisualizer(
            waveform: waveform,
            rms: rms,
            pitch: pitch,
            isListening: isListening,
            height: 44.0,
            primaryColor: accentColor,
            secondaryColor: theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Circular Radial Painter for Yousician Ring
// -------------------------------------------------------------
class _SustainRadialPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color trackColor;
  final bool isActive;

  _SustainRadialPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 10.0;

    // Background circle track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    if (progress > 0.0) {
      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

      // Glow shadow
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth + 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );

      // Main gradient arc
      final progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SustainRadialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isActive != isActive;
  }
}

// -------------------------------------------------------------
// Mini In-Tune Cents Ribbon
// -------------------------------------------------------------
class _MiniCentsBar extends StatelessWidget {
  final double cents;
  final bool isActive;
  final Color accentColor;

  const _MiniCentsBar({
    required this.cents,
    required this.isActive,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isCenter = isActive && cents.abs() <= 12.0;

    return Container(
      width: 120,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center tick
          Container(
            width: 2,
            height: 10,
            color: isCenter
                ? Colors.greenAccent
                : Colors.white.withValues(alpha: 0.3),
          ),
          if (isActive)
            Align(
              alignment: Alignment((cents / 50.0).clamp(-1.0, 1.0), 0),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCenter ? Colors.greenAccent : accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: (isCenter ? Colors.greenAccent : accentColor)
                          .withValues(alpha: 0.6),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepInfoRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final Color color;

  const _StepInfoRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Text(
            number,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CapturedNoteCard extends StatelessWidget {
  final String label;
  final String note;
  final Color color;
  final bool isLocked;

  const _CapturedNoteCard({
    required this.label,
    required this.note,
    required this.color,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLocked ? color : color.withValues(alpha: 0.25),
          width: isLocked ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLocked) ...[
                Icon(Icons.lock_rounded, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Text(
              note.isEmpty ? '--' : note,
              key: ValueKey(note),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBadge extends StatelessWidget {
  final String label;
  final String note;
  final String hz;
  final Color color;
  final VoidCallback onPlay;

  const _NoteBadge({
    required this.label,
    required this.note,
    required this.hz,
    required this.color,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (hz.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              hz,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 6),
          IconButton.filledTonal(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: onPlay,
            tooltip: 'Play $note tone',
          ),
        ],
      ),
    );
  }
}
