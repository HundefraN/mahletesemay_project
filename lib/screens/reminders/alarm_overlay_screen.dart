import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/alarm_service.dart';
import '../settings/service_reminder_screen.dart';

/// Full-screen alarm overlay presented when an exact service reminder fires.
/// Displays directly in the center of the screen with glowing wave animations,
/// looping audio playback, haptic pulses, and clear Snooze / Dismiss controls.
class AlarmOverlayScreen extends StatefulWidget {
  final ServiceAlarmMetadata metadata;

  const AlarmOverlayScreen({
    super.key,
    required this.metadata,
  });

  @override
  State<AlarmOverlayScreen> createState() => _AlarmOverlayScreenState();
}

class _AlarmOverlayScreenState extends State<AlarmOverlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start ringing audio and repeating vibration
    AlarmService.startAlarmAudioAndVibration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    AlarmService.stopAlarmAudioAndVibration();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await AlarmService.dismissAlarm(widget.metadata.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSnooze() async {
    await AlarmService.snoozeAlarm(metadata: widget.metadata, minutes: 10);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm snoozed for 10 minutes.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _handleOpenService() async {
    await AlarmService.stopAlarmAudioAndVibration();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ServiceReminderScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat.jm().format(DateTime.now());
    final serviceDateStr = DateFormat.yMMMEd().format(widget.metadata.serviceDateTime);
    final serviceTimeStr = DateFormat.jm().format(widget.metadata.serviceDateTime);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background rich ambient gradient with glassmorphism blur
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF1E3A8A), // Deep royal blue
                  Color(0xFF0F172A), // Midnight
                  Color(0xFF020617), // Pitch black
                ],
              ),
            ),
          ),

          // Pulsing ambient background rings
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 280 * _scaleAnimation.value,
                      height: 280 * _scaleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08 * _glowAnimation.value),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.15 * _glowAnimation.value),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 220 * _scaleAnimation.value,
                      height: 220 * _scaleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12 * _glowAnimation.value),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.25 * _glowAnimation.value),
                          width: 2,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Urgency Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEF4444),
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1.4, 1.4),
                              ),
                          const SizedBox(width: 8),
                          Text(
                            'WORSHIP SERVICE REMINDER',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFCA5A5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

                    const SizedBox(height: 32),

                    // Animated Glowing Alarm Bell
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.6 * _glowAnimation.value),
                                  blurRadius: 36,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              size: 58,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Large Digital Clock
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 8),

                    // Service Title
                    Text(
                      widget.metadata.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 16),

                    // Glassmorphic Details Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event_available_rounded,
                                      size: 18, color: Color(0xFF60A5FA)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$serviceDateStr at $serviceTimeStr',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFE2E8F0),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.metadata.notes != null &&
                                  widget.metadata.notes!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.notes_rounded,
                                        size: 18, color: Color(0xFFFBBF24)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.metadata.notes!,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFCBD5E1),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 36),

                    // Action Buttons (Dismiss & Snooze)
                    Row(
                      children: [
                        // Snooze Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleSnooze,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.06),
                            ),
                            icon: const Icon(Icons.snooze_rounded, size: 22),
                            label: Text(
                              'Snooze (10m)',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Dismiss Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleDismiss,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 6,
                              shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.alarm_off_rounded, size: 22),
                            label: Text(
                              'Dismiss',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.15),

                    const SizedBox(height: 16),

                    // Link to open service reminder screen
                    TextButton.icon(
                      onPressed: _handleOpenService,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF93C5FD),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        'View Rehearsal Details & Songs',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
