import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:collection/collection.dart';

import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitchupdart/pitch_handler.dart';
import 'package:pitchupdart/pitch_result.dart';
import 'package:pitchupdart/instrument_type.dart'; // FIX: Add the required import

class VocalRangeFinder extends StatefulWidget {
  const VocalRangeFinder({super.key});

  @override
  State<VocalRangeFinder> createState() => _VocalRangeFinderState();
}

class _VocalRangeFinderState extends State<VocalRangeFinder> {
  // --- STATE VARIABLES ---
  bool _isRecording = false;
  String _statusMessage = "Tap 'Start' to find your vocal range";
  String _currentNote = "";
  String _lowestNote = "N/A";
  String _highestNote = "N/A";
  String _voiceType = "";

  final AudioRecorder _audioRecorder = AudioRecorder();

  late final PitchDetector _pitchDetector;
  late final PitchHandler _pitchHandler;

  StreamSubscription<List<int>>? _audioStreamSubscription;

  // --- STABILITY & RANGE TRACKING ---
  final List<double> _pitchBuffer = [];
  double _lowestFrequency = 20000.0;
  double _highestFrequency = 0.0;

  @override
  void initState() {
    super.initState();
    _pitchDetector = PitchDetector();
    // FIX: The constructor requires an InstrumentType, not a double.
    _pitchHandler = PitchHandler(InstrumentType.guitar);
  }

  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() => _statusMessage = "Microphone permission is required.");
      return;
    }

    setState(() {
      _isRecording = true;
      _statusMessage = "Sing your lowest note, then your highest...";
      _lowestNote = "N/A";
      _highestNote = "N/A";
      _voiceType = "";
      _lowestFrequency = 20000.0;
      _highestFrequency = 0.0;
    });

    try {
      final stream = await _audioRecorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 44100, numChannels: 1));

      _audioStreamSubscription = stream.listen((data) async {
        if (!_isRecording) return;
        final detectedPitch = await _pitchDetector.getPitchFromIntBuffer(data);

        if (detectedPitch.pitched) {
          final frequency = detectedPitch.pitch;
          final pitchResult = await _pitchHandler.handlePitch(frequency);

          _pitchBuffer.add(frequency);
          if (_pitchBuffer.length > 5) {
            final averagePitch = _pitchBuffer.average;
            final deviation = _pitchBuffer.map((p) => (p - averagePitch).abs()).average;
            if (deviation < 10) {
              await _updateRange(averagePitch);
            }
            _pitchBuffer.clear();
          }

          if (mounted) {
            setState(() {
              _currentNote = pitchResult.note;
            });
          }
        }
      });
    } catch (e) {
      print("Error starting stream: $e");
      await _stopRecording();
    }
  }

  Future<void> _stopRecording() async {
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _statusMessage = "Processing complete! Here's your result.";
        _voiceType = _classifyVoiceType();
      });
    }
  }

  Future<void> _updateRange(double stableFrequency) async {
    bool rangeUpdated = false;
    if (stableFrequency > 50 && stableFrequency < _lowestFrequency) {
      _lowestFrequency = stableFrequency;
      rangeUpdated = true;
    }
    if (stableFrequency > _highestFrequency) {
      _highestFrequency = stableFrequency;
      rangeUpdated = true;
    }

    if (rangeUpdated && mounted) {
      final PitchResult lowestResult = await _pitchHandler.handlePitch(_lowestFrequency);
      final PitchResult highestResult = await _pitchHandler.handlePitch(_highestFrequency);

      setState(() {
        _lowestNote = lowestResult.note;
        _highestNote = highestResult.note;
      });
    }
  }

  String _classifyVoiceType() {
    if (_lowestFrequency > 10000 || _highestFrequency == 0) {
      return "Could not determine range.";
    }

    final lowNoteMidi = _noteToMidi(_lowestNote);
    final highNoteMidi = _noteToMidi(_highestNote);

    if (lowNoteMidi >= 60 && highNoteMidi >= 84) return "Soprano";
    if (lowNoteMidi >= 57 && highNoteMidi >= 81) return "Mezzo-Soprano";
    if (lowNoteMidi >= 53 && highNoteMidi >= 77) return "Alto";
    if (lowNoteMidi >= 48 && highNoteMidi >= 72) return "Tenor";
    if (lowNoteMidi >= 41 && highNoteMidi >= 65) return "Baritone";
    if (lowNoteMidi >= 36 && highNoteMidi >= 64) return "Bass";

    return "Unique Range";
  }

  int _noteToMidi(String note) {
    if (note == "N/A") return 0;
    try {
      final Map<String, int> noteValues = {
        'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
        'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
      };
      final octave = int.parse(note.substring(note.length - 1));
      final noteName = note.substring(0, note.length - 1);
      return (octave + 1) * 12 + noteValues[noteName]!;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          Text(
            _isRecording ? _currentNote : _voiceType,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          _buildRangeDisplay(),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _toggleRecording,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              shape: const CircleBorder(),
              backgroundColor: _isRecording ? Colors.red : Colors.blue,
            ),
            child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 50, color: Colors.white,),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNoteBox("Lowest Note", _lowestNote),
        _buildNoteBox("Highest Note", _highestNote),
      ],
    );
  }

  Widget _buildNoteBox(String title, String note) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 8),
        Text(note, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
      ],
    );
  }
}