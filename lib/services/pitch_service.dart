import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

class PitchService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PitchDetector _pitchDetector = PitchDetector();
  StreamSubscription<Uint8List>? _recordStreamSubscription;

  bool get isRecording => _recordStreamSubscription != null && !_recordStreamSubscription!.isPaused;

  Future<bool> startListening(Function(double pitch) onData) async {
    await stopListening();

    if (!await _audioRecorder.hasPermission()) {
      debugPrint("Microphone permission not granted.");
      return false;
    }

    final stream = await _audioRecorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100,
      numChannels: 1,
    ));

    _recordStreamSubscription = stream.listen((data) async {
      final result = await _pitchDetector.getPitchFromIntBuffer(data);
      if (result.pitched) {
        onData(result.pitch);
      }
    });

    return true;
  }

  Future<void> stopListening() async {
    // FIXED: Add safety check
    if (_recordStreamSubscription == null) return;
    await _recordStreamSubscription?.cancel();
    _recordStreamSubscription = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
  }

  void dispose() {
    stopListening();
    _audioRecorder.dispose();
  }

  String getNoteFromPitch(double pitch) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    if (pitch <= 0) return '';

    var semiTone = (12 * (log(pitch / 440) / log(2))).round();
    var noteIndex = (semiTone + 69 + 12) % 12;
    var octave = ((semiTone + 69) / 12).floor();

    return '${notes[noteIndex]}$octave';
  }

  double getPitchFromNote(String note) {
    const notes = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11};
    if (note.length < 2) return 0.0;
    try {
      final octave = int.parse(note.substring(note.length - 1));
      final key = note.substring(0, note.length - 1);
      if (!notes.containsKey(key)) return 0.0;

      final semiTone = notes[key]! - 9 + (octave - 4) * 12;
      return 440 * pow(2, semiTone / 12).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  double getCentsDifference(double targetPitch, double userPitch) {
    if (targetPitch <= 0 || userPitch <= 0) return 0;
    return 1200 * log(userPitch / targetPitch) / log(2);
  }

  String getVoiceType(String lowestNote, String highestNote) {
    if (lowestNote.isEmpty || highestNote.isEmpty) return 'Unknown';

    final lowPitch = getPitchFromNote(lowestNote);
    final highPitch = getPitchFromNote(highestNote);

    if (lowPitch == 0 || highPitch == 0) return 'Unknown';
    if (highPitch < 261) return 'Contralto / Bass';
    if (lowPitch >= 220 && highPitch >= 880) return 'Soprano';
    if (lowPitch >= 174 && highPitch >= 698) return 'Mezzo-Soprano';
    if (lowPitch >= 146 && highPitch >= 587) return 'Contralto';
    if (lowPitch >= 110 && highPitch >= 440) return 'Tenor';
    if (lowPitch >= 82 && highPitch >= 330) return 'Baritone';
    if (lowPitch >= 65 && highPitch >= 261) return 'Bass';

    return 'Unique Range';
  }
}