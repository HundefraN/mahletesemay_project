import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/services/pitch_service.dart';
import 'package:mahlete_semay_project/utils/generated_tones.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

enum TrainerState { idle, playing, listening, finished }

class PitchTrainerScreen extends StatefulWidget {
  const PitchTrainerScreen({super.key});

  @override
  State<PitchTrainerScreen> createState() => _PitchTrainerScreenState();
}

class _PitchTrainerScreenState extends State<PitchTrainerScreen> {
  late final PitchService _pitchService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  TrainerState _state = TrainerState.idle;
  final List<String> _targetNotes = ['C4', 'E4', 'G4', 'A4', 'C5'];
  int _currentNoteIndex = 3;
  String get _targetNote => _targetNotes[_currentNoteIndex];

  double _centsDifference = 0.0;
  Timer? _inTuneTimer;
  double _inTuneProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _pitchService = Provider.of<PitchService>(context, listen: false);
    _pitchService.addListener(_onPitchChanged);
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
    super.dispose();
  }

  void _onPitchChanged() {
    if (!mounted || _state != TrainerState.listening) return;

    final pitchData = _pitchService.pitchData;
    if (pitchData.pitch == 0.0) return;

    final targetPitch = _pitchService.getPitchFromNote(_targetNote);
    final cents = _pitchService.getCentsDifference(targetPitch, pitchData.pitch);

    setState(() => _centsDifference = cents);

    if (cents.abs() < 15) {
      if (_inTuneTimer == null || !_inTuneTimer!.isActive) {
        _inTuneTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() => _inTuneProgress = (_inTuneProgress + 0.025).clamp(0.0, 1.0));

          if (_inTuneProgress >= 1.0) {
            _finishPractice();
          }
        });
      }
    } else {
      _inTuneTimer?.cancel();
      if (mounted && _inTuneProgress > 0) {
        setState(() => _inTuneProgress = (_inTuneProgress - 0.05).clamp(0.0, 1.0));
      }
    }
  }

  void _startPractice() async {
    _reset(keepState: true);
    setState(() => _state = TrainerState.playing);

    final toneData = GeneratedTones.getTone(_targetNote);
    if (toneData != null) {
      await _audioPlayer.play(BytesSource(toneData));
    } else {
      _reset();
    }
  }

  void _startListeningForMatch() async {
    setState(() => _state = TrainerState.listening);
    final hasPermission = await _pitchService.startListening();
    if (!hasPermission && mounted) {
      CustomSnackbar.show(context, 'Microphone permission is needed.', isError: true);
      openAppSettings();
      _reset();
    }
  }

  void _finishPractice() {
    _inTuneTimer?.cancel();
    _pitchService.stopListening();
    if (mounted) {
      setState(() => _state = TrainerState.finished);
    }
  }

  void _reset({bool keepState = false}) {
    _inTuneTimer?.cancel();
    _pitchService.stopListening();
    _audioPlayer.stop();
    if (mounted) {
      setState(() {
        if (!keepState) _state = TrainerState.idle;
        _centsDifference = 0;
        _inTuneProgress = 0;
      });
    }
  }

  void _changeNote(int delta) {
    if (_state == TrainerState.idle) {
      setState(() {
        _currentNoteIndex = (_currentNoteIndex + delta).clamp(0, _targetNotes.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pitch Trainer')),
      body: Center(
        child: Column(
          children: [
            const Spacer(),
            _buildInstructionWidget(),
            const SizedBox(height: 30),
            _buildNoteSelector(),
            const SizedBox(height: 30),
            _buildPitchVisualizer(theme),
            const SizedBox(height: 20),
            Text(
              '${_centsDifference.toStringAsFixed(1)} cents',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const Spacer(),
            _buildControlButton(),
            const SizedBox(height: 50),
          ],
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }

  Widget _buildInstructionWidget() {
    String text;
    IconData icon;
    Color color;

    switch (_state) {
      case TrainerState.playing:
        text = 'Listen...';
        icon = Icons.hearing;
        color = Colors.blue;
        break;
      case TrainerState.listening:
        text = 'Now, Match the Note!';
        icon = Icons.mic;
        color = Colors.green;
        break;
      case TrainerState.finished:
        text = 'Perfect Match!';
        icon = Icons.check_circle;
        color = Colors.amber;
        break;
      case TrainerState.idle:
      default:
        text = 'Select a Note and Press Start';
        icon = Icons.music_note;
        color = Theme.of(context).colorScheme.primary;
        break;
    }
    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 8),
        Text(text, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildNoteSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left_rounded),
          iconSize: 40,
          onPressed: _currentNoteIndex > 0 && _state == TrainerState.idle ? () => _changeNote(-1) : null,
        ),
        const SizedBox(width: 20),
        Text(
          _targetNote,
          style: GoogleFonts.poppins(fontSize: 64, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.arrow_right_rounded),
          iconSize: 40,
          onPressed: _currentNoteIndex < _targetNotes.length - 1 && _state == TrainerState.idle ? () => _changeNote(1) : null,
        ),
      ],
    );
  }

  Widget _buildPitchVisualizer(ThemeData theme) {
    return SizedBox(
      width: 280,
      height: 100,
      child: CustomPaint(
        painter: _PitchVisualizerPainter(
          centsDifference: _centsDifference,
          inTuneProgress: _inTuneProgress,
          theme: theme,
        ),
      ),
    );
  }

  Widget _buildControlButton() {
    String text;
    IconData icon;
    VoidCallback? onPressed;
    Color color = Theme.of(context).colorScheme.primary;

    switch (_state) {
      case TrainerState.idle:
        text = 'Start';
        icon = Icons.play_arrow;
        onPressed = _startPractice;
        break;
      case TrainerState.playing:
      case TrainerState.listening:
        text = 'Stop';
        icon = Icons.stop;
        onPressed = _reset;
        color = Colors.red;
        break;
      case TrainerState.finished:
        text = 'Practice Again';
        icon = Icons.refresh;
        onPressed = _reset;
        color = Colors.green;
        break;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

class _PitchVisualizerPainter extends CustomPainter {
  final double centsDifference;
  final double inTuneProgress;
  final ThemeData theme;

  _PitchVisualizerPainter({
    required this.centsDifference,
    required this.inTuneProgress,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = theme.colorScheme.surfaceVariant
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2)), trackPaint);

    if(inTuneProgress > 0) {
      final progressPaint = Paint()
        ..color = Colors.amber;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width * inTuneProgress, size.height), Radius.circular(size.height / 2)), progressPaint);
    }

    final inTuneZonePaint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 40, height: size.height), Radius.circular(size.height / 2)), inTuneZonePaint);

    final double maxOffset = size.width / 2;
    final double offset = (centsDifference.clamp(-50, 50) / 50.0) * maxOffset;

    final indicatorPaint = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.fill;

    final indicatorPath = Path()
      ..moveTo(center.dx + offset, 10)
      ..lineTo(center.dx + offset - 8, size.height - 10)
      ..lineTo(center.dx + offset + 8, size.height - 10)
      ..close();

    canvas.drawPath(indicatorPath, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant _PitchVisualizerPainter oldDelegate) {
    return oldDelegate.centsDifference != centsDifference || oldDelegate.inTuneProgress != inTuneProgress;
  }
}