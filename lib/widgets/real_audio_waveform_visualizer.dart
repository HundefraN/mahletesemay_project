import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../services/audio_waveform_extractor_service.dart';

/// Ultra-responsive, real physical audio waveform visualizer with interactive
/// tap-and-drag scrubbing and smooth playback synchronization.
class RealAudioWaveformVisualizer extends StatefulWidget {
  final String audioUrl;
  final String? localFilePath;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final ValueChanged<Duration>? onSeek;
  final double height;
  final int barCount;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? inactiveColor;
  final bool enableSeek;

  const RealAudioWaveformVisualizer({
    super.key,
    required this.audioUrl,
    this.localFilePath,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    this.onSeek,
    this.height = 40.0,
    this.barCount = 42,
    this.primaryColor,
    this.secondaryColor,
    this.inactiveColor,
    this.enableSeek = true,
  });

  @override
  State<RealAudioWaveformVisualizer> createState() =>
      _RealAudioWaveformVisualizerState();
}

class _RealAudioWaveformVisualizerState
    extends State<RealAudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  final AudioWaveformExtractorService _extractorService =
      AudioWaveformExtractorService();

  List<double>? _waveform;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadWaveform();
  }

  @override
  void didUpdateWidget(covariant RealAudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.localFilePath != widget.localFilePath ||
        oldWidget.barCount != widget.barCount) {
      _loadWaveform();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadWaveform() async {
    setState(() => _isLoading = true);
    try {
      final samples = await _extractorService.extractWaveform(
        audioSource: widget.audioUrl,
        localFilePath: widget.localFilePath,
        targetSamples: widget.barCount,
      );
      if (mounted) {
        setState(() {
          _waveform = samples;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _waveform = List.filled(widget.barCount, 0.15);
          _isLoading = false;
        });
      }
    }
  }

  void _handleSeek(Offset localPosition, double totalWidth) {
    if (!widget.enableSeek ||
        widget.onSeek == null ||
        widget.totalDuration.inMilliseconds <= 0 ||
        totalWidth <= 0) {
      return;
    }

    final double progress = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (progress * widget.totalDuration.inMilliseconds).round();
    HapticFeedback.selectionClick();
    widget.onSeek!(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final secondary = widget.secondaryColor ?? theme.colorScheme.secondary;
    final inactive = widget.inactiveColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2);

    final double progress = (widget.totalDuration.inMilliseconds > 0)
        ? (widget.currentPosition.inMilliseconds /
                widget.totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    if (_isLoading) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Shimmer.fromColors(
          baseColor: inactive.withValues(alpha: 0.15),
          highlightColor: primary.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.barCount, (index) {
              final defaultHeight =
                  widget.height * (0.2 + (0.4 * (index % 4) / 4.0));
              return Container(
                width: 3.2,
                height: defaultHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              );
            }),
          ),
        ),
      );
    }

    final waveformData =
        _waveform ?? List.filled(widget.barCount, 0.15);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _handleSeek(details.localPosition, totalWidth),
          onHorizontalDragUpdate: (details) =>
              _handleSeek(details.localPosition, totalWidth),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RealWaveformPainter(
                    waveform: waveformData,
                    progress: progress,
                    isPlaying: widget.isPlaying,
                    pulseValue: _pulseController.value,
                    primaryColor: primary,
                    secondaryColor: secondary,
                    inactiveColor: inactive,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RealWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final bool isPlaying;
  final double pulseValue;
  final Color primaryColor;
  final Color secondaryColor;
  final Color inactiveColor;

  _RealWaveformPainter({
    required this.waveform,
    required this.progress,
    required this.isPlaying,
    required this.pulseValue,
    required this.primaryColor,
    required this.secondaryColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final double w = size.width;
    final double h = size.height;
    final double midY = h / 2;
    final int count = waveform.length;

    // Responsive bar sizing
    final double totalSlotWidth = w / count;
    final double barWidth = math.max(2.2, totalSlotWidth * 0.62);

    final Paint activePaint = Paint()..style = PaintingStyle.fill;
    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    // Glowing Shader for Active Region
    final Rect fullRect = Rect.fromLTWH(0, 0, w, h);
    activePaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        primaryColor,
        secondaryColor,
      ],
    ).createShader(fullRect);

    final double currentPlayheadX = progress * w;

    for (int i = 0; i < count; i++) {
      final double barCenterX = (i * totalSlotWidth) + (totalSlotWidth / 2);
      final double normalizedAmp = waveform[i].clamp(0.08, 1.0);

      // Height calculation
      double barHeight = normalizedAmp * (h * 0.92);

      final bool isBarPlayed = barCenterX <= currentPlayheadX;
      final bool isActivePlayhead = (barCenterX - currentPlayheadX).abs() <=
          (totalSlotWidth * 1.1);

      // Micro-animation for active playing bar
      if (isActivePlayhead && isPlaying) {
        barHeight = (barHeight * (1.0 + (pulseValue * 0.15))).clamp(3.0, h);
      }

      final double top = midY - (barHeight / 2);
      final double bottom = midY + (barHeight / 2);
      final double left = barCenterX - (barWidth / 2);
      final double right = barCenterX + (barWidth / 2);

      final RRect barRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        Radius.circular(barWidth / 2),
      );

      if (isBarPlayed) {
        // Draw active bar with slight neon glow if playing
        if (isActivePlayhead && isPlaying) {
          final Paint glowPaint = Paint()
            ..color = primaryColor.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
          canvas.drawRRect(barRRect, glowPaint);
        }
        canvas.drawRRect(barRRect, activePaint);
      } else {
        canvas.drawRRect(barRRect, inactivePaint);
      }
    }

    // Subtle Glowing Playhead Needle
    if (progress > 0.001 && progress < 0.999) {
      final double playheadX = currentPlayheadX.clamp(1.0, w - 1.0);
      final Paint needlePaint = Paint()
        ..color = isPlaying ? secondaryColor : primaryColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final Paint needleGlow = Paint()
        ..color = (isPlaying ? secondaryColor : primaryColor).withValues(alpha: 0.4)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawLine(
        Offset(playheadX, 2),
        Offset(playheadX, h - 2),
        needleGlow,
      );
      canvas.drawLine(
        Offset(playheadX, 2),
        Offset(playheadX, h - 2),
        needlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RealWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.waveform != waveform ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
