import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/services/pitch_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';

enum TrainerState { idle, playing, listening, finished }

class PitchTrainerScreen extends StatefulWidget {
  const PitchTrainerScreen({super.key});

  @override
  State<PitchTrainerScreen> createState() => _PitchTrainerScreenState();
}

class _PitchTrainerScreenState extends State<PitchTrainerScreen> {
  final PitchService _pitchService = PitchService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  TrainerState _state = TrainerState.idle;
  String _targetNote = 'A4';
  double _centsDifference = 0.0;
  int _inTuneDuration = 0;
  Timer? _inTuneTimer;

  @override
  void dispose() {
    _pitchService.stopListening();
    _audioPlayer.dispose();
    _inTuneTimer?.cancel();
    super.dispose();
  }

  void _startPractice() async {
    setState(() {
      _state = TrainerState.playing;
      _centsDifference = 0.0;
      _inTuneDuration = 0;
    });

    try {
      // In a real app, you would generate a sine wave here.
      // For now, we'll just simulate a delay.
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _state = TrainerState.listening;
      });

      await _pitchService.startListening((pitch) {
        if (!mounted || _state != TrainerState.listening) return;

        final targetPitch = _pitchService.getPitchFromNote(_targetNote);
        final cents = _pitchService.getCentsDifference(targetPitch, pitch);

        setState(() {
          _centsDifference = cents;
        });

        if (cents.abs() < 25) { // In tune threshold
          if (_inTuneTimer == null || !_inTuneTimer!.isActive) {
            _inTuneTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
              if (!mounted) {
                timer.cancel();
                return;
              }
              setState(() {
                _inTuneDuration += 100;
              });

              if (_inTuneDuration >= 2000) { // Hold for 2 seconds
                _finishPractice();
              }
            });
          }
        } else {
          _inTuneTimer?.cancel();
          if (mounted) {
            setState(() {
              _inTuneDuration = 0;
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Error starting practice: $e', isError: true);
        _reset();
      }
    }
  }

  void _finishPractice() {
    _inTuneTimer?.cancel();
    _pitchService.stopListening();
    if (mounted) {
      setState(() {
        _state = TrainerState.finished;
      });
    }
  }

  void _reset() {
    _inTuneTimer?.cancel();
    _pitchService.stopListening();
    if (mounted) {
      setState(() {
        _state = TrainerState.idle;
        _centsDifference = 0;
        _inTuneDuration = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pitch Trainer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInstructionWidget(),
            _buildPitchIndicator(),
            _buildControlButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionWidget() {
    String text;
    switch (_state) {
      case TrainerState.idle:
        text = 'Press Start to practice matching the note';
        break;
      case TrainerState.playing:
        text = 'Listen for the target note...';
        break;
      case TrainerState.listening:
        text = 'Now, match the note!';
        break;
      case TrainerState.finished:
        text = 'Great job!';
        break;
    }
    return Text(text, style: Theme.of(context).textTheme.headlineSmall);
  }

  Widget _buildPitchIndicator() {
    return Column(
      children: [
        Text(_targetNote, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(
          width: 250,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.green, Colors.red],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                left: (_centsDifference.clamp(-50, 50) + 50) / 100 * 230 - 10,
                child: Container(
                  width: 20,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('${_centsDifference.toStringAsFixed(1)} cents'),
        const SizedBox(height: 20),
        SizedBox(
          width: 250,
          child: LinearProgressIndicator(
            value: _inTuneDuration / 2000,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton() {
    String text;
    IconData icon;
    VoidCallback? onPressed;

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
        break;
      case TrainerState.finished:
        text = 'Practice Again';
        icon = Icons.refresh;
        onPressed = _reset;
        break;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        textStyle: const TextStyle(fontSize: 18),
      ),
    );
  }
}