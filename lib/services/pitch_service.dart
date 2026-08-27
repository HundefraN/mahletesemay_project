import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';
import '../utils/generated_tones.dart';

/// Holds real-time pitch, note, clarity, RMS volume, and audio waveform data.
class PitchData {
  final double pitch;
  final String note;
  final double clarity;
  final double rms;
  final Float64List? waveform;

  PitchData({
    this.pitch = 0.0,
    this.note = '',
    this.clarity = 0.0,
    this.rms = 0.0,
    this.waveform,
  });

  bool get hasPitch => pitch > 0.0 && note.isNotEmpty;
}

class Note {
  final String name;
  final int octave;
  final double frequency;
  const Note({required this.name, required this.octave, required this.frequency});
}

/// Professional Audio & Pitch Detection Engine powered by McLeod Pitch Method (MPM)
/// and Normalized Square Difference Function (NSDF) with subharmonic disambiguation.
class PitchService with ChangeNotifier {
  AudioRecorder? _audioRecorderInstance;
  AudioRecorder get _audioRecorder => _audioRecorderInstance ??= AudioRecorder();

  AudioPlayer? _soundPlayerInstance;
  AudioPlayer get _soundPlayer => _soundPlayerInstance ??= AudioPlayer();

  StreamSubscription<Uint8List>? _recordStreamSubscription;

  final List<int> _audioByteBuffer = [];
  // 4096 bytes = 2048 samples (PCM 16-bit mono at 44.1 kHz)
  static const int _targetBytes = 4096;
  // 1024 bytes hop = 512 samples (~11.6ms refresh rate with 75% overlap)
  static const int _hopBytes = 1024;
  static const int _sampleRate = 44100;
  
  double _noiseFloor = 25.0;
  static const int _filterWindowSize = 3;
  final List<double> _pitchFilterBuffer = [];
  double _smoothedPitch = 0.0;

  PitchData _pitchData = PitchData();
  PitchData get pitchData => _pitchData;
  bool _isListening = false;
  bool get isListening => _isListening;

  /// Plays a synthesized audio tone tuned to the exact pitch frequency.
  Future<void> playPitchBeep(double frequency) async {
    try {
      final wavData = GeneratedTones.getPitchBeepTone(frequency);
      await _soundPlayer.stop();
      await _soundPlayer.play(BytesSource(wavData));
    } catch (e) {
      debugPrint("PitchService: Error playing pitch beep sound: $e");
    }
  }

  /// Plays a synthesized audio tone tuned to a specific musical note.
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

  /// Starts real-time microphone stream with zero-latency audio buffer processing.
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
      _noiseFloor = 25.0;

      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ));

      _isListening = true;
      _recordStreamSubscription = stream.listen((data) {
        _audioByteBuffer.addAll(data);

        // Anti-lag protection: If buffer accumulates more than 2 target frames (e.g. during heavy GC/UI frame),
        // keep only the newest window to guarantee instant real-time response.
        if (_audioByteBuffer.length > _targetBytes * 2) {
          final excess = _audioByteBuffer.length - _targetBytes;
          _audioByteBuffer.removeRange(0, excess);
        }

        while (_audioByteBuffer.length >= _targetBytes) {
          final chunkBytes = Uint8List.fromList(_audioByteBuffer.sublist(0, _targetBytes));
          _audioByteBuffer.removeRange(0, _hopBytes);

          final rms = _calculateRMS(chunkBytes);
          final waveform = _extractNormalizedWaveform(chunkBytes, pointCount: 96);
          
          // Adaptive smooth noise floor tracking
          if (rms < 45.0) {
            _noiseFloor = _noiseFloor * 0.95 + rms * 0.05;
          }
          final dynamicThreshold = max(20.0, _noiseFloor * 1.25);

          if (rms < dynamicThreshold) {
            if (_pitchData.pitch != 0.0 || _pitchData.rms != rms) {
              _pitchData = PitchData(
                pitch: 0.0,
                note: '',
                clarity: 0.0,
                rms: rms,
                waveform: waveform,
              );
              _pitchFilterBuffer.clear();
              _smoothedPitch = 0.0;
              notifyListeners();
            }
            continue;
          }

          try {
            // Ultra-precise McLeod Pitch Method (MPM) pitch detection with subharmonic correction
            final result = detectPitchFromPcm16(chunkBytes, sampleRate: _sampleRate);

            if (result.pitch >= 40.0 && result.pitch <= 1500.0 && result.clarity >= 0.45) {
              _pitchFilterBuffer.add(result.pitch);
              if (_pitchFilterBuffer.length > _filterWindowSize) {
                _pitchFilterBuffer.removeAt(0);
              }

              // 3-point median filter to reject transient onset noise
              final sortedPitches = List<double>.from(_pitchFilterBuffer)..sort();
              final medianPitch = sortedPitches[sortedPitches.length ~/ 2];

              // Exponential smoothing for liquid-smooth needle/ribbon tracking
              if (_smoothedPitch == 0.0 || (_smoothedPitch - medianPitch).abs() > 35.0) {
                _smoothedPitch = medianPitch;
              } else {
                _smoothedPitch = _smoothedPitch * 0.45 + medianPitch * 0.55;
              }

              final note = getNoteFromPitch(_smoothedPitch);
              _pitchData = PitchData(
                pitch: _smoothedPitch,
                note: note,
                clarity: result.clarity,
                rms: rms,
                waveform: waveform,
              );
              notifyListeners();
            } else {
              if (_pitchData.pitch != 0.0) {
                _pitchData = PitchData(
                  pitch: 0.0,
                  note: '',
                  clarity: 0.0,
                  rms: rms,
                  waveform: waveform,
                );
                _pitchFilterBuffer.clear();
                _smoothedPitch = 0.0;
                notifyListeners();
              } else {
                // Update waveform even in silence so UI visualizers are alive
                _pitchData = PitchData(
                  pitch: 0.0,
                  note: '',
                  clarity: 0.0,
                  rms: rms,
                  waveform: waveform,
                );
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

  /// Extracts downsampled normalized audio waveform samples in range [-1.0, 1.0]
  static Float64List _extractNormalizedWaveform(Uint8List buffer, {int pointCount = 96}) {
    final samplesCount = buffer.length ~/ 2;
    if (samplesCount == 0) return Float64List(pointCount);

    final byteData = ByteData.sublistView(buffer);
    final waveform = Float64List(pointCount);
    final step = samplesCount / pointCount;

    for (int i = 0; i < pointCount; i++) {
      final sampleIdx = (i * step).toInt().clamp(0, samplesCount - 1);
      final raw = byteData.getInt16(sampleIdx * 2, Endian.little);
      waveform[i] = (raw / 32768.0).clamp(-1.0, 1.0);
    }
    return waveform;
  }

  /// High-Precision McLeod Pitch Method (MPM) / NSDF Pitch Detector
  ///
  /// Combines:
  /// 1. 2nd-order Butterworth low-pass digital filter ($f_c \approx 1400\text{ Hz}$) to eliminate high-frequency harmonics & pick scrape noise.
  /// 2. Normalized Square Difference Function (NSDF) $r_t(\tau) = \frac{2 \sum x_j x_{j+\tau}}{\sum x_j^2 + \sum x_{j+\tau}^2}$.
  /// 3. Subharmonic octave disambiguation for low guitar strings (E2, D2, B1) and bass voices.
  /// 4. 3-Point Parabolic sub-sample interpolation for sub-cent frequency accuracy.
  static PitchData detectPitchFromPcm16(Uint8List buffer, {int sampleRate = 44100}) {
    final samplesCount = buffer.length ~/ 2;
    if (samplesCount < 512) return PitchData();

    final byteData = ByteData.sublistView(buffer);
    final rawFloats = Float64List(samplesCount);

    // Step 0: Convert 16-bit PCM Little Endian to normalized [-1.0, 1.0] floats & subtract DC bias
    double sum = 0.0;
    for (int i = 0; i < samplesCount; i++) {
      final rawSample = byteData.getInt16(i * 2, Endian.little);
      final val = rawSample / 32768.0;
      rawFloats[i] = val;
      sum += val;
    }
    final double dcMean = sum / samplesCount;
    for (int i = 0; i < samplesCount; i++) {
      rawFloats[i] -= dcMean;
    }

    // Step 1: 2nd-Order Low-Pass Butterworth Filter (Cutoff ~ 1400 Hz at 44.1 kHz)
    // Preserves fundamental frequencies while damping upper noise/harmonics
    final filtered = _applyLowPassFilter(rawFloats, sampleRate, 1400.0);

    // Step 2: Compute Normalized Square Difference Function (NSDF)
    // Window size = samplesCount / 2 = 1024
    final int windowSize = samplesCount ~/ 2;
    final nsdf = Float64List(windowSize);

    // Limits for 40 Hz (tau ~ 1102) to 1500 Hz (tau ~ 29)
    final int minTau = (sampleRate / 1500.0).floor().clamp(2, windowSize - 1);
    final int maxTau = (sampleRate / 40.0).ceil().clamp(minTau + 1, windowSize - 1);

    for (int tau = 0; tau <= maxTau; tau++) {
      double acf = 0.0;
      double divisor = 0.0;
      for (int i = 0; i < windowSize; i++) {
        final x1 = filtered[i];
        final x2 = filtered[i + tau];
        acf += x1 * x2;
        divisor += x1 * x1 + x2 * x2;
      }
      nsdf[tau] = (divisor > 1e-9) ? (2.0 * acf / divisor) : 0.0;
    }

    // Step 3: Peak Picking on NSDF
    // Find all positive local maxima
    final List<int> peakPositions = [];
    bool isPositive = false;

    for (int tau = minTau; tau < maxTau; tau++) {
      if (nsdf[tau] > 0.0) {
        isPositive = true;
      } else {
        isPositive = false;
      }

      if (isPositive && tau > 0 && tau < maxTau) {
        if (nsdf[tau] > nsdf[tau - 1] && nsdf[tau] >= nsdf[tau + 1]) {
          peakPositions.add(tau);
        }
      }
    }

    if (peakPositions.isEmpty) return PitchData();

    // Find highest peak value
    double maxPeakValue = 0.0;
    for (final pos in peakPositions) {
      if (nsdf[pos] > maxPeakValue) {
        maxPeakValue = nsdf[pos];
      }
    }

    if (maxPeakValue < 0.35) return PitchData();

    // Dynamic threshold k = 0.85 * maxPeakValue (standard MPM threshold)
    final double threshold = 0.85 * maxPeakValue;
    int chosenTau = -1;

    for (final pos in peakPositions) {
      if (nsdf[pos] >= threshold) {
        chosenTau = pos;
        break;
      }
    }

    if (chosenTau <= 0) {
      chosenTau = peakPositions.first;
    }

    // Step 4: Subharmonic / Octave Error Disambiguation
    // Guitars and deep vocal tones have strong 2nd and 3rd harmonics.
    // If chosenTau is around half of a true fundamental peak (~2*tau), check if a 2*tau peak exists.
    final int doubleTau = chosenTau * 2;
    if (doubleTau <= maxTau) {
      int bestSubPos = -1;
      double bestSubVal = 0.0;
      for (final pos in peakPositions) {
        if ((pos - doubleTau).abs() <= 6) {
          if (nsdf[pos] > bestSubVal) {
            bestSubVal = nsdf[pos];
            bestSubPos = pos;
          }
        }
      }

      // If a valid peak exists at ~2*tau with substantial clarity (>= 0.65 of max peak)
      if (bestSubPos != -1 && bestSubVal >= maxPeakValue * 0.65 && bestSubVal >= 0.40) {
        chosenTau = bestSubPos;
      }
    }

    // Step 5: Sub-sample Parabolic Interpolation on chosen peak
    final int x0 = (chosenTau > 0) ? chosenTau - 1 : chosenTau;
    final int x2 = (chosenTau + 1 < windowSize) ? chosenTau + 1 : chosenTau;

    double refinedTau = chosenTau.toDouble();
    if (x0 != chosenTau && x2 != chosenTau) {
      final s0 = nsdf[x0];
      final s1 = nsdf[chosenTau];
      final s2 = nsdf[x2];
      final denominator = 2.0 * (2.0 * s1 - s2 - s0);
      if (denominator.abs() > 1e-6) {
        refinedTau = chosenTau + (s2 - s0) / denominator;
      }
    }

    if (refinedTau <= 0) return PitchData();

    final pitch = sampleRate / refinedTau;
    if (pitch < 40.0 || pitch > 1500.0) return PitchData();

    final clarity = nsdf[chosenTau].clamp(0.0, 1.0);

    return PitchData(
      pitch: pitch,
      clarity: clarity,
    );
  }

  /// Fast 2nd-order Butterworth low-pass digital filter
  static Float64List _applyLowPassFilter(Float64List input, int sampleRate, double cutoffHz) {
    final int len = input.length;
    final output = Float64List(len);

    final double c = tan(pi * cutoffHz / sampleRate);
    final double c2 = c * c;
    final double sqrt2c = sqrt(2.0) * c;
    final double d = 1.0 + sqrt2c + c2;

    final double a0 = c2 / d;
    final double a1 = 2.0 * a0;
    final double a2 = a0;
    final double b1 = 2.0 * (c2 - 1.0) / d;
    final double b2 = (1.0 - sqrt2c + c2) / d;

    double x1 = 0.0, x2 = 0.0;
    double y1 = 0.0, y2 = 0.0;

    for (int i = 0; i < len; i++) {
      final double x0 = input[i];
      final double y0 = a0 * x0 + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2;
      output[i] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    return output;
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

  /// Octave-wrapped cents difference (for auto-transposed vocal pitch training)
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