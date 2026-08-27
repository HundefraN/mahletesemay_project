import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/pitch_service.dart';
import '../../utils/generated_tones.dart';
import '../../utils/responsive_sizer.dart';
import '../../widgets/custom_snackbar.dart';

class GuitarString {
  final int index;
  final String noteName;
  final int octave;
  final double frequency;
  final String label;
  final bool isWound;
  final double gauge;

  const GuitarString({
    required this.index,
    required this.noteName,
    required this.octave,
    required this.frequency,
    required this.label,
    this.isWound = false,
    this.gauge = 1.0,
  });

  String get fullNote => '$noteName$octave';
}

class TuningPreset {
  final String name;
  final String description;
  final List<GuitarString> strings;

  const TuningPreset({
    required this.name,
    required this.description,
    required this.strings,
  });
}

class GuitarTunerScreen extends StatefulWidget {
  const GuitarTunerScreen({super.key});

  @override
  State<GuitarTunerScreen> createState() => _GuitarTunerScreenState();
}

class _GuitarTunerScreenState extends State<GuitarTunerScreen>
    with TickerProviderStateMixin {
  static final List<TuningPreset> _presets = [
    TuningPreset(
      name: 'Standard (E A D G B E)',
      description: 'Classic 6-string guitar standard tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'E',
            octave: 2,
            frequency: 82.41,
            label: '6th (Low E)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'B',
            octave: 3,
            frequency: 246.94,
            label: '2nd (B)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'E',
            octave: 4,
            frequency: 329.63,
            label: '1st (High E)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Drop D (D A D G B E)',
      description: 'Heavy rock / metal tuning with low D string',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'B',
            octave: 3,
            frequency: 246.94,
            label: '2nd (B)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'E',
            octave: 4,
            frequency: 329.63,
            label: '1st (High E)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Half-Step Down (Eb Ab Db Gb Bb Eb)',
      description: 'SRV / Hendrix / Guns N\' Roses tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D#',
            octave: 2,
            frequency: 77.78,
            label: '6th (Eb)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'G#',
            octave: 2,
            frequency: 103.83,
            label: '5th (Ab)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'C#',
            octave: 3,
            frequency: 138.59,
            label: '4th (Db)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'F#',
            octave: 3,
            frequency: 185.00,
            label: '3rd (Gb)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'A#',
            octave: 3,
            frequency: 233.08,
            label: '2nd (Bb)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'D#',
            octave: 4,
            frequency: 311.13,
            label: '1st (Eb)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'DADGAD (Celtic Modal)',
      description: 'Modal fingerstyle resonant acoustic tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'A',
            octave: 3,
            frequency: 220.00,
            label: '2nd (A)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Open D (D A D F# A D)',
      description: 'Acoustic fingerstyle open resonant chord',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'F#',
            octave: 3,
            frequency: 185.00,
            label: '3rd (F#)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'A',
            octave: 3,
            frequency: 220.00,
            label: '2nd (A)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Open G (D G D G B D)',
      description: 'Keith Richards / Blues slide guitar tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'G',
            octave: 2,
            frequency: 98.00,
            label: '5th (G)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'B',
            octave: 3,
            frequency: 246.94,
            label: '2nd (B)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Full-Step Down (D G C F A D)',
      description: 'D Standard heavy downtuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 1,
            noteName: 'G',
            octave: 2,
            frequency: 98.00,
            label: '5th (G)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'C',
            octave: 3,
            frequency: 130.81,
            label: '4th (C)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'F',
            octave: 3,
            frequency: 174.61,
            label: '3rd (F)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'A',
            octave: 3,
            frequency: 220.00,
            label: '2nd (A)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Drop C (C G C F A D)',
      description: 'Ultra-heavy metal tuning with low C string',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'C',
            octave: 2,
            frequency: 65.41,
            label: '6th (Low C)',
            isWound: true,
            gauge: 3.6),
        GuitarString(
            index: 1,
            noteName: 'G',
            octave: 2,
            frequency: 98.00,
            label: '5th (G)',
            isWound: true,
            gauge: 2.8),
        GuitarString(
            index: 2,
            noteName: 'C',
            octave: 3,
            frequency: 130.81,
            label: '4th (C)',
            isWound: true,
            gauge: 2.2),
        GuitarString(
            index: 3,
            noteName: 'F',
            octave: 3,
            frequency: 174.61,
            label: '3rd (F)',
            isWound: false,
            gauge: 1.6),
        GuitarString(
            index: 4,
            noteName: 'A',
            octave: 3,
            frequency: 220.00,
            label: '2nd (A)',
            isWound: false,
            gauge: 1.2),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false,
            gauge: 0.9),
      ],
    ),
    TuningPreset(
      name: 'Bass 4-String (E A D G)',
      description: 'Standard 4-string electric & acoustic bass tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'E',
            octave: 1,
            frequency: 41.20,
            label: '4th (Low E)',
            isWound: true,
            gauge: 4.2),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 1,
            frequency: 55.00,
            label: '3rd (A)',
            isWound: true,
            gauge: 3.4),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '2nd (D)',
            isWound: true,
            gauge: 2.6),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 2,
            frequency: 98.00,
            label: '1st (G)',
            isWound: true,
            gauge: 1.9),
      ],
    ),
    TuningPreset(
      name: 'Ukulele Standard (G C E A)',
      description: 'Standard soprano, concert, and tenor ukulele tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'G',
            octave: 4,
            frequency: 392.00,
            label: '4th (High G)',
            isWound: false,
            gauge: 1.4),
        GuitarString(
            index: 1,
            noteName: 'C',
            octave: 4,
            frequency: 261.63,
            label: '3rd (C)',
            isWound: false,
            gauge: 1.8),
        GuitarString(
            index: 2,
            noteName: 'E',
            octave: 4,
            frequency: 329.63,
            label: '2nd (E)',
            isWound: false,
            gauge: 1.3),
        GuitarString(
            index: 3,
            noteName: 'A',
            octave: 4,
            frequency: 440.00,
            label: '1st (A)',
            isWound: false,
            gauge: 1.0),
      ],
    ),
  ];

  late TuningPreset _currentPreset;
  int _selectedStringIndex = 0;
  bool _isAutoMode = true;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _soundPlayer = AudioPlayer();
  StreamSubscription<Uint8List>? _streamSub;
  final List<int> _audioBuffer = [];
  static const int _targetBufferBytes = 4096;
  static const int _hopBufferBytes = 1024;

  final List<double> _pitchHistory = [];
  static const int _historyCapacity = 3;
  double _filteredPitch = 0.0;
  int _autoStringCandidate = -1;
  int _autoStringCandidateCount = 0;

  bool _isListening = false;
  double _currentPitch = 0.0;
  double _centsOffset = 0.0;
  bool _isInTune = false;

  int _inTuneHoldCount = 0;
  static const int _requiredHoldFrames = 4;
  double _rangeHoldProgress = 0.0;
  bool _beepTriggeredForCurrentHold = false;

  late AnimationController _pulseController;
  late AnimationController _stringVibrationController;
  double _animatedCents = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPreset = _presets.first;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _stringVibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    )..repeat(reverse: true);

    _initMicAndStartTuner();
  }

  @override
  void dispose() {
    _stopListening();
    _soundPlayer.dispose();
    _pulseController.dispose();
    _stringVibrationController.dispose();
    super.dispose();
  }

  Future<void> _playTunedPitchBeep(double frequency) async {
    try {
      final bytes = GeneratedTones.getPitchBeepTone(frequency);
      await _soundPlayer.stop();
      await _soundPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint("GuitarTuner: Error playing pitch beep sound: $e");
    }
  }

  Future<void> _initMicAndStartTuner() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _startListening();
    } else {
      if (mounted) {
        CustomSnackbar.show(
            context, 'Microphone permission required for Guitar Tuner');
      }
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      _audioBuffer.clear();
      _pitchHistory.clear();
      _filteredPitch = 0.0;
      _inTuneHoldCount = 0;
      _rangeHoldProgress = 0.0;
      _beepTriggeredForCurrentHold = false;

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );

      _isListening = true;
      _streamSub = stream.listen((data) {
        _audioBuffer.addAll(data);

        // Anti-lag circular buffer protection: drop stale accumulation if UI frame dips
        if (_audioBuffer.length > _targetBufferBytes * 2) {
          final excess = _audioBuffer.length - _targetBufferBytes;
          _audioBuffer.removeRange(0, excess);
        }

        while (_audioBuffer.length >= _targetBufferBytes) {
          final chunk =
              Uint8List.fromList(_audioBuffer.sublist(0, _targetBufferBytes));
          // Hop forward with 75% overlap for ultra-responsive ~11.6ms updates
          _audioBuffer.removeRange(0, _hopBufferBytes);

          // Fast RMS signal energy calculation
          double sumSquares = 0;
          final byteData = ByteData.sublistView(chunk);
          final samples = chunk.length ~/ 2;
          for (int i = 0; i < samples; i++) {
            final sample = byteData.getInt16(i * 2, Endian.little);
            sumSquares += sample * sample;
          }
          final rms = math.sqrt(sumSquares / samples);

          if (rms < 20.0) {
            _pitchHistory.clear();
            _filteredPitch = 0.0;
            _inTuneHoldCount = 0;
            _rangeHoldProgress = 0.0;
            _beepTriggeredForCurrentHold = false;
            if (_currentPitch != 0.0) {
              if (mounted) {
                setState(() {
                  _currentPitch = 0.0;
                  _centsOffset = 0.0;
                  _animatedCents = 0.0;
                  _isInTune = false;
                });
              }
            }
            continue;
          }

          try {
            // Ultra-precise McLeod Pitch Method (MPM) pitch detection with subharmonic check
            final result = PitchService.detectPitchFromPcm16(chunk, sampleRate: 44100);
            if (result.pitch >= 35.0 && result.pitch <= 1400.0 && result.clarity >= 0.42) {
              _processPitch(result.pitch);
            }
          } catch (e) {
            debugPrint('GuitarTuner: Pitch detection error: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting tuner audio stream: $e');
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _processPitch(double rawPitch) {
    if (!mounted) return;

    _pitchHistory.add(rawPitch);
    if (_pitchHistory.length > _historyCapacity) {
      _pitchHistory.removeAt(0);
    }

    final sortedPitches = List<double>.from(_pitchHistory)..sort();
    final medianPitch = sortedPitches[sortedPitches.length ~/ 2];

    if (_filteredPitch == 0.0 || (_filteredPitch - medianPitch).abs() > 35.0) {
      _filteredPitch = medianPitch;
    } else {
      _filteredPitch = _filteredPitch * 0.45 + medianPitch * 0.55;
    }

    if (_isAutoMode) {
      double minScore = double.infinity;
      int bestIdx = _selectedStringIndex;

      for (int i = 0; i < _currentPreset.strings.length; i++) {
        final string = _currentPreset.strings[i];
        final semitoneDist = (12.0 * (math.log(_filteredPitch / string.frequency) / math.ln2)).abs();
        
        // Hysteresis boost: prioritize current string to avoid flitting between strings during tuning
        final score = (i == _selectedStringIndex) ? semitoneDist * 0.65 : semitoneDist;
        
        if (score < minScore) {
          minScore = score;
          bestIdx = i;
        }
      }

      if (bestIdx != _selectedStringIndex) {
        if (_autoStringCandidate == bestIdx) {
          _autoStringCandidateCount++;
          if (_autoStringCandidateCount >= 2) {
            _selectedStringIndex = bestIdx;
            _autoStringCandidateCount = 0;
          }
        } else {
          _autoStringCandidate = bestIdx;
          _autoStringCandidateCount = 1;
        }
      } else {
        _autoStringCandidateCount = 0;
      }
    }

    final targetString = _currentPreset.strings[_selectedStringIndex];

    double cents =
        1200.0 * (math.log(_filteredPitch / targetString.frequency) / math.ln2);
    cents = cents.clamp(-50.0, 50.0);

    if (cents.abs() < 0.3) cents = 0.0;

    final bool currentlyInTune = cents.abs() <= 3.5;

    if (currentlyInTune) {
      _inTuneHoldCount++;
      _rangeHoldProgress =
          (_inTuneHoldCount / _requiredHoldFrames).clamp(0.0, 1.0);
      if (_inTuneHoldCount >= _requiredHoldFrames &&
          !_beepTriggeredForCurrentHold) {
        HapticFeedback.mediumImpact();
        _playTunedPitchBeep(targetString.frequency);
        _beepTriggeredForCurrentHold = true;
      }
    } else {
      _inTuneHoldCount = 0;
      _rangeHoldProgress = 0.0;
      _beepTriggeredForCurrentHold = false;
    }

    // Smooth spring interpolation for the gauge needle
    _animatedCents = _animatedCents * 0.40 + cents * 0.60;

    setState(() {
      _currentPitch = _filteredPitch;
      _centsOffset = cents;
      _isInTune = currentlyInTune;
    });
  }

  Future<void> _stopListening() async {
    _streamSub?.cancel();
    _streamSub = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    _isListening = false;
  }

  void _selectString(int index) {
    HapticFeedback.lightImpact();
    final str = _currentPreset.strings[index];
    _playTunedPitchBeep(str.frequency);
    setState(() {
      _selectedStringIndex = index;
      _isAutoMode = false;
      _currentPitch = 0.0;
      _centsOffset = 0.0;
      _animatedCents = 0.0;
      _isInTune = false;
      _inTuneHoldCount = 0;
      _rangeHoldProgress = 0.0;
      _beepTriggeredForCurrentHold = false;
    });
  }

  void _toggleAutoMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoMode = !_isAutoMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetString = _currentPreset.strings[_selectedStringIndex];

    Color statusColor = const Color(0xFFFFB300);
    if (_currentPitch == 0.0) {
      statusColor = isDark ? Colors.white38 : Colors.black38;
    } else if (_isInTune) {
      statusColor = const Color(0xFF00E676);
    } else if (_centsOffset < -3.5) {
      statusColor = const Color(0xFFFF3D00); // Too flat
    } else {
      statusColor = const Color(0xFF7C4DFF); // Too sharp
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF080A0F) : const Color(0xFFF4F6FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(IconsaxPlusLinear.arrow_left_3,
              color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'GUITAR TUNER',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            fontSize: context.sp(17),
            letterSpacing: 2.0,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: context.w(16)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: _isAutoMode
                  ? LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.25),
                        theme.colorScheme.primary.withOpacity(0.08),
                      ],
                    )
                  : null,
              border: Border.all(
                color: _isAutoMode
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white24 : Colors.black12),
                width: 1.2,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _toggleAutoMode,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(12), vertical: context.w(6)),
                child: Row(
                  children: [
                    Icon(
                      _isAutoMode
                          ? IconsaxPlusBold.magicpen
                          : IconsaxPlusLinear.element_3,
                      size: context.w(14),
                      color: _isAutoMode
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: context.w(6)),
                    Text(
                      _isAutoMode ? 'AUTO' : 'MANUAL',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: context.sp(11),
                        letterSpacing: 1.0,
                        color: _isAutoMode
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preset Selector
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(20), vertical: context.w(2)),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(16), vertical: context.w(2)),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131722).withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(context.w(16)),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TuningPreset>(
                    value: _currentPreset,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? const Color(0xFF131722) : Colors.white,
                    icon: Icon(IconsaxPlusLinear.arrow_down_1,
                        size: context.w(18), color: theme.colorScheme.primary),
                    items: _presets.map((preset) {
                      return DropdownMenuItem<TuningPreset>(
                        value: preset,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              preset.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: context.sp(13),
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              preset.description,
                              style: TextStyle(
                                fontSize: context.sp(10.5),
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (preset) {
                      if (preset != null) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _currentPreset = preset;
                          _selectedStringIndex = 0;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: context.w(6)),

            // Gauge & Frequency Readout
            Expanded(
              flex: 5,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInTune)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.10)
                            .animate(_pulseController),
                        child: Container(
                          width: context.w(230),
                          height: context.w(230),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF00E676).withOpacity(0.35),
                                blurRadius: 60,
                                spreadRadius: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    CustomPaint(
                      size: Size(context.w(250), context.w(250)),
                      painter: RadialPitchGaugePainter(
                        cents: _animatedCents,
                        hasPitch: _currentPitch > 0,
                        isInTune: _isInTune,
                        statusColor: statusColor,
                        isDark: isDark,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetString.noteName,
                              style: GoogleFonts.syne(
                                fontSize: context.sp(52),
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '${targetString.octave}',
                              style: GoogleFonts.outfit(
                                fontSize: context.sp(20),
                                fontWeight: FontWeight.w800,
                                color: statusColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.w(4)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                              horizontal: context.w(14),
                              vertical: context.w(4)),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(context.w(20)),
                            border: Border.all(
                                color: statusColor.withOpacity(0.4),
                                width: 1.2),
                          ),
                          child: Text(
                            _currentPitch == 0.0
                                ? 'PLUCK STRING'
                                : _isInTune
                                    ? 'IN TUNE ✓'
                                    : _centsOffset < 0
                                        ? 'TOO FLAT ▼'
                                        : 'TOO SHARP ▲',
                            style: GoogleFonts.outfit(
                              fontSize: context.sp(10.5),
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: context.w(6)),
                        Text(
                          _currentPitch > 0
                              ? '${_currentPitch.toStringAsFixed(1)} Hz / ${targetString.frequency.toStringAsFixed(1)} Hz'
                              : 'Target: ${targetString.frequency.toStringAsFixed(1)} Hz',
                          style: GoogleFonts.outfit(
                            fontSize: context.sp(11),
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Cents indicator & hold meter
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(36)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-50 cents',
                      style: GoogleFonts.outfit(
                          fontSize: context.sp(10), color: Colors.grey)),
                  Text(
                    _currentPitch > 0
                        ? '${_centsOffset > 0 ? "+" : ""}${_centsOffset.toStringAsFixed(1)} CENTS'
                        : '0.0 CENTS',
                    style: GoogleFonts.outfit(
                      fontSize: context.sp(12.5),
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text('+50 cents',
                      style: GoogleFonts.outfit(
                          fontSize: context.sp(10), color: Colors.grey)),
                ],
              ),
            ),
            SizedBox(height: context.w(4)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(36)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.w(4)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: context.w(4),
                  child: LinearProgressIndicator(
                    value: _rangeHoldProgress,
                    backgroundColor: isDark
                        ? const Color(0xFF1A1F2C)
                        : const Color(0xFFE2E7F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _beepTriggeredForCurrentHold
                          ? const Color(0xFF00E676)
                          : statusColor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: context.w(6)),

            // String choice chips
            SizedBox(
              height: context.w(40),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                itemCount: _currentPreset.strings.length,
                itemBuilder: (context, idx) {
                  final str = _currentPreset.strings[idx];
                  final isSelected = idx == _selectedStringIndex;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.w(3)),
                    child: ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        '${str.fullNote} (${str.label.split(" ").first})',
                        style: GoogleFonts.outfit(
                          fontSize: context.sp(11.5),
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      selectedColor: statusColor,
                      backgroundColor: isDark
                          ? const Color(0xFF1A1F2C)
                          : const Color(0xFFE2E7F0),
                      onSelected: (_) => _selectString(idx),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: context.w(8)),

            // Ultra-Realistic 3D Guitar Headstock Canvas & Interactive Pegs
            Expanded(
              flex: 6,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(16), vertical: context.w(4)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double headstockWidth =
                        math.min(constraints.maxWidth, context.w(360));
                    final double headstockHeight = constraints.maxHeight;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _stringVibrationController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(headstockWidth, headstockHeight),
                              painter: UltraRealisticHeadstockPainter(
                                selectedIndex: _selectedStringIndex,
                                strings: _currentPreset.strings,
                                isDark: isDark,
                                statusColor: statusColor,
                                isVibrating: _currentPitch > 0,
                                vibrationPhase:
                                    _stringVibrationController.value,
                              ),
                            );
                          },
                        ),
                        // Interactive tap areas for each peg key
                        SizedBox(
                          width: headstockWidth,
                          height: headstockHeight,
                          child: Stack(
                            children: [
                              _buildInteractivePegKey(0, headstockWidth * 0.02,
                                  headstockHeight * 0.16, context),
                              _buildInteractivePegKey(1, headstockWidth * 0.02,
                                  headstockHeight * 0.38, context),
                              _buildInteractivePegKey(2, headstockWidth * 0.02,
                                  headstockHeight * 0.60, context),
                              _buildInteractivePegKey(3, headstockWidth * 0.78,
                                  headstockHeight * 0.60, context),
                              _buildInteractivePegKey(4, headstockWidth * 0.78,
                                  headstockHeight * 0.38, context),
                              _buildInteractivePegKey(5, headstockWidth * 0.78,
                                  headstockHeight * 0.16, context),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractivePegKey(
      int index, double left, double top, BuildContext context) {
    if (index >= _currentPreset.strings.length) return const SizedBox.shrink();
    final string = _currentPreset.strings[index];
    final isSelected = index == _selectedStringIndex;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _selectString(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: context.w(68),
          height: context.w(52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                string.fullNote,
                style: GoogleFonts.syne(
                  fontSize: context.sp(12.5),
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'Str ${string.index + 1}',
                style: TextStyle(
                  fontSize: context.sp(9),
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RadialPitchGaugePainter extends CustomPainter {
  final double cents;
  final bool hasPitch;
  final bool isInTune;
  final Color statusColor;
  final bool isDark;

  RadialPitchGaugePainter({
    required this.cents,
    required this.hasPitch,
    required this.isInTune,
    required this.statusColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double center = size.width / 2;
    final Offset centerOffset = Offset(center, center);
    final double radius = center - 12;

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0);

    const double startAngle = 135 * math.pi / 180;
    const double sweepAngle = 270 * math.pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: centerOffset, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (hasPitch) {
      final double normalizedCents = (cents.clamp(-50.0, 50.0) + 50) / 100.0;
      final double activeSweep = sweepAngle * normalizedCents;

      final Paint activeArcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = statusColor;

      canvas.drawArc(
        Rect.fromCircle(center: centerOffset, radius: radius),
        startAngle,
        activeSweep,
        false,
        activeArcPaint,
      );
    }

    final Paint tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = -50; i <= 50; i += 10) {
      final double angle = startAngle + ((i + 50) / 100.0) * sweepAngle;
      final bool isCenter = i == 0;
      final bool isMajor = i % 20 == 0 || isCenter;

      final double tickLength = isCenter ? 15 : (isMajor ? 11 : 7);
      tickPaint.strokeWidth = isCenter ? 3.0 : (isMajor ? 1.8 : 1.0);
      tickPaint.color = isCenter
          ? const Color(0xFF00E676)
          : (isDark ? Colors.white38 : Colors.black38);

      final Offset inner = Offset(
        center + (radius - 12) * math.cos(angle),
        center + (radius - 12) * math.sin(angle),
      );
      final Offset outer = Offset(
        center + (radius - 12 - tickLength) * math.cos(angle),
        center + (radius - 12 - tickLength) * math.sin(angle),
      );

      canvas.drawLine(inner, outer, tickPaint);
    }

    final double needleAngle =
        startAngle + ((cents.clamp(-50.0, 50.0) + 50) / 100.0) * sweepAngle;

    final Offset needleTip = Offset(
      center + (radius - 20) * math.cos(needleAngle),
      center + (radius - 20) * math.sin(needleAngle),
    );

    final Paint needlePaint = Paint()
      ..color =
          hasPitch ? statusColor : (isDark ? Colors.white30 : Colors.black26)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(centerOffset, needleTip, needlePaint);

    canvas.drawCircle(centerOffset, 7, Paint()..color = statusColor);
    canvas.drawCircle(
      centerOffset,
      3.5,
      Paint()..color = isDark ? const Color(0xFF080A0F) : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant RadialPitchGaugePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.hasPitch != hasPitch ||
        oldDelegate.isInTune != isInTune ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Ultra-Realistic Photo-rendered Guitar Headstock, Binding, Inlays, Tuners, and Strings Painter
class UltraRealisticHeadstockPainter extends CustomPainter {
  final int selectedIndex;
  final List<GuitarString> strings;
  final bool isDark;
  final Color statusColor;
  final bool isVibrating;
  final double vibrationPhase;

  UltraRealisticHeadstockPainter({
    required this.selectedIndex,
    required this.strings,
    required this.isDark,
    required this.statusColor,
    required this.isVibrating,
    required this.vibrationPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Headstock Silhouette & Contour
    final Path headstockPath = Path();
    headstockPath.moveTo(w * 0.28, h * 0.98);
    headstockPath.lineTo(w * 0.22, h * 0.16);
    headstockPath.quadraticBezierTo(w * 0.18, h * 0.03, w * 0.38, h * 0.05);
    headstockPath.quadraticBezierTo(w * 0.50, h * 0.12, w * 0.62, h * 0.05);
    headstockPath.quadraticBezierTo(w * 0.82, h * 0.03, w * 0.78, h * 0.16);
    headstockPath.lineTo(w * 0.72, h * 0.98);
    headstockPath.close();

    // 2. Ambient Drop Shadow behind Headstock
    canvas.drawPath(
      headstockPath,
      Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 3. Flame Maple / Sunburst Wood Grain Base Shader
    final Rect headstockRect = Rect.fromLTWH(0, 0, w, h);
    final Paint woodShader = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.2),
        radius: 0.85,
        colors: isDark
            ? [
                const Color(0xFF422116), // Warm amber burst center
                const Color(0xFF26120C), // Mahogany mid
                const Color(0xFF0F0604), // Dark sunburst rim
              ]
            : [
                const Color(0xFF8B4513), // Rich vintage amber
                const Color(0xFF5C260E), // Burnt sienna
                const Color(0xFF240E06), // Deep walnut edge
              ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(headstockRect);

    canvas.drawPath(headstockPath, woodShader);

    // 4. Subtle Organic Flame Maple Grain Stripes
    final Paint grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.black.withOpacity(0.12);

    for (double y = h * 0.10; y < h * 0.80; y += h * 0.045) {
      final Path grainLine = Path();
      grainLine.moveTo(w * 0.24, y);
      grainLine.cubicTo(
        w * 0.38, y + 4.0 * math.sin(y * 10),
        w * 0.62, y - 3.0 * math.cos(y * 8),
        w * 0.76, y,
      );
      canvas.save();
      canvas.clipPath(headstockPath);
      canvas.drawPath(grainLine, grainPaint);
      canvas.restore();
    }

    // 5. Nitrocellulose Lacquer Curved Gloss Reflection Highlight
    final Path glossPath = Path();
    glossPath.moveTo(w * 0.26, h * 0.16);
    glossPath.quadraticBezierTo(w * 0.40, h * 0.08, w * 0.50, h * 0.16);
    glossPath.lineTo(w * 0.44, h * 0.70);
    glossPath.lineTo(w * 0.30, h * 0.70);
    glossPath.close();

    final Paint glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.22),
          Colors.white.withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(headstockRect);

    canvas.save();
    canvas.clipPath(headstockPath);
    canvas.drawPath(glossPath, glossPaint);
    canvas.restore();

    // 6. Multi-ply Vintage Aged Ivory Binding with Purfling Accent
    final Paint bindingOuter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = const Color(0xFFF3EAD3); // Aged ivory
    canvas.drawPath(headstockPath, bindingOuter);

    final Paint purflingInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF1E140F); // Black inner pinstripe
    canvas.drawPath(headstockPath, purflingInner);

    // 7. Pearloid Crown/Diamond Inlay & Golden Logo
    final Path pearlDiamond = Path();
    pearlDiamond.moveTo(w * 0.50, h * 0.20);
    pearlDiamond.lineTo(w * 0.54, h * 0.26);
    pearlDiamond.lineTo(w * 0.50, h * 0.32);
    pearlDiamond.lineTo(w * 0.46, h * 0.26);
    pearlDiamond.close();

    final Paint pearlPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFD4E6F1),
          Color(0xFFE8DAEF),
          Color(0xFFD5F5E3),
          Color(0xFFFCF3CF),
        ],
      ).createShader(Rect.fromLTWH(w * 0.46, h * 0.20, w * 0.08, h * 0.12));

    canvas.drawPath(pearlDiamond, pearlPaint);
    canvas.drawPath(
      pearlDiamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black45,
    );

    // 8. 3-Ply Bell-Shaped Truss Rod Cover with Bevelled Screws
    final Path trussCover = Path();
    trussCover.moveTo(w * 0.47, h * 0.64);
    trussCover.lineTo(w * 0.53, h * 0.64);
    trussCover.lineTo(w * 0.52, h * 0.74);
    trussCover.lineTo(w * 0.48, h * 0.74);
    trussCover.close();

    canvas.drawPath(trussCover, Paint()..color = const Color(0xFF0F0F0F));
    canvas.drawPath(
      trussCover,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFEAEAEA),
    );

    // Truss screws
    final Paint screwPaint = Paint()..color = const Color(0xFFB0BEC5);
    canvas.drawCircle(Offset(w * 0.50, h * 0.655), 1.6, screwPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.725), 1.6, screwPaint);

    // 9. Dense Ebony Fretboard below Nut
    final Rect fretboardRect = Rect.fromLTRB(w * 0.27, h * 0.81, w * 0.73, h);
    final Paint ebonyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E1A17), Color(0xFF0D0B0A)],
      ).createShader(fretboardRect);
    canvas.drawRect(fretboardRect, ebonyPaint);

    // 10. Hand-Carved Slotted Bone Nut with Individual String Grooves
    final Rect nutRect =
        Rect.fromLTRB(w * 0.265, h * 0.77, w * 0.735, h * 0.81);
    final Paint boneNutPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFBEA), Color(0xFFD6CEBA), Color(0xFFAFA794)],
      ).createShader(nutRect);

    final RRect roundedNut =
        RRect.fromRectAndRadius(nutRect, const Radius.circular(2.5));
    canvas.drawRRect(roundedNut, boneNutPaint);
    canvas.drawRRect(
      roundedNut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black45,
    );

    // 11. 3D Tuning Machines (Peg Posts, Hex Bushings, and Keystone Buttons)
    final List<Offset> pegPositions = [
      Offset(w * 0.20, h * 0.22),
      Offset(w * 0.20, h * 0.42),
      Offset(w * 0.20, h * 0.62),
      Offset(w * 0.80, h * 0.62),
      Offset(w * 0.80, h * 0.42),
      Offset(w * 0.80, h * 0.22),
    ];

    final Paint chromeGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFCFD8DC),
          Color(0xFF78909C),
          Color(0xFF37474F),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    for (int i = 0; i < pegPositions.length; i++) {
      final pos = pegPositions[i];
      final bool isLeft = i < 3;
      final bool isSelected = i == selectedIndex;

      final double keyX = isLeft ? pos.dx - 32 : pos.dx + 32;

      // Shaft connection
      canvas.drawLine(
        pos,
        Offset(keyX, pos.dy),
        Paint()
          ..color = const Color(0xFF90A4AE)
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round,
      );

      // Keystone Pearloid Button
      final RRect buttonRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(keyX, pos.dy), width: 15, height: 24),
        const Radius.circular(5),
      );

      final Paint buttonPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSelected
              ? [
                  statusColor.withOpacity(0.9),
                  statusColor,
                  statusColor.withOpacity(0.7),
                ]
              : [
                  const Color(0xFFFFF9E6),
                  const Color(0xFFE8DEC0),
                  const Color(0xFFC7BBA0),
                ],
        ).createShader(buttonRRect.outerRect);

      canvas.drawRRect(buttonRRect, buttonPaint);
      canvas.drawRRect(
        buttonRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = isSelected ? statusColor : Colors.black45
          ..strokeWidth = 1.0,
      );

      // Hex Bushing Base
      canvas.drawCircle(
        pos,
        12.5,
        Paint()
          ..color = const Color(0xFF607D8B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(pos, 11.5, chromeGradient);

      // Peg post cylinder
      canvas.drawCircle(pos, 7.5, Paint()..color = const Color(0xFFCFD8DC));
      canvas.drawCircle(pos, 5.0, Paint()..color = const Color(0xFF37474F));
      canvas.drawCircle(pos, 2.5, Paint()..color = const Color(0xFF111111));

      // Active halo on selected peg
      if (isSelected) {
        canvas.drawCircle(
          pos,
          16,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = statusColor.withOpacity(0.8)
            ..strokeWidth = 2.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // 12. Highly Textured Strings with Winding Coils, Standing Waves & Shadows
    final double stringNutStartX = w * 0.29;
    final double stringNutSpacing = (w * 0.42) / 5;

    for (int i = 0; i < strings.length; i++) {
      final bool isSelected = i == selectedIndex;
      final string = strings[i];
      final double nutX = stringNutStartX + (i * stringNutSpacing);
      final Offset nutPos = Offset(nutX, h * 0.77);
      final Offset pegPos = pegPositions[i];

      final double gauge = string.gauge;

      // Drop shadow from string onto headstock face
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.38)
        ..strokeWidth = gauge + 0.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(
        Offset(nutPos.dx + 2, nutPos.dy + 3),
        Offset(pegPos.dx + 2, pegPos.dy + 3),
        shadowPaint,
      );

      // Bronze wound texture for 6th, 5th, 4th strings vs Steel for 1st, 2nd, 3rd
      Color coreColor;
      if (isSelected) {
        coreColor = statusColor;
      } else if (string.isWound) {
        coreColor = const Color(0xFFD49E50); // Warm phosphor bronze
      } else {
        coreColor = const Color(0xFFE6ECF2); // Polished nickel steel
      }

      final Paint stringPaint = Paint()
        ..color = coreColor
        ..strokeWidth = isSelected ? gauge + 0.9 : gauge
        ..strokeCap = StrokeCap.round;

      // Glow effect if selected string
      if (isSelected) {
        canvas.drawLine(
          nutPos,
          pegPos,
          Paint()
            ..color = statusColor.withOpacity(0.6)
            ..strokeWidth = gauge + 6.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Harmonic standing wave vibration when sound is detected
      if (isSelected && isVibrating) {
        final double waveAmp =
            math.sin(vibrationPhase * math.pi * 2) * 3.5;
        final Path wavePath = Path();
        wavePath.moveTo(nutPos.dx, nutPos.dy);
        wavePath.quadraticBezierTo(
          (nutPos.dx + pegPos.dx) / 2 + waveAmp,
          (nutPos.dy + pegPos.dy) / 2,
          pegPos.dx,
          pegPos.dy,
        );
        canvas.drawPath(wavePath, stringPaint);
      } else {
        canvas.drawLine(nutPos, pegPos, stringPaint);
      }

      // Straight string extension across fretboard below nut
      canvas.drawLine(
        nutPos,
        Offset(nutX, h),
        stringPaint,
      );

      // Coiled wire loops wrapped around peg post
      final Paint coilPaint = Paint()
        ..color = coreColor.withOpacity(0.85)
        ..strokeWidth = math.max(1.0, gauge * 0.6)
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pegPos, 8.5, coilPaint);
      canvas.drawCircle(pegPos, 9.8, coilPaint);
    }
  }

  @override
  bool shouldRepaint(covariant UltraRealisticHeadstockPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.isVibrating != isVibrating ||
        oldDelegate.vibrationPhase != vibrationPhase;
  }
}
