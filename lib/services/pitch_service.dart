import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import '../utils/constants.dart';

class PitchData {
  final double pitch;
  final String note;
  PitchData({this.pitch = 0.0, this.note = ''});
}

class Note {
  final String name;
  final int octave;
  final double frequency;
  const Note({required this.name, required this.octave, required this.frequency});
}

class PitchService with ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PitchDetector _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 2048);
  StreamSubscription<Uint8List>? _recordStreamSubscription;

  PitchData _pitchData = PitchData();
  PitchData get pitchData => _pitchData;

  Future<bool> startListening() async {
    if (await _audioRecorder.isRecording()) {
      return true;
    }

    if (!await _audioRecorder.hasPermission()) {
      return false;
    }

    try {
      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ));

      _recordStreamSubscription = stream.listen((data) async {
        final result = await _pitchDetector.getPitchFromIntBuffer(data);

        if (result.pitched && result.pitch > 50.0 && result.pitch < 2000.0) {
          final note = getNoteFromPitch(result.pitch);
          if (_pitchData.pitch != result.pitch) {
            _pitchData = PitchData(pitch: result.pitch, note: note);
            notifyListeners();
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint("PitchService: Error starting audio stream: $e");
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_recordStreamSubscription == null) return;
    await _recordStreamSubscription?.cancel();
    _recordStreamSubscription = null;
    if (await _audioRecorder.isRecording()) {
      try {
        await _audioRecorder.stop();
      } catch (e) {
        debugPrint("PitchService: Error stopping recorder: $e");
      }
    }
    _pitchData = PitchData();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    _audioRecorder.dispose();
    super.dispose();
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
    if (lowPitch == 0 || highPitch == 0 || highPitch <= lowPitch) return 'Could not determine.';

    for (final range in voiceTypeRanges) {
      if (lowPitch >= range.lowPitch && highPitch >= range.highPitch) {
        return range.name;
      }
    }
    return 'Unique Range';
  }
}