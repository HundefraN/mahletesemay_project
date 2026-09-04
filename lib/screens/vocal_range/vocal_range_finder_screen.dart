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

enum GuidedStep { intro, lowNote, lowNoteConfirmed, highNote, results }

class VocalRangeFinderScreen extends StatefulWidget {
  const VocalRangeFinderScreen({super.key});

  @override
  State<VocalRangeFinderScreen> createState() => _VocalRangeFinderScreenState();
}

class _VocalRangeFinderScreenState extends State<VocalRangeFinderScreen> {
  late final PitchService _pitchService;
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 2));

  GuidedStep _currentStep = GuidedStep.intro;

  double? _lowestPitchFound;
  double? _highestPitchFound;
  String _lowestNoteFound = '';
  String _highestNoteFound = '';

  // Real-time dynamic glide tracking
  String _candidateNote = '';
  double _candidatePitch = 0.0;
  int _stableFrames = 0;
  // ~450ms of steady vocal sustain
  static const int _requiredStableFrames = 9;
  double _stabilityProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _pitchService = Provider.of<PitchService>(context, listen: false);
    _pitchService.addListener(_onPitchChanged);
  }

  @override
  void dispose() {
    _pitchService.removeListener(_onPitchChanged);
    _pitchService.stopListening();
    _confettiController.dispose();
    super.dispose();
  }

  void _onPitchChanged() {
    if (!mounted) return;
    if (_currentStep != GuidedStep.lowNote &&
        _currentStep != GuidedStep.highNote) {
      return;
    }

    final pitchData = _pitchService.pitchData;
    if (pitchData.pitch <= 0.0 || pitchData.note.isEmpty) {
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

    if (_currentStep == GuidedStep.lowNote) {
      // For lowest note: dynamically track lower notes as user glides down
      if (_candidatePitch == 0.0 || detectedPitch < _candidatePitch * 1.03) {
        if (detectedNote == _candidateNote) {
          _stableFrames++;
        } else {
          _candidateNote = detectedNote;
          _candidatePitch = detectedPitch;
          _stableFrames = 1;
        }
      } else if (detectedNote == _candidateNote) {
        _stableFrames++;
      } else {
        _stableFrames = max(1, _stableFrames - 1);
      }
    } else if (_currentStep == GuidedStep.highNote) {
      // For highest note: dynamically track higher notes as user glides up
      if (_candidatePitch == 0.0 || detectedPitch > _candidatePitch * 0.97) {
        if (detectedNote == _candidateNote) {
          _stableFrames++;
        } else {
          _candidateNote = detectedNote;
          _candidatePitch = detectedPitch;
          _stableFrames = 1;
        }
      } else if (detectedNote == _candidateNote) {
        _stableFrames++;
      } else {
        _stableFrames = max(1, _stableFrames - 1);
      }
    }

    final progress = (_stableFrames / _requiredStableFrames).clamp(0.0, 1.0);

    setState(() {
      _stabilityProgress = progress;
    });

    // Auto-lock when sustained steadily
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
        'Lowest note captured: $note! Confirm to proceed to the high note test.',
        isError: false,
      );
    } else if (_currentStep == GuidedStep.highNote) {
      _pitchService.playPitchBeep(pitch);
      setState(() {
        _highestNoteFound = note;
        _highestPitchFound = pitch;
        _candidateNote = '';
        _candidatePitch = 0.0;
        _stableFrames = 0;
        _stabilityProgress = 0.0;
        _currentStep = GuidedStep.results;
      });
      _pitchService.stopListening();
      _confettiController.play();
      _pitchService.playSuccessBeep();
      CustomSnackbar.show(
        context,
        'Highest note locked: $note! Vocal Range Analysis Complete.',
        isError: false,
      );
    }
  }

  Future<void> _startHighNoteTest() async {
    _candidateNote = '';
    _candidatePitch = 0.0;
    _stableFrames = 0;
    _stabilityProgress = 0.0;
    final started = await _pitchService.startListening();
    if (started) {
      setState(() {
        _currentStep = GuidedStep.highNote;
      });
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Now glide upwards to your highest comfortable note and hold steady!',
          isError: false,
        );
      }
    } else {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Could not access audio recording input.',
          isError: true,
        );
      }
    }
  }

  Future<void> _retestLowestNote() async {
    _candidateNote = '';
    _candidatePitch = 0.0;
    _stableFrames = 0;
    _stabilityProgress = 0.0;
    _lowestNoteFound = '';
    _lowestPitchFound = null;
    final started = await _pitchService.startListening();
    if (started) {
      setState(() {
        _currentStep = GuidedStep.lowNote;
      });
    }
  }

  void _startGuidedTest() async {
    final hasPermission = await PermissionHelper.requestMicrophone(context);
    if (!hasPermission) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Microphone permission is required to test your vocal range.',
          isError: true,
        );
      }
      return;
    }

    _resetState(keepIntro: false);
    final started = await _pitchService.startListening();
    if (started) {
      setState(() {
        _currentStep = GuidedStep.lowNote;
      });
    } else {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Could not access audio recording input.',
          isError: true,
        );
      }
    }
  }

  void _resetState({bool keepIntro = true}) {
    _pitchService.stopListening();
    setState(() {
      if (keepIntro) _currentStep = GuidedStep.intro;
      _lowestPitchFound = null;
      _highestPitchFound = null;
      _lowestNoteFound = '';
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

    SharePlus.instance.share(ShareParams(text: 
      '🎤 My Vocal Range: $_lowestNoteFound - $_highestNoteFound ($span))\n'
      '🎼 Voice Type: $voiceType\n'
      'Analyzed with Mahletesemay App!',
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
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
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
                Colors.green,
                Colors.purple
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
      case GuidedStep.lowNote:
        return _buildStepCaptureView(
          theme: theme,
          stepTitle: AppLocalizations.of(context)?.step1FindLowest ?? "Step 1: Find Your Lowest Note",
          stepInstruction:
              AppLocalizations.of(context)?.step1FindLowestDesc ??
                  "Hum or sing downwards to your lowest comfortable pitch and hold it steady.",
          currentLowest: _lowestNoteFound,
          currentHighest: _highestNoteFound,
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
      case GuidedStep.highNote:
        return _buildStepCaptureView(
          theme: theme,
          stepTitle: AppLocalizations.of(context)?.step2FindHighest ?? "Step 2: Find Your Highest Note",
          stepInstruction:
              AppLocalizations.of(context)?.step2FindHighestDesc ??
                  "Glide upwards to your highest comfortable note (chest or head voice) and hold it steady.",
          currentLowest: _lowestNoteFound,
          currentHighest: _highestNoteFound,
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
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
                fontSize: 26,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 12),
            Text(
              l10n.voiceTypeDisclaimer,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _StepInfoRow(
                      number: '1',
                      title: l10n.findLowestNote,
                      subtitle: l10n.findLowestNoteDesc,
                      color: Colors.blueAccent,
                    ),
                    const Divider(height: 28),
                    _StepInfoRow(
                      number: '2',
                      title: l10n.findHighestNote,
                      subtitle: l10n.findHighestNoteDesc,
                      color: Colors.purpleAccent,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startGuidedTest,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: Text(
                  l10n.startFindingLowest,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
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
    required String stepTitle,
    required String stepInstruction,
    required String currentLowest,
    required String currentHighest,
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header Step Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  stepTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                stepInstruction,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Modern Equalizer Visualizer & Real-Time Audio Waveform Card
              _ModernEqualizerCard(
                pitch: displayPitch,
                note: displayNote,
                stabilityProgress: _stabilityProgress,
                waveform: pitchData.waveform,
                rms: pitchData.rms,
                isListening: _pitchService.isListening,
              ),

              const SizedBox(height: 16),

              // Live Piano Roll Feedback
              VocalPianoRoll(
                lowestNote: currentLowest.isNotEmpty ? currentLowest : null,
                highestNote: currentHighest.isNotEmpty ? currentHighest : null,
                currentNote: displayNote.isNotEmpty ? displayNote : null,
              ),

              const SizedBox(height: 16),

              // Stability Progress Meter
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _stabilityProgress > 0
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_none_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _stabilityProgress > 0
                                ? (AppLocalizations.of(context)?.holdingSteady ?? "Hold note steady...")
                                : (AppLocalizations.of(context)?.listening ?? "Listening..."),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(_stabilityProgress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: _stabilityProgress),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 10,
                          backgroundColor: theme
                              .colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            value >= 1.0
                                ? Colors.greenAccent.shade700
                                : theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Captured Notes Badges
              Row(
                children: [
                  Expanded(
                    child: _CapturedNoteCard(
                      label: AppLocalizations.of(context)?.lowestNote ?? "Lowest Note",
                      note: currentLowest.isNotEmpty
                          ? currentLowest
                          : (_currentStep == GuidedStep.lowNote &&
                                  displayNote.isNotEmpty
                              ? displayNote
                              : '--'),
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CapturedNoteCard(
                      label: AppLocalizations.of(context)?.highestNote ?? "Highest Note",
                      note: currentHighest.isNotEmpty
                          ? currentHighest
                          : (_currentStep == GuidedStep.highNote &&
                                  displayNote.isNotEmpty
                              ? displayNote
                              : '--'),
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Manual Lock Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: displayNote.isNotEmpty ? onLockManual : null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                      '${AppLocalizations.of(context)?.lockNote ?? 'Lock Note'} (${displayNote.isEmpty ? "--" : displayNote})'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
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
                  colors: [Color(0xFF00C853), Color(0xFF009688)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),

            Text(
              "Lowest Note Confirmed!",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0A1E3F),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn().slideY(begin: 0.2),

            const SizedBox(height: 8),

            Text(
              "Your lowest vocal note has been recorded and verified.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Note Card with Pitch and Tone Playback
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
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
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_lowestPitchFound?.toStringAsFixed(1) ?? '0.0'} Hz",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueAccent,
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
                    label: const Text("Listen to Note"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Step 1 Complete! Click continue when you are ready to find your highest note. Take a breath and get ready to glide upwards.",
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
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
                    onPressed: _retestLowestNote,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Retest"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _startHighNoteTest,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      "Continue to High Note",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    l10n.yourResults.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      voiceTypeName,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                  if (voiceRangeInfo != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      voiceRangeInfo.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  const Divider(height: 36),

                  // Fixed layout using FittedBox to prevent overflows on small phones
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$_lowestNoteFound  ➔  $_highestNoteFound',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rangeSpan,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (voiceRangeInfo != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      voiceRangeInfo.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
                      borderRadius: BorderRadius.circular(14),
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
                      borderRadius: BorderRadius.circular(14),
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

// Modern Equalizer & Audio Waveform Display Component
class _ModernEqualizerCard extends StatelessWidget {
  final double pitch;
  final String note;
  final double stabilityProgress;
  final Float64List? waveform;
  final double rms;
  final bool isListening;

  const _ModernEqualizerCard({
    required this.pitch,
    required this.note,
    required this.stabilityProgress,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          // Animated Note Display
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              isActive ? note : '--',
              key: ValueKey(note.isEmpty ? '--' : note),
              style: GoogleFonts.poppins(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                height: 1.0,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 150),
            tween: Tween<double>(begin: 0, end: pitch),
            builder: (context, value, child) {
              return Text(
                value > 0 ? '${value.toStringAsFixed(1)} Hz' : '0.0 Hz',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Real Live Audio PCM Waveform Visualizer
          AudioWaveformVisualizer(
            waveform: waveform,
            rms: rms,
            pitch: pitch,
            isListening: isListening,
            height: 52.0,
            primaryColor: theme.colorScheme.primary,
            secondaryColor: theme.colorScheme.secondary,
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
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
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
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
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

  const _CapturedNoteCard({
    required this.label,
    required this.note,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 1,
              ),
            ),
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
