import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/services/pitch_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';

enum FinderState { idle, listening, finished }

class VocalRangeFinderScreen extends StatefulWidget {
  const VocalRangeFinderScreen({super.key});

  @override
  State<VocalRangeFinderScreen> createState() => _VocalRangeFinderScreenState();
}

class _VocalRangeFinderScreenState extends State<VocalRangeFinderScreen> {
  late final PitchService _pitchService;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  FinderState _currentState = FinderState.idle;

  double? _lowestPitchFound;
  double? _highestPitchFound;
  String _lowestNoteFound = '';
  String _highestNoteFound = '';

  final List<double> _pitchBuffer = [];
  static const int _pitchBufferSize = 5;
  static const double _stabilityThresholdHz = 15.0;
  bool _noteLocked = false;

  @override
  void initState() {
    super.initState();
    _pitchService = Provider.of<PitchService>(context, listen: false);
    _pitchService.addListener(_onPitchChanged);
  }

  @override
  void dispose() {
    _pitchService.removeListener(_onPitchChanged);
    if (_currentState == FinderState.listening) {
      _pitchService.stopListening();
    }
    _confettiController.dispose();
    super.dispose();
  }

  void _onPitchChanged() {
    if (!mounted || _currentState != FinderState.listening) return;

    final pitchData = _pitchService.pitchData;
    if (pitchData.pitch == 0.0) return;

    _pitchBuffer.add(pitchData.pitch);
    if (_pitchBuffer.length > _pitchBufferSize) _pitchBuffer.removeAt(0);

    if (_pitchBuffer.length == _pitchBufferSize) {
      final mean = _pitchBuffer.reduce((a, b) => a + b) / _pitchBufferSize;
      final variance = _pitchBuffer.map((p) => pow(p - mean, 2)).reduce((a, b) => a + b) / _pitchBufferSize;
      final stdDev = sqrt(variance);

      if (stdDev < _stabilityThresholdHz) {
        if (mounted) {
          setState(() => _noteLocked = true);
          Timer(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _noteLocked = false);
          });
        }

        if (_lowestPitchFound == null) {
          _lowestPitchFound = mean;
          _highestPitchFound = mean;
        } else {
          if (mean < _lowestPitchFound!) _lowestPitchFound = mean;
          if (mean > _highestPitchFound!) _highestPitchFound = mean;
        }

        if (mounted) {
          setState(() {
            _lowestNoteFound = _pitchService.getNoteFromPitch(_lowestPitchFound!);
            _highestNoteFound = _pitchService.getNoteFromPitch(_highestPitchFound!);
          });
        }
      }
    }
  }

  void _startListening() async {
    _reset(keepState: true);
    final hasStarted = await _pitchService.startListening();
    if (hasStarted) {
      setState(() => _currentState = FinderState.listening);
    } else {
      if (mounted) {
        CustomSnackbar.show(context, 'Microphone permission may be denied. Please check your settings.', isError: true);
        openAppSettings();
      }
    }
  }

  void _stopListening() {
    _pitchService.stopListening();
    setState(() => _currentState = FinderState.finished);
    if (_lowestNoteFound.isNotEmpty && _highestNoteFound.isNotEmpty) {
      _confettiController.play();
    }
  }

  void _reset({bool keepState = false}) {
    _pitchService.stopListening();
    if (mounted) {
      setState(() {
        if (!keepState) _currentState = FinderState.idle;
        _lowestPitchFound = null;
        _highestPitchFound = null;
        _lowestNoteFound = '';
        _highestNoteFound = '';
        _pitchBuffer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.vocalRangeFinder),
        actions: [
          if (_currentState != FinderState.idle)
            IconButton(onPressed: () => _reset(), icon: const Icon(Icons.refresh))
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: _buildCurrentView(),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary, Colors.green, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentState) {
      case FinderState.listening:
        return Consumer<PitchService>(
            builder: (context, pitchService, child) {
              return _ListeningView(
                pitchService: pitchService,
                currentPitch: pitchService.pitchData.pitch,
                currentNote: pitchService.pitchData.note,
                lowestNote: _lowestNoteFound,
                highestNote: _highestNoteFound,
                noteLocked: _noteLocked,
                onStop: _stopListening,
              );
            }
        );
      case FinderState.finished:
        return _ResultsView(
          lowestNote: _lowestNoteFound,
          highestNote: _highestNoteFound,
          voiceType: _pitchService.getVoiceType(_lowestNoteFound, _highestNoteFound),
          onTryAgain: () => _reset(),
        );
      case FinderState.idle:
      default:
        return _IdleView(onStart: _startListening);
    }
  }
}

class _IdleView extends StatelessWidget {
  final VoidCallback onStart;
  const _IdleView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child: Icon(Icons.mic_none_rounded, size: 80, color: theme.colorScheme.primary),
          ).animate().scale(delay: 200.ms),
          const SizedBox(height: 32),
          Text(
            'Discover Your Vocal Range',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
          const SizedBox(height: 16),
          Text(
            'Press Start, then sing your lowest note and hold it steady. Then, glide up to your highest note and hold it steady.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600, height: 1.5),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5),
        ],
      ),
    );
  }
}

class _ListeningView extends StatelessWidget {
  final PitchService pitchService;
  final double currentPitch;
  final String currentNote;
  final String lowestNote;
  final String highestNote;
  final bool noteLocked;
  final VoidCallback onStop;

  const _ListeningView({
    required this.pitchService,
    required this.currentPitch,
    required this.currentNote,
    required this.lowestNote,
    required this.highestNote,
    required this.noteLocked,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          "Listening...",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _VocalGauge(
              currentPitch: currentPitch,
              lowestPitch: pitchService.getPitchFromNote(lowestNote),
              highestPitch: pitchService.getPitchFromNote(highestNote),
            ),
          ),
        ),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: noteLocked ? FontWeight.w900 : FontWeight.bold,
            color: noteLocked ? theme.colorScheme.secondary : theme.colorScheme.onSurface,
          ),
          child: Text(currentNote.isEmpty ? '--' : currentNote),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RangeDisplay(label: "Lowest", note: lowestNote),
            _RangeDisplay(label: "Highest", note: highestNote),
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Finish'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ResultsView extends StatelessWidget {
  final String lowestNote;
  final String highestNote;
  final String voiceType;
  final VoidCallback onTryAgain;

  const _ResultsView({
    required this.lowestNote,
    required this.highestNote,
    required this.voiceType,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(l10n.yourResults, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Text(l10n.vocalRange.toUpperCase(), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey, letterSpacing: 1)),
                  Text(
                      (lowestNote.isEmpty || highestNote.isEmpty) ? 'N/A' : '$lowestNote - $highestNote',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.probableVoiceType.toUpperCase(), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey, letterSpacing: 1)),
                  Text(voiceType, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text(l10n.voiceTypeDisclaimer, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: onTryAgain,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
        ],
      ),
    );
  }
}

class _RangeDisplay extends StatelessWidget {
  final String label;
  final String note;

  const _RangeDisplay({required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(note.isEmpty ? '--' : note, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _VocalGauge extends StatefulWidget {
  final double currentPitch;
  final double lowestPitch;
  final double highestPitch;

  const _VocalGauge({
    required this.currentPitch,
    required this.lowestPitch,
    required this.highestPitch,
  });

  @override
  State<_VocalGauge> createState() => _VocalGaugeState();
}

class _VocalGaugeState extends State<_VocalGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(covariant _VocalGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPitch != oldWidget.currentPitch) {
      final targetAngle = _pitchToAngle(widget.currentPitch);
      _controller.animateTo(targetAngle, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pitchToAngle(double pitch) {
    const minPitch = 80.0;
    const maxPitch = 1050.0;
    if (pitch <= minPitch) return 0.0;
    if (pitch > maxPitch) return 1.0;
    final double logMin = log(minPitch);
    final double logMax = log(maxPitch);
    final double logPitch = log(pitch);
    return (logPitch - logMin) / (logMax - logMin);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VocalGaugePainter(
        needleAnimation: _controller,
        lowestPitchAngle: _pitchToAngle(widget.lowestPitch),
        highestPitchAngle: _pitchToAngle(widget.highestPitch),
        theme: Theme.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _VocalGaugePainter extends CustomPainter {
  final Animation<double> needleAnimation;
  final double lowestPitchAngle;
  final double highestPitchAngle;
  final ThemeData theme;

  _VocalGaugePainter({
    required this.needleAnimation,
    required this.lowestPitchAngle,
    required this.highestPitchAngle,
    required this.theme,
  }) : super(repaint: needleAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    const startAngle = -pi * 1.25;
    const sweepAngle = pi * 1.5;

    final backgroundPaint = Paint()
      ..color = theme.colorScheme.surfaceVariant.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, backgroundPaint);

    if (lowestPitchAngle > 0 && highestPitchAngle > lowestPitchAngle) {
      final rangePaint = Paint()
        ..shader = LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      final rangeStartAngle = startAngle + lowestPitchAngle * sweepAngle;
      final rangeSweepAngle = (highestPitchAngle - lowestPitchAngle) * sweepAngle;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), rangeStartAngle, rangeSweepAngle, false, rangePaint);
    }

    final needleAngle = startAngle + needleAnimation.value * sweepAngle;
    final needlePaint = Paint()..color = theme.colorScheme.primary..strokeWidth = 4..strokeCap = StrokeCap.round;
    final needleEnd = center + Offset(cos(needleAngle) * radius, sin(needleAngle) * radius);
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 8, needlePaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    const notes = {'C3': 130.8, 'G3': 196.0, 'C4': 261.6, 'G4': 392.0, 'C5': 523.3, 'G5': 784.0};

    for (var entry in notes.entries) {
      final noteAngleFraction = (log(entry.value) - log(80.0)) / (log(1050.0) - log(80.0));
      final angle = startAngle + noteAngleFraction * sweepAngle;

      final tickStart = center + Offset(cos(angle) * (radius - 10), sin(angle) * (radius - 10));
      final tickEnd = center + Offset(cos(angle) * (radius + 5), sin(angle) * (radius + 5));
      canvas.drawLine(tickStart, tickEnd, Paint()..color = Colors.grey..strokeWidth = 2);

      textPainter.text = TextSpan(text: entry.key, style: TextStyle(color: Colors.grey.shade600, fontSize: 12));
      textPainter.layout();
      final textOffset = center + Offset(cos(angle) * (radius + 20), sin(angle) * (radius + 20)) - Offset(textPainter.width/2, textPainter.height/2);
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}