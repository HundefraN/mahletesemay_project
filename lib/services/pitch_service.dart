import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';
import '../utils/generated_tones.dart';

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
  final AudioPlayer _soundPlayer = AudioPlayer();
  StreamSubscription<Uint8List>? _recordStreamSubscription;

  final List<int> _audioByteBuffer = [];
  static const int _targetBytes = 4096; // 2048 samples * 2 bytes/sample (PCM 16-bit)
  
  double _adaptiveNoiseFloor = 60.0;
  static const int _filterWindowSize = 5;
  final List<double> _pitchFilterBuffer = [];

  PitchData _pitchData = PitchData();
  PitchData get pitchData => _pitchData;

  /// Plays a synthesized audio beep tuned to the exact pitch frequency.
  Future<void> playPitchBeep(double frequency) async {
    try {
      final wavData = GeneratedTones.getPitchBeepTone(frequency);
      await _soundPlayer.stop();
      await _soundPlayer.play(BytesSource(wavData));
    } catch (e) {
      debugPrint("PitchService: Error playing pitch beep sound: $e");
    }
  }

  /// Plays a synthesized audio beep tuned to the pitch of a specific musical note.
  Future<void> playNoteBeep(String note) async {
    try {
      final wavData = GeneratedTones.getNoteBeepTone(note);
      await _soundPlayer.stop();
      await _soundPlayer.play(BytesSource(wavData));
    } catch (e) {
      debugPrint("PitchService: Error playing note beep sound: $e");
    }
  }

  /// Plays synthesized success chime audio tone (E5-G#5-B5-E6 flourish)
  Future<void> playSuccessBeep() async {
    try {
      final wavData = GeneratedTones.getSuccessBeepTone();
      await _soundPlayer.stop();
      await _soundPlayer.play(BytesSource(wavData));
    } catch (e) {
      debugPrint("PitchService: Error playing success chime sound: $e");
    }
  }

  /// Plays synthesized lock note confirmation sound (dual pitch ping)
  Future<void> playLockNoteBeep() async {
    try {
      final wavData = GeneratedTones.getLockNoteBeepTone();
      await _soundPlayer.stop();
      await _soundPlayer.play(BytesSource(wavData));
    } catch (e) {
      debugPrint("PitchService: Error playing lock note sound: $e");
    }
  }

  Future<bool> startListening() async {
    if (await _audioRecorder.isRecording()) {
      return true;
    }

    if (!await _audioRecorder.hasPermission()) {
      return false;
    }

    try {
      _audioByteBuffer.clear();
      _pitchFilterBuffer.clear();

      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ));

      _recordStreamSubscription = stream.listen((data) async {
        _audioByteBuffer.addAll(data);

        while (_audioByteBuffer.length >= _targetBytes) {
          final chunkBytes = Uint8List.fromList(_audioByteBuffer.sublist(0, _targetBytes));
          _audioByteBuffer.removeRange(0, _targetBytes);

          final rms = _calculateRMS(chunkBytes);
          
          // Adaptive Noise Gate Floor
          if (rms < 120.0) {
            _adaptiveNoiseFloor = _adaptiveNoiseFloor * 0.9 + rms * 0.1;
          }
          final dynamicThreshold = max(60.0, _adaptiveNoiseFloor * 1.6);

          if (rms < dynamicThreshold) {
            if (_pitchData.pitch != 0.0) {
              _pitchData = PitchData(pitch: 0.0, note: '');
              _pitchFilterBuffer.clear();
              notifyListeners();
            }
            continue;
          }

          try {
            // High precision pitch estimation using McLeod Autocorrelation + Parabolic Interpolation
            double detectedPitch = _detectPitchMcLeod(chunkBytes);

            // Fallback to pitch_detector_dart if McLeod NSDF peak was inconclusive
            if (detectedPitch <= 0.0) {
              final result = await _pitchDetector.getPitchFromIntBuffer(chunkBytes);
              if (result.pitched && result.pitch >= 55.0 && result.pitch <= 1400.0) {
                detectedPitch = result.pitch;
              }
            }

            if (detectedPitch >= 55.0 && detectedPitch <= 1400.0) {
              _pitchFilterBuffer.add(detectedPitch);
              if (_pitchFilterBuffer.length > _filterWindowSize) {
                _pitchFilterBuffer.removeAt(0);
              }

              // Median filter to eliminate transient spikes
              final sortedPitches = List<double>.from(_pitchFilterBuffer)..sort();
              final medianPitch = sortedPitches[sortedPitches.length ~/ 2];

              final note = getNoteFromPitch(medianPitch);
              if ((_pitchData.pitch - medianPitch).abs() > 0.3 || _pitchData.note != note) {
                _pitchData = PitchData(pitch: medianPitch, note: note);
                notifyListeners();
              }
            }
          } catch (e) {
            debugPrint("PitchService: Pitch detection exception: $e");
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint("PitchService: Error starting audio stream: $e");
      return false;
    }
  }

  /// McLeod / NSDF (Normalized Square Difference Function) Pitch Detection with Parabolic Interpolation
  double _detectPitchMcLeod(Uint8List buffer, {int sampleRate = 44100}) {
    final samplesCount = buffer.length ~/ 2;
    if (samplesCount < 512) return 0.0;

    final byteData = ByteData.sublistView(buffer);
    final floats = Float64List(samplesCount);

    // Apply Hanning Window to eliminate spectral leakage & boundary discontinuities
    for (int i = 0; i < samplesCount; i++) {
      final rawSample = byteData.getInt16(i * 2, Endian.little);
      final normSample = rawSample / 32768.0;
      final hanningWindow = 0.5 * (1.0 - cos(2.0 * pi * i / (samplesCount - 1)));
      floats[i] = normSample * hanningWindow;
    }

    final minLag = (sampleRate / 1400.0).floor().clamp(15, samplesCount ~/ 4);
    final maxLag = (sampleRate / 55.0).ceil().clamp(minLag + 5, samplesCount ~/ 2);

    final nsdf = Float64List(maxLag + 1);

    for (int lag = minLag; lag <= maxLag; lag++) {
      double num = 0.0;
      double den1 = 0.0;
      double den2 = 0.0;

      for (int i = 0; i < samplesCount - lag; i++) {
        final x1 = floats[i];
        final x2 = floats[i + lag];
        num += x1 * x2;
        den1 += x1 * x1;
        den2 += x2 * x2;
      }

      final den = den1 + den2;
      if (den > 0.00001) {
        nsdf[lag] = 2.0 * num / den;
      } else {
        nsdf[lag] = 0.0;
      }
    }

    double maxVal = -1.0;
    const double clarityThreshold = 0.42;
    List<int> peakIndices = [];

    for (int lag = minLag + 1; lag < maxLag; lag++) {
      if (nsdf[lag] > nsdf[lag - 1] && nsdf[lag] >= nsdf[lag + 1]) {
        if (nsdf[lag] > maxVal) {
          maxVal = nsdf[lag];
        }
        if (nsdf[lag] >= clarityThreshold) {
          peakIndices.add(lag);
        }
      }
    }

    if (peakIndices.isEmpty || maxVal < clarityThreshold) {
      return 0.0;
    }

    // Select fundamental peak to avoid octave errors
    int chosenLag = peakIndices.first;
    for (final idx in peakIndices) {
      if (nsdf[idx] >= maxVal * 0.85) {
        chosenLag = idx;
        break;
      }
    }

    // Parabolic Peak Interpolation
    final alpha = nsdf[chosenLag - 1];
    final beta = nsdf[chosenLag];
    final gamma = nsdf[chosenLag + 1];

    final denominator = 2.0 * (2.0 * beta - alpha - gamma);
    double delta = 0.0;
    if (denominator.abs() > 1e-6) {
      delta = (gamma - alpha) / denominator;
    }

    final refinedLag = chosenLag + delta;
    if (refinedLag <= 0) return 0.0;

    final pitch = sampleRate / refinedLag;
    if (pitch < 55.0 || pitch > 1400.0) return 0.0;

    return pitch;
  }

  double _calculateRMS(Uint8List buffer) {
    if (buffer.length < 2) return 0.0;
    double sumSquares = 0;
    final samplesCount = buffer.length ~/ 2;
    final byteData = ByteData.sublistView(buffer);

    for (int i = 0; i < buffer.length - 1; i += 2) {
      final sample = byteData.getInt16(i, Endian.little);
      sumSquares += sample * sample;
    }
    return sqrt(sumSquares / samplesCount);
  }

  Future<void> stopListening() async {
    if (_recordStreamSubscription != null) {
      await _recordStreamSubscription?.cancel();
      _recordStreamSubscription = null;
    }
    if (await _audioRecorder.isRecording()) {
      try {
        await _audioRecorder.stop();
      } catch (e) {
        debugPrint("PitchService: Error stopping recorder: $e");
      }
    }
    _audioByteBuffer.clear();
    _pitchFilterBuffer.clear();
    _pitchData = PitchData();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    _audioRecorder.dispose();
    _soundPlayer.dispose();
    super.dispose();
  }

  /// Calculates musical note from pitch frequency using standard MIDI reference
  /// (A4 = 440Hz -> MIDI 69, C4 = Middle C = MIDI 60).
  String getNoteFromPitch(double pitch) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    if (pitch <= 0 || pitch.isNaN || pitch.isInfinite) return '';

    final midiDouble = 69 + 12 * (log(pitch / 440.0) / log(2.0));
    final midiNote = midiDouble.round();

    if (midiNote < 0) return '';
    final noteIndex = (midiNote % 12 + 12) % 12;
    final octave = (midiNote ~/ 12) - 1;
    return '${notes[noteIndex]}$octave';
  }

  double getPitchFromNote(String note) {
    const notes = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11};
    if (note.length < 2) return 0.0;
    try {
      final octaveStr = note.substring(note.length - 1);
      final key = note.substring(0, note.length - 1);
      if (!notes.containsKey(key)) return 0.0;
      final octave = int.parse(octaveStr);
      final midiNote = (octave + 1) * 12 + notes[key]!;
      return 440.0 * pow(2.0, (midiNote - 69) / 12.0);
    } catch (e) {
      return 0.0;
    }
  }

  double getCentsDifference(double targetPitch, double userPitch) {
    if (targetPitch <= 0 || userPitch <= 0) return 0.0;
    return 1200 * (log(userPitch / targetPitch) / log(2.0));
  }

  String getVoiceType(String lowestNote, String highestNote) {
    final voiceRange = getVoiceTypeRange(lowestNote, highestNote);
    return voiceRange?.name ?? 'Unique Range';
  }

  VoiceTypeRange? getVoiceTypeRange(String lowestNote, String highestNote) {
    if (lowestNote.isEmpty || highestNote.isEmpty) return null;
    final lowPitch = getPitchFromNote(lowestNote);
    final highPitch = getPitchFromNote(highestNote);
    if (lowPitch <= 0 || highPitch <= 0 || highPitch <= lowPitch) return null;

    final userCenterLog = sqrt(lowPitch * highPitch);

    VoiceTypeRange? bestMatch;
    double minDistance = double.infinity;

    for (final range in voiceTypeRanges) {
      final rangeCenterLog = sqrt(range.lowPitch * range.highPitch);
      final dist = (log(userCenterLog) - log(rangeCenterLog)).abs();
      if (dist < minDistance) {
        minDistance = dist;
        bestMatch = range;
      }
    }
    return bestMatch;
  }

  String getVocalRangeSpan(String lowestNote, String highestNote) {
    final lowPitch = getPitchFromNote(lowestNote);
    final highPitch = getPitchFromNote(highestNote);
    if (lowPitch <= 0 || highPitch <= 0 || highPitch <= lowPitch) return 'N/A';

    final semitones = (12 * (log(highPitch / lowPitch) / log(2.0))).round();
    final octaves = semitones ~/ 12;
    final remainingSemitones = semitones % 12;

    if (octaves == 0) {
      return '$semitones Semitones';
    } else if (remainingSemitones == 0) {
      return '$octaves Octave${octaves > 1 ? 's' : ''} ($semitones Semitones)';
    } else {
      return '$octaves Octave${octaves > 1 ? 's' : ''}, $remainingSemitones Semitone${remainingSemitones > 1 ? 's' : ''} ($semitones Semitones)';
    }
  }
}