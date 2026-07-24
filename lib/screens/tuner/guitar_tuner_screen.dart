import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:audioplayers/audioplayers.dart';
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

  const GuitarString({
    required this.index,
    required this.noteName,
    required this.octave,
    required this.frequency,
    required this.label,
    this.isWound = false,
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
      name: 'Standard (EADGBE)',
      description: 'Classic 6-string guitar standard tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'E',
            octave: 2,
            frequency: 82.41,
            label: '6th (Low E)',
            isWound: true),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false),
        GuitarString(
            index: 4,
            noteName: 'B',
            octave: 3,
            frequency: 246.94,
            label: '2nd (B)',
            isWound: false),
        GuitarString(
            index: 5,
            noteName: 'E',
            octave: 4,
            frequency: 329.63,
            label: '1st (High E)',
            isWound: false),
      ],
    ),
    TuningPreset(
      name: 'Drop D (DADGBE)',
      description: 'Heavy rock / metal tuning with low D string',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false),
        GuitarString(
            index: 4,
            noteName: 'B',
            octave: 3,
            frequency: 246.94,
            label: '2nd (B)',
            isWound: false),
        GuitarString(
            index: 5,
            noteName: 'E',
            octave: 4,
            frequency: 329.63,
            label: '1st (High E)',
            isWound: false),
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
            isWound: true),
        GuitarString(
            index: 1,
            noteName: 'G#',
            octave: 2,
            frequency: 103.83,
            label: '5th (Ab)',
            isWound: true),
        GuitarString(
            index: 2,
            noteName: 'C#',
            octave: 3,
            frequency: 138.59,
            label: '4th (Db)',
            isWound: true),
        GuitarString(
            index: 3,
            noteName: 'F#',
            octave: 3,
            frequency: 185.00,
            label: '3rd (Gb)',
            isWound: false),
        GuitarString(
            index: 4,
            noteName: 'A#',
            octave: 3,
            frequency: 233.08,
            label: '2nd (Bb)',
            isWound: false),
        GuitarString(
            index: 5,
            noteName: 'D#',
            octave: 4,
            frequency: 311.13,
            label: '1st (Eb)',
            isWound: false),
      ],
    ),
    TuningPreset(
      name: 'Open D (DADF#AD)',
      description: 'Acoustic fingerstyle open resonant chord',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true),
        GuitarString(
            index: 1,
            noteName: 'A',
            octave: 2,
            frequency: 110.00,
            label: '5th (A)',
            isWound: true),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true),
        GuitarString(
            index: 3,
            noteName: 'F#',
            octave: 3,
            frequency: 185.00,
            label: '3rd (F#)',
            isWound: false),
        GuitarString(
            index: 4,
            noteName: 'A',
            octave: 3,
            frequency: 220.00,
            label: '2nd (A)',
            isWound: false),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false),
      ],
    ),
    TuningPreset(
      name: 'Open G (DGDGBD)',
      description: 'Keith Richards / Blues slide guitar tuning',
      strings: const [
        GuitarString(
            index: 0,
            noteName: 'D',
            octave: 2,
            frequency: 73.42,
            label: '6th (Low D)',
            isWound: true),
        GuitarString(
            index: 1,
            noteName: 'G',
            octave: 2,
            frequency: 98.00,
            label: '5th (G)',
            isWound: true),
        GuitarString(
            index: 2,
            noteName: 'D',
            octave: 3,
            frequency: 146.83,
            label: '4th (D)',
            isWound: true),
        GuitarString(
            index: 3,
            noteName: 'G',
            octave: 3,
            frequency: 196.00,
            label: '3rd (G)',
            isWound: false),
        GuitarString(
            index: 4,
            noteName: 'B',
            octave: 3,
            frequency: 246.94,
            label: '2nd (B)',
            isWound: false),
        GuitarString(
            index: 5,
            noteName: 'D',
            octave: 4,
            frequency: 293.66,
            label: '1st (High D)',
            isWound: false),
      ],
    ),
  ];

  late TuningPreset _currentPreset;
  int _selectedStringIndex = 0;
  bool _isAutoMode = true;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final PitchDetector _pitchDetector =
      PitchDetector(audioSampleRate: 44100, bufferSize: 2048);
  final AudioPlayer _soundPlayer = AudioPlayer();
  StreamSubscription<Uint8List>? _streamSub;
  final List<int> _audioBuffer = [];
  static const int _targetBufferBytes = 4096;

  final List<double> _pitchHistory = [];
  static const int _historyCapacity = 5;
  double _filteredPitch = 0.0;
  int _autoStringCandidate = -1;
  int _autoStringCandidateCount = 0;

  bool _isListening = false;
  double _currentPitch = 0.0;
  double _centsOffset = 0.0;
  bool _isInTune = false;
  bool _wasInTuneLastFrame = false;

  int _inTuneHoldCount = 0;
  static const int _requiredHoldFrames = 3;
  double _rangeHoldProgress = 0.0;
  bool _beepTriggeredForCurrentHold = false;

  late AnimationController _pulseController;
  late AnimationController _stringVibrationController;
  late AnimationController _needleController;
  double _animatedCents = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPreset = _presets.first;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _stringVibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _initMicAndStartTuner();
  }

  @override
  void dispose() {
    _stopListening();
    _soundPlayer.dispose();
    _pulseController.dispose();
    _stringVibrationController.dispose();
    _needleController.dispose();
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
      _streamSub = stream.listen((data) async {
        _audioBuffer.addAll(data);

        while (_audioBuffer.length >= _targetBufferBytes) {
          final chunk =
              Uint8List.fromList(_audioBuffer.sublist(0, _targetBufferBytes));
          _audioBuffer.removeRange(0, _targetBufferBytes);

          double sumSquares = 0;
          for (int i = 0; i < chunk.length; i += 2) {
            int sample = chunk[i] | (chunk[i + 1] << 8);
            if (sample >= 32768) sample -= 65536;
            sumSquares += sample * sample;
          }
          final rms = math.sqrt(sumSquares / (chunk.length / 2));

          if (rms < 85.0) {
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
            final result = await _pitchDetector.getPitchFromIntBuffer(chunk);
            if (result.pitched &&
                result.pitch >= 55.0 &&
                result.pitch <= 1100.0) {
              _processPitch(result.pitch);
            }
          } catch (e) {
            debugPrint('Pitch detection error: $e');
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

    List<double> sortedPitches = List.from(_pitchHistory)..sort();
    double medianPitch = sortedPitches[sortedPitches.length ~/ 2];

    if (_filteredPitch == 0.0 || (_filteredPitch - medianPitch).abs() > 35.0) {
      _filteredPitch = medianPitch;
    } else {
      _filteredPitch = _filteredPitch * 0.60 + medianPitch * 0.40;
    }

    if (_isAutoMode) {
      double minDiff = double.infinity;
      int bestIdx = _selectedStringIndex;
      for (int i = 0; i < _currentPreset.strings.length; i++) {
        final string = _currentPreset.strings[i];
        final diff = (_filteredPitch - string.frequency).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestIdx = i;
        }
      }

      if (bestIdx != _selectedStringIndex) {
        if (_autoStringCandidate == bestIdx) {
          _autoStringCandidateCount++;
          if (_autoStringCandidateCount >= 3) {
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

    GuitarString targetString = _currentPreset.strings[_selectedStringIndex];

    double cents =
        1200.0 * (math.log(_filteredPitch / targetString.frequency) / math.ln2);
    cents = cents.clamp(-50.0, 50.0);

    if (cents.abs() < 0.8) cents = 0.0;

    final bool currentlyInTune = cents.abs() <= 3.5;

    if (currentlyInTune) {
      _inTuneHoldCount++;
      _rangeHoldProgress = (_inTuneHoldCount / _requiredHoldFrames).clamp(0.0, 1.0);
      if (_inTuneHoldCount >= _requiredHoldFrames && !_beepTriggeredForCurrentHold) {
        HapticFeedback.mediumImpact();
        _playTunedPitchBeep(targetString.frequency);
        _beepTriggeredForCurrentHold = true;
      }
    } else {
      _inTuneHoldCount = 0;
      _rangeHoldProgress = 0.0;
      _beepTriggeredForCurrentHold = false;
    }
    _wasInTuneLastFrame = currentlyInTune;

    setState(() {
      _currentPitch = _filteredPitch;
      _centsOffset = cents;
      _animatedCents = cents;
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
      statusColor = const Color(0xFFFF3D00);
    } else {
      statusColor = const Color(0xFF7C4DFF);
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090B10) : const Color(0xFFF4F6FC),
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
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(20), vertical: context.w(4)),
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
                                fontSize: context.sp(14),
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              preset.description,
                              style: TextStyle(
                                fontSize: context.sp(11),
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
            SizedBox(height: context.w(12)),
            Expanded(
              flex: 5,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInTune)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.12)
                            .animate(_pulseController),
                        child: Container(
                          width: context.w(250),
                          height: context.w(250),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF00E676).withOpacity(0.35),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    CustomPaint(
                      size: Size(context.w(270), context.w(270)),
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
                                fontSize: context.sp(56),
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '${targetString.octave}',
                              style: GoogleFonts.outfit(
                                fontSize: context.sp(22),
                                fontWeight: FontWeight.w800,
                                color: statusColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.w(4)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                              horizontal: context.w(14),
                              vertical: context.w(5)),
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
                              fontSize: context.sp(11),
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: context.w(8)),
                        Text(
                          _currentPitch > 0
                              ? '${_currentPitch.toStringAsFixed(1)} Hz  /  ${targetString.frequency.toStringAsFixed(1)} Hz'
                              : 'Target: ${targetString.frequency.toStringAsFixed(1)} Hz',
                          style: GoogleFonts.outfit(
                            fontSize: context.sp(11.5),
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                      fontSize: context.sp(13),
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
            SizedBox(height: context.w(6)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(36)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _beepTriggeredForCurrentHold
                            ? Icons.check_circle_rounded
                            : Icons.timelapse_rounded,
                        size: context.w(14),
                        color: _beepTriggeredForCurrentHold
                            ? const Color(0xFF00E676)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      SizedBox(width: context.w(6)),
                      Text(
                        _beepTriggeredForCurrentHold
                            ? 'TUNED ✓'
                            : _rangeHoldProgress > 0
                                ? 'HOLD ${(_rangeHoldProgress * 100).toInt()}%'
                                : 'RANGE HOLD',
                        style: GoogleFonts.outfit(
                          fontSize: context.sp(10),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: _beepTriggeredForCurrentHold
                              ? const Color(0xFF00E676)
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.w(4)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.w(4)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: context.w(5),
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
                ],
              ),
            ),
            SizedBox(height: context.w(6)),
            SizedBox(
              height: context.w(44),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                itemCount: _currentPreset.strings.length,
                itemBuilder: (context, idx) {
                  final str = _currentPreset.strings[idx];
                  final isSelected = idx == _selectedStringIndex;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.w(4)),
                    child: ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        '${str.fullNote} (${str.label.split(" ").first})',
                        style: GoogleFonts.outfit(
                          fontSize: context.sp(12),
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
            SizedBox(height: context.w(10)),
            Expanded(
              flex: 6,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(16), vertical: context.w(6)),
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
    final string = _currentPreset.strings[index];
    final isSelected = index == _selectedStringIndex;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _selectString(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: context.w(70),
          height: context.w(55),
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
                  fontSize: context.sp(13),
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
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0xFF1A202C) : const Color(0xFFE2E8F0);

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
        ..strokeWidth = 10
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

      final double tickLength = isCenter ? 16 : (isMajor ? 12 : 8);
      tickPaint.strokeWidth = isCenter ? 3.5 : (isMajor ? 2.0 : 1.2);
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
      center + (radius - 22) * math.cos(needleAngle),
      center + (radius - 22) * math.sin(needleAngle),
    );

    final Paint needlePaint = Paint()
      ..color =
          hasPitch ? statusColor : (isDark ? Colors.white30 : Colors.black26)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(centerOffset, needleTip, needlePaint);

    canvas.drawCircle(centerOffset, 8, Paint()..color = statusColor);
    canvas.drawCircle(
      centerOffset,
      4,
      Paint()..color = isDark ? const Color(0xFF090B10) : Colors.white,
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

    final Paint mahoganyShader = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF261410),
                const Color(0xFF1A0C09),
                const Color(0xFF0D0604),
              ]
            : [
                const Color(0xFF5C2D1F),
                const Color(0xFF3B1A11),
                const Color(0xFF240F0A),
              ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final Path headstockPath = Path();
    headstockPath.moveTo(w * 0.28, h * 0.98);
    headstockPath.lineTo(w * 0.22, h * 0.16);
    headstockPath.quadraticBezierTo(w * 0.18, h * 0.03, w * 0.38, h * 0.05);
    headstockPath.quadraticBezierTo(w * 0.50, h * 0.12, w * 0.62, h * 0.05);
    headstockPath.quadraticBezierTo(w * 0.82, h * 0.03, w * 0.78, h * 0.16);
    headstockPath.lineTo(w * 0.72, h * 0.98);
    headstockPath.close();

    canvas.drawPath(
      headstockPath,
      Paint()
        ..color = Colors.black.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawPath(headstockPath, mahoganyShader);

    final Paint edgeBevel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.35),
          Colors.amber.withOpacity(0.15),
          Colors.black.withOpacity(0.7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(headstockPath, edgeBevel);

    final Path trussRodPath = Path();
    trussRodPath.moveTo(w * 0.46, h * 0.65);
    trussRodPath.lineTo(w * 0.54, h * 0.65);
    trussRodPath.lineTo(w * 0.52, h * 0.75);
    trussRodPath.lineTo(w * 0.48, h * 0.75);
    trussRodPath.close();
    canvas.drawPath(trussRodPath, Paint()..color = const Color(0xFF111111));
    canvas.drawPath(
        trussRodPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white24
          ..strokeWidth = 1.0);

    final Rect fretboardRect = Rect.fromLTRB(w * 0.27, h * 0.82, w * 0.73, h);
    final Paint ebonyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF181514), Color(0xFF0C0A09)],
      ).createShader(fretboardRect);
    canvas.drawRect(fretboardRect, ebonyPaint);

    final Rect nutRect =
        Rect.fromLTRB(w * 0.265, h * 0.78, w * 0.735, h * 0.82);
    final Paint boneNutPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEDE8D8), Color(0xFFC7C1B0)],
      ).createShader(nutRect);
    canvas.drawRRect(RRect.fromRectAndRadius(nutRect, const Radius.circular(3)),
        boneNutPaint);

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
        colors: [Color(0xFFFFFFFF), Color(0xFF9E9E9E), Color(0xFF424242)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    for (int i = 0; i < pegPositions.length; i++) {
      final pos = pegPositions[i];
      final bool isLeft = i < 3;
      final bool isSelected = i == selectedIndex;

      final double keyX = isLeft ? pos.dx - 32 : pos.dx + 32;
      canvas.drawLine(
        pos,
        Offset(keyX, pos.dy),
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..strokeWidth = 4.0,
      );

      final RRect paddleRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(keyX, pos.dy), width: 14, height: 22),
        const Radius.circular(6),
      );
      canvas.drawRRect(paddleRRect, chromeGradient);

      canvas.drawCircle(pos, 11, chromeGradient);
      canvas.drawCircle(
        pos,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = isSelected ? statusColor : Colors.black45
          ..strokeWidth = isSelected ? 2.5 : 1.0,
      );

      canvas.drawCircle(pos, 3.5, Paint()..color = const Color(0xFF111111));

      if (isSelected) {
        canvas.drawCircle(
          pos,
          15,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = statusColor.withOpacity(0.7)
            ..strokeWidth = 2.0,
        );
      }
    }

    final double stringNutStartX = w * 0.29;
    final double stringNutSpacing = (w * 0.42) / 5;

    for (int i = 0; i < strings.length; i++) {
      final bool isSelected = i == selectedIndex;
      final string = strings[i];
      final double nutX = stringNutStartX + (i * stringNutSpacing);
      final Offset nutPos = Offset(nutX, h * 0.78);
      final Offset pegPos = pegPositions[i];

      final double gaugeThickness = 3.4 - (i * 0.45);

      Color stringColor =
          string.isWound ? const Color(0xFFD4A359) : const Color(0xFFE0E6ED);

      if (isSelected) {
        stringColor = statusColor;
      }

      final Paint stringPaint = Paint()
        ..color = stringColor
        ..strokeWidth = isSelected ? gaugeThickness + 0.8 : gaugeThickness
        ..strokeCap = StrokeCap.round;

      if (isSelected) {
        canvas.drawLine(
          nutPos,
          pegPos,
          Paint()
            ..color = statusColor.withOpacity(0.5)
            ..strokeWidth = gaugeThickness + 5.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      if (isSelected && isVibrating) {
        final double vibOffset = math.sin(vibrationPhase * math.pi * 2) * 3.0;
        final Path vibPath = Path();
        vibPath.moveTo(nutPos.dx, nutPos.dy);
        vibPath.quadraticBezierTo(
          (nutPos.dx + pegPos.dx) / 2 + vibOffset,
          (nutPos.dy + pegPos.dy) / 2,
          pegPos.dx,
          pegPos.dy,
        );
        canvas.drawPath(vibPath, stringPaint);
      } else {
        canvas.drawLine(nutPos, pegPos, stringPaint);
      }

      canvas.drawLine(
        nutPos,
        Offset(nutX, h),
        stringPaint,
      );
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
