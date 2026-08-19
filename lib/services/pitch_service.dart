import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';
import '../utils/generated_tones.dart';

class PitchData {
  final double pitch;
  final String note;
  final double clarity;
  final double rms;
  
  PitchData({
    this.pitch = 0.0,
    this.note = '',
    this.clarity = 0.0,
    this.rms = 0.0,
  });

  bool get hasPitch => pitch > 0.0 && note.isNotEmpty;
}

class Note {
  final String name;
  final int octave;
  final double frequency;
  const Note({required this.name, required this.octave, required this.frequency});
}

class PitchService with ChangeNotifier {
  AudioRecorder? _audioRecorderInstance;
  AudioRecorder get _audioRecorder => _audioRecorderInstance ??= AudioRecorder();

  AudioPlayer? _soundPlayerInstance;
  AudioPlayer get _soundPlayer => _soundPlayerInstance ??= AudioPlayer();

  StreamSubscription<Uint8List>? _recordStreamSubscription;

  final List<int> _audioByteBuffer = [];
  // 4096 bytes = 2048 samples (PCM 16-bit mono)
  static const int _targetBytes = 4096;
  // 75% overlap for ultra-smooth ~23ms pitch refresh rate
  static const int _hopBytes = 1024;
  static const int _sampleRate = 44100;
  
  double _noiseFloor = 30.0;
  static const int _filterWindowSize = 3;
  final List<double> _pitchFilterBuffer = [];
  double _smoothedPitch = 0.0;

  PitchData _pitchData = PitchData();
  PitchData get pitchData => _pitchData;
  bool _isListening = false;
  bool get isListening => _isListening;

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
    if (_isListening || await _audioRecorder.isRecording()) {
      return true;
    }

    if (!await _audioRecorder.hasPermission()) {
      return false;
    }

    try {
      _audioByteBuffer.clear();
      _pitchFilterBuffer.clear();
      _smoothedPitch = 0.0;
      _noiseFloor = 30.0;

      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ));

      _isListening = true;
      _recordStreamSubscription = stream.listen((data) {
        _audioByteBuffer.addAll(data);

        while (_audioByteBuffer.length >= _targetBytes) {
          final chunkBytes = Uint8List.fromList(_audioByteBuffer.sublist(0, _targetBytes));
          // Hop forward with 75% overlap
          _audioByteBuffer.removeRange(0, _hopBytes);

          final rms = _calculateRMS(chunkBytes);
          
          // Adaptive smooth noise floor tracking
          if (rms < 50.0) {
            _noiseFloor = _noiseFloor * 0.96 + rms * 0.04;
          }
          final dynamicThreshold = max(25.0, _noiseFloor * 1.25);

          if (rms < dynamicThreshold) {
            if (_pitchData.pitch != 0.0) {
              _pitchData = PitchData(pitch: 0.0, note: '', clarity: 0.0, rms: rms);
              _pitchFilterBuffer.clear();
              _smoothedPitch = 0.0;
              notifyListeners();
            }
            continue;
          }

          try {
            // High-precision YIN+ Pitch Detector with subharmonic verification
            final result = detectPitchFromPcm16(chunkBytes, sampleRate: _sampleRate);

            if (result.pitch >= 40.0 && result.pitch <= 1500.0 && result.clarity >= 0.40) {
              _pitchFilterBuffer.add(result.pitch);
              if (_pitchFilterBuffer.length > _filterWindowSize) {
                _pitchFilterBuffer.removeAt(0);
              }

              // Median filter to eliminate transient spike noise
              final sortedPitches = List<double>.from(_pitchFilterBuffer)..sort();
              final medianPitch = sortedPitches[sortedPitches.length ~/ 2];

              // Exponential moving average for jitter-free pitch reading
              if (_smoothedPitch == 0.0 || (_smoothedPitch - medianPitch).abs() > 35.0) {
                _smoothedPitch = medianPitch;
              } else {
                _smoothedPitch = _smoothedPitch * 0.50 + medianPitch * 0.50;
              }

              final note = getNoteFromPitch(_smoothedPitch);
              if ((_pitchData.pitch - _smoothedPitch).abs() > 0.15 || _pitchData.note != note) {
                _pitchData = PitchData(
                  pitch: _smoothedPitch,
                  note: note,
                  clarity: result.clarity,
                  rms: rms,
                );
                notifyListeners();
              }
            } else {
              if (_pitchData.pitch != 0.0) {
                _pitchData = PitchData(pitch: 0.0, note: '', clarity: 0.0, rms: rms);
                _pitchFilterBuffer.clear();
                _smoothedPitch = 0.0;
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
      _isListening = false;
      return false;
    }
  }

  /// High-Precision YIN+ Pitch Detector with Harmonic Multi-tau Disambiguation
  /// Supports frequencies from 40 Hz (Low B / Drop D guitar / Bass) up to 1500 Hz (Soprano C6+)
  static PitchData detectPitchFromPcm16(Uint8List buffer, {int sampleRate = 44100}) {
    final samplesCount = buffer.length ~/ 2;
    if (samplesCount < 512) return PitchData();

    final byteData = ByteData.sublistView(buffer);
    final floats = Float64List(samplesCount);

    // Step 0: Convert 16-bit PCM Little Endian to normalized [-1.0, 1.0] floats & subtract DC offset
    double sum = 0.0;
    for (int i = 0; i < samplesCount; i++) {
      final rawSample = byteData.getInt16(i * 2, Endian.little);
      final val = rawSample / 32768.0;
      floats[i] = val;
      sum += val;
    }
    final double dcMean = sum / samplesCount;
    for (int i = 0; i < samplesCount; i++) {
      floats[i] -= dcMean;
    }

    final yinBufferSize = samplesCount ~/ 2;
    final yinBuffer = Float64List(yinBufferSize);

    // Step 1: Compute difference function d(tau) = sum((x[i] - x[i+tau])^2)
    for (int tau = 0; tau < yinBufferSize; tau++) {
      double diff = 0.0;
      for (int i = 0; i < yinBufferSize; i++) {
        final delta = floats[i] - floats[i + tau];
        diff += delta * delta;
      }
      yinBuffer[tau] = diff;
    }

    // Step 2: Cumulative Mean Normalized Difference Function (CMNDF)
    yinBuffer[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < yinBufferSize; tau++) {
      runningSum += yinBuffer[tau];
      if (runningSum > 0.00001) {
        yinBuffer[tau] *= tau / runningSum;
      } else {
        yinBuffer[tau] = 1.0;
      }
    }

    // Step 3: Absolute Thresholding & Peak Picking with Subharmonic Disambiguation
    // Limits for 40 Hz to 1500 Hz
    final int minTau = (sampleRate / 1500.0).floor().clamp(2, yinBufferSize - 1);
    final int maxTau = (sampleRate / 40.0).ceil().clamp(minTau + 1, yinBufferSize - 1);

    const double initialThreshold = 0.15;
    int tauEstimate = -1;
    double bestClarity = 0.0;

    // Collect all candidate local minima below threshold
    for (int tau = minTau; tau <= maxTau; tau++) {
      if (yinBuffer[tau] < initialThreshold) {
        while (tau + 1 <= maxTau && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }
        tauEstimate = tau;
        bestClarity = (1.0 - yinBuffer[tau]).clamp(0.0, 1.0);
        break;
      }
    }

    // Fallback: If strict threshold was not reached, find global minimum in range
    if (tauEstimate == -1) {
      double globalMin = double.infinity;
      int globalMinTau = -1;
      for (int tau = minTau; tau <= maxTau; tau++) {
        if (yinBuffer[tau] < globalMin) {
          globalMin = yinBuffer[tau];
          globalMinTau = tau;
        }
      }
      if (globalMin < 0.50 && globalMinTau != -1) {
        tauEstimate = globalMinTau;
        bestClarity = (1.0 - globalMin).clamp(0.0, 1.0);
      }
    }

    if (tauEstimate <= 0) return PitchData();

    // Step 3b: Subharmonic / Octave Error Disambiguation
    // Only promote to 2*tau if the first candidate was a partial harmonic dip (not ultra-low)
    // and the 2*tau dip is strictly significantly deeper than the candidate dip.
    final int doubleTau = tauEstimate * 2;
    if (doubleTau <= maxTau && yinBuffer[tauEstimate] > 0.06) {
      int searchStart = max(minTau, doubleTau - 3);
      int searchEnd = min(maxTau, doubleTau + 3);
      int subharmonicTau = -1;
      double subharmonicVal = double.infinity;

      for (int t = searchStart; t <= searchEnd; t++) {
        if (yinBuffer[t] < subharmonicVal) {
          subharmonicVal = yinBuffer[t];
          subharmonicTau = t;
        }
      }

      // If the subharmonic has significantly deeper correlation than candidate
      if (subharmonicTau != -1 &&
          subharmonicVal < yinBuffer[tauEstimate] * 0.80 &&
          subharmonicVal < 0.25) {
        tauEstimate = subharmonicTau;
        bestClarity = (1.0 - subharmonicVal).clamp(0.0, 1.0);
      }
    }

    // Step 4: Sub-cent Parabolic Interpolation on the chosen minimum
    final int x0 = (tauEstimate > 0) ? tauEstimate - 1 : tauEstimate;
    final int x2 = (tauEstimate + 1 < yinBufferSize) ? tauEstimate + 1 : tauEstimate;

    double refinedTau = tauEstimate.toDouble();
    if (x0 != tauEstimate && x2 != tauEstimate) {
      final s0 = yinBuffer[x0];
      final s1 = yinBuffer[tauEstimate];
      final s2 = yinBuffer[x2];
      final denominator = 2.0 * (2.0 * s1 - s2 - s0);
      if (denominator.abs() > 1e-6) {
        refinedTau = tauEstimate + (s2 - s0) / denominator;
      }
    }

    if (refinedTau <= 0) return PitchData();

    final pitch = sampleRate / refinedTau;
    if (pitch < 40.0 || pitch > 1500.0) return PitchData();

    return PitchData(pitch: pitch, clarity: bestClarity);
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
    _isListening = false;
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
    _smoothedPitch = 0.0;
    _pitchData = PitchData();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    _audioRecorderInstance?.dispose();
    _soundPlayerInstance?.dispose();
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
    const notes = {
      'C': 0, 'C#': 1, 'Db': 1,
      'D': 2, 'D#': 3, 'Eb': 3,
      'E': 4,
      'F': 5, 'F#': 6, 'Gb': 6,
      'G': 7, 'G#': 8, 'Ab': 8,
      'A': 9, 'A#': 10, 'Bb': 10,
      'B': 11,
    };
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

  /// Calculates cents difference between target and detected pitch:
  /// cents = 1200 * log2(userPitch / targetPitch)
  double getCentsDifference(double targetPitch, double userPitch) {
    if (targetPitch <= 0 || userPitch <= 0) return 0.0;
    return 1200 * (log(userPitch / targetPitch) / log(2.0));
  }

  /// Octave-wrapped cents difference (e.g. for auto-transposed vocal pitch training)
  /// Returns nearest octave cents difference in range [-600, +600]
  double getOctaveWrappedCentsDifference(double targetPitch, double userPitch) {
    if (targetPitch <= 0 || userPitch <= 0) return 0.0;
    final rawCents = getCentsDifference(targetPitch, userPitch);
    return ((rawCents + 600) % 1200) - 600;
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