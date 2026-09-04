import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

enum WaveformStyle { oscilloscope, glowingRibbon, frequencyBars }

/// Ultra-responsive, smooth real-time audio waveform & frequency visualizer.
class AudioWaveformVisualizer extends StatefulWidget {
  final Float64List? waveform;
  final double rms;
  final double pitch;
  final bool isListening;
  final Color? primaryColor;
  final Color? secondaryColor;
  final double height;
  final WaveformStyle style;

  const AudioWaveformVisualizer({
    super.key,
    this.waveform,
    this.rms = 0.0,
    this.pitch = 0.0,
    this.isListening = true,
    this.primaryColor,
    this.secondaryColor,
    this.height = 64.0,
    this.style = WaveformStyle.oscilloscope,
  });

  @override
  State<AudioWaveformVisualizer> createState() =>
      _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleAnimController;

  @override
  void initState() {
    super.initState();
    _idleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _idleAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final secondary = widget.secondaryColor ?? theme.colorScheme.secondary;

    return AnimatedBuilder(
      animation: _idleAnimController,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _WaveformCustomPainter(
              waveform: widget.waveform,
              rms: widget.rms,
              hasPitch: widget.pitch > 0,
              isListening: widget.isListening,
              primaryColor: primary,
              secondaryColor: secondary,
              idlePhase: _idleAnimController.value * 2 * math.pi,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformCustomPainter extends CustomPainter {
  final Float64List? waveform;
  final double rms;
  final bool hasPitch;
  final bool isListening;
  final Color primaryColor;
  final Color secondaryColor;
  final double idlePhase;
  final WaveformStyle style;

  _WaveformCustomPainter({
    required this.waveform,
    required this.rms,
    required this.hasPitch,
    required this.isListening,
    required this.primaryColor,
    required this.secondaryColor,
    required this.idlePhase,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double midY = h / 2;

    if (style == WaveformStyle.frequencyBars) {
      _drawFrequencyBars(canvas, size, w, h, midY);
      return;
    }

    _drawOscilloscopeWaveform(canvas, size, w, h, midY);
  }

  void _drawOscilloscopeWaveform(
      Canvas canvas, Size size, double w, double h, double midY) {
    final Path wavePath = Path();
    final Path fillPath = Path();

    final bool hasLiveWave =
        waveform != null && waveform!.isNotEmpty && rms > 20.0;
    final int points = hasLiveWave ? waveform!.length : 64;

    final double maxAmplitude = (h * 0.45);
    final double ampScale = (rms / 250.0).clamp(0.15, 1.0);

    for (int i = 0; i < points; i++) {
      final double x = (i / (points - 1)) * w;
      double yOffset = 0.0;

      if (hasLiveWave) {
        // Real PCM microphone waveform
        final rawVal = waveform![i];
        yOffset = rawVal * maxAmplitude * ampScale;
      } else if (isListening) {
        // Subtle ambient breathing idle wave
        final normalizedX = (i / points) * 4 * math.pi;
        yOffset = math.sin(normalizedX + idlePhase) * (h * 0.08);
      }

      final double y = (midY + yOffset).clamp(2.0, h - 2.0);

      if (i == 0) {
        wavePath.moveTo(x, y);
        fillPath.moveTo(x, midY);
        fillPath.lineTo(x, y);
      } else {
        wavePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, midY);
    fillPath.close();

    // 1. Shaded Gradient Fill Under Waveform
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: hasPitch ? 0.35 : 0.15),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 2. Glowing Ambient Neon Blur behind line
    final Paint glowPaint = Paint()
      ..color = (hasPitch ? secondaryColor : primaryColor).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = hasPitch ? 4.0 : 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(wavePath, glowPaint);

    // 3. Crisp Foreground Stroke
    final Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          secondaryColor,
          primaryColor,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = hasPitch ? 2.2 : 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(wavePath, linePaint);

    // 4. Subtle Centerline Baseline
    final Paint centerLinePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), centerLinePaint);
  }

  void _drawFrequencyBars(
      Canvas canvas, Size size, double w, double h, double midY) {
    const int barCount = 32;
    final double barWidth = (w / barCount) * 0.65;
    final double spacing = (w / barCount) * 0.35;

    final bool hasLiveWave =
        waveform != null && waveform!.isNotEmpty && rms > 20.0;

    for (int i = 0; i < barCount; i++) {
      final double x = i * (barWidth + spacing) + spacing / 2;
      double barHeight = h * 0.08;

      if (hasLiveWave) {
        final sampleIdx = (i * (waveform!.length / barCount)).toInt();
        final rawAmp = waveform![sampleIdx.clamp(0, waveform!.length - 1)].abs();
        barHeight = (rawAmp * h * 0.9).clamp(h * 0.08, h * 0.95);
      } else if (isListening) {
        final waveVal =
            math.sin(i * 0.3 + idlePhase) * 0.5 + 0.5;
        barHeight = (h * 0.12) + waveVal * (h * 0.18);
      }

      final top = midY - barHeight / 2;
      final bottom = midY + barHeight / 2;

      final RRect barRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, top, x + barWidth, bottom),
        Radius.circular(barWidth / 2),
      );

      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            secondaryColor,
            primaryColor,
          ],
        ).createShader(Rect.fromLTRB(x, top, x + barWidth, bottom));

      canvas.drawRRect(barRRect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformCustomPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.rms != rms ||
        oldDelegate.hasPitch != hasPitch ||
        oldDelegate.idlePhase != idlePhase ||
        oldDelegate.isListening != isListening;
  }
}
