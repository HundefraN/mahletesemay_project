import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/service_reminder_model.dart';
import 'package:mahlete_semay_project/providers/service_reminder_provider.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';

class ServiceReminderScreen extends StatelessWidget {
  const ServiceReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0D1B2A), const Color(0xFF0A1628)]
                : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFF)],
          ),
        ),
        child: Consumer<ServiceReminderProvider>(
          builder: (context, provider, child) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(theme, isDark, provider, l10n),
                provider.reminders.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context, l10n))
                    : SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          context.w(16),
                          context.w(8),
                          context.w(16),
                          context.w(100),
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final reminder = provider.reminders[index];
                              return _ReminderCard(reminder: reminder)
                                  .animate()
                                  .fadeIn(delay: (80 * index).ms)
                                  .slideY(
                                      begin: 0.15,
                                      curve: Curves.easeOutCubic);
                            },
                            childCount: provider.reminders.length,
                          ),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditReminderDialog(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        label: Text(l10n.newReminder,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add_alert_rounded),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
      ThemeData theme, bool isDark, ServiceReminderProvider provider, AppLocalizations l10n) {
    final upcoming = provider.upcomingReminders.length;
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: isDark
          ? const Color(0xFF0D1B2A).withOpacity(0.95)
          : const Color(0xFFF0F4FF).withOpacity(0.95),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(l10n.serviceReminders,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: theme.appBarTheme.titleTextStyle?.color,
            )),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.15),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 20),
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_on_rounded,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        upcoming == 0
                            ? 'No upcoming'
                            : '$upcoming active',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.12),
                    theme.colorScheme.primary.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.15)),
              ),
              child: Icon(Icons.alarm_off_rounded,
                  size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.noServiceReminders,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.headlineSmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noServiceRemindersDesc,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showAddEditReminderDialog(context),
              icon: const Icon(Icons.add_alert_rounded),
              label: Text(AppLocalizations.of(context)?.setYourFirstReminder ?? 'Set Your First Reminder',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }
}

// =============================================================================
// REMINDER CARD — Live countdown, urgency colors, expandable timeline
// =============================================================================

class _ReminderCard extends StatefulWidget {
  final ServiceReminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard>
    with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _isExpanded = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final diff = widget.reminder.serviceDateTime.difference(now);
    if (mounted) {
      setState(() {
        _remaining = diff;
      });

      // Pulse animation for imminent reminders (< 24 hours).
      if (diff.inHours < 24 && !diff.isNegative) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _urgencyColor(ThemeData theme) {
    if (_remaining.isNegative) return Colors.grey;
    if (_remaining.inHours < 24) return const Color(0xFFE53935); // Red
    if (_remaining.inDays < 3) return const Color(0xFFFFA726); // Amber
    return const Color(0xFF66BB6A); // Green
  }

  Color _urgencyGlow(ThemeData theme) {
    if (_remaining.isNegative) return Colors.grey.withOpacity(0.1);
    if (_remaining.inHours < 24) return const Color(0xFFE53935).withOpacity(0.15);
    if (_remaining.inDays < 3) return const Color(0xFFFFA726).withOpacity(0.12);
    return const Color(0xFF66BB6A).withOpacity(0.10);
  }

  String _urgencyLabel() {
    if (_remaining.isNegative) return 'Service Started';
    if (_remaining.inHours < 2) return 'STARTING SOON';
    if (_remaining.inHours < 24) return 'TODAY';
    if (_remaining.inDays == 1) return 'TOMORROW';
    return '${_remaining.inDays} DAYS LEFT';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final urgency = _urgencyColor(theme);
    final isPast = _remaining.isNegative;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        final glowOpacity =
            isPast ? 0.0 : (0.08 + pulseValue * 0.12);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (!isPast)
                BoxShadow(
                  color: urgency.withOpacity(glowOpacity),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1A2332).withOpacity(0.9),
                            const Color(0xFF162030).withOpacity(0.9),
                          ]
                        : [
                            Colors.white.withOpacity(0.85),
                            Colors.white.withOpacity(0.7),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: urgency.withOpacity(isPast ? 0.1 : 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Main card content
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                        child: Column(
                          children: [
                            _buildHeader(theme, urgency, isPast),
                            const SizedBox(height: 16),
                            if (!isPast) _buildCountdown(theme, urgency),
                            if (!isPast) const SizedBox(height: 16),
                            _buildDateTimeInfo(theme),
                            if (widget.reminder.notes != null &&
                                widget.reminder.notes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildNotes(theme),
                            ],
                            const SizedBox(height: 12),
                            _buildActionRow(theme, urgency, isPast),
                          ],
                        ),
                      ),
                    ),
                    // Expandable notification timeline
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _NotificationTimeline(
                        reminder: widget.reminder,
                        urgencyColor: urgency,
                      ),
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, Color urgency, bool isPast) {
    final alertCount = Provider.of<ServiceReminderProvider>(context)
        .scheduledAlertCount(widget.reminder);

    return Row(
      children: [
        // Animated alarm bell
        _AnimatedAlarmBell(
          urgencyColor: urgency,
          isImminent: _remaining.inHours < 24 && !isPast,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.reminder.title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: urgency.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _urgencyLabel(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: urgency,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (alertCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active_rounded,
                              size: 10, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$alertCount alert${alertCount == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Expand icon
        AnimatedRotation(
          turns: _isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown(ThemeData theme, Color urgency) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            urgency.withOpacity(0.08),
            urgency.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgency.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CountdownDigit(value: days, label: AppLocalizations.of(context)?.daysCountdown ?? 'DAYS', color: urgency),
          _CountdownSeparator(color: urgency),
          _CountdownDigit(value: hours, label: AppLocalizations.of(context)?.hoursCountdown ?? 'HRS', color: urgency),
          _CountdownSeparator(color: urgency),
          _CountdownDigit(value: minutes, label: AppLocalizations.of(context)?.minutesCountdown ?? 'MIN', color: urgency),
          _CountdownSeparator(color: urgency),
          _CountdownDigit(value: seconds, label: AppLocalizations.of(context)?.secondsCountdown ?? 'SEC', color: urgency),
        ],
      ),
    );
  }

  Widget _buildDateTimeInfo(ThemeData theme) {
    return Row(
      children: [
        _InfoChip(
          icon: Icons.calendar_today_rounded,
          text: DateFormat('EEE, MMM d, yyyy')
              .format(widget.reminder.serviceDateTime),
          theme: theme,
        ),
        const SizedBox(width: 10),
        _InfoChip(
          icon: Icons.access_time_filled_rounded,
          text: DateFormat('h:mm a').format(widget.reminder.serviceDateTime),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildNotes(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note_alt_outlined,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.reminder.notes!,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                fontStyle: FontStyle.italic,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(ThemeData theme, Color urgency, bool isPast) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tap to expand hint
        Text(
          _isExpanded ? 'Hide alert schedule' : 'Tap to see alert schedule',
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withOpacity(0.35),
            fontStyle: FontStyle.italic,
          ),
        ),
        Row(
          children: [
            _ActionButton(
              icon: Icons.edit_outlined,
              onTap: () => _showAddEditReminderDialog(context,
                  reminder: widget.reminder),
              theme: theme,
            ),
            const SizedBox(width: 4),
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              onTap: () => _confirmDelete(context),
              theme: theme,
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)?.cancelReminderPrompt ?? 'Cancel Reminder'),
          ],
        ),
        content: Text(
          'Cancel "${widget.reminder.title}"?\n\nAll scheduled alerts for this service will be removed.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.keepAction ?? 'Keep'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<ServiceReminderProvider>(context, listen: false)
                  .cancelReminder(widget.reminder.id);
              CustomSnackbar.show(
                  context, 'Reminder for "${widget.reminder.title}" cancelled.');
            },
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            child: Text(AppLocalizations.of(context)?.cancelReminderPrompt ?? 'Cancel Reminder'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COUNTDOWN DIGIT
// =============================================================================

class _CountdownDigit extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _CountdownDigit({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            value.toString().padLeft(2, '0'),
            key: ValueKey<int>(value),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.6),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _CountdownSeparator extends StatelessWidget {
  final Color color;
  const _CountdownSeparator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        ':',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: color.withOpacity(0.5),
        ),
      ),
    );
  }
}

// =============================================================================
// INFO CHIP
// =============================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: theme.colorScheme.primary.withOpacity(0.7)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ACTION BUTTON
// =============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDestructive;
  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.theme,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color.withOpacity(0.6)),
        ),
      ),
    );
  }
}

// =============================================================================
// ANIMATED ALARM BELL
// =============================================================================

class _AnimatedAlarmBell extends StatefulWidget {
  final Color urgencyColor;
  final bool isImminent;
  const _AnimatedAlarmBell({
    required this.urgencyColor,
    required this.isImminent,
  });

  @override
  State<_AnimatedAlarmBell> createState() => _AnimatedAlarmBellState();
}

class _AnimatedAlarmBellState extends State<_AnimatedAlarmBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isImminent) {
      _startRinging();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedAlarmBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isImminent && !oldWidget.isImminent) {
      _startRinging();
    } else if (!widget.isImminent && oldWidget.isImminent) {
      _controller.stop();
      _controller.reset();
    }
  }

  void _startRinging() {
    // Ring 3 times, pause, repeat
    Future<void> ring() async {
      if (!mounted) return;
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        await _controller.forward();
        await _controller.reverse();
      }
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && widget.isImminent) ring();
    }

    ring();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 0.15;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.urgencyColor.withOpacity(0.1),
          ),
          child: Transform.rotate(
            angle: (angle * 3.14159 * 2) *
                (_controller.status == AnimationStatus.forward ? 1 : -1),
            child: Icon(
              widget.isImminent
                  ? Icons.alarm_rounded
                  : Icons.alarm_outlined,
              color: widget.urgencyColor,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// NOTIFICATION TIMELINE — shows all 7 alert slots with status
// =============================================================================

class _NotificationTimeline extends StatelessWidget {
  final ServiceReminder reminder;
  final Color urgencyColor;
  const _NotificationTimeline({
    required this.reminder,
    required this.urgencyColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider =
        Provider.of<ServiceReminderProvider>(context, listen: false);
    final timeline = provider.getNotificationTimeline(reminder);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Alert Schedule',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(timeline.length, (index) {
            final slot = timeline[index];
            final isLast = index == timeline.length - 1;
            return _TimelineSlot(
              slot: slot,
              isLast: isLast,
              theme: theme,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineSlot extends StatelessWidget {
  final AlertSlotInfo slot;
  final bool isLast;
  final ThemeData theme;
  const _TimelineSlot({
    required this.slot,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final icon = _statusIcon();
    final isHighlighted = slot.status == AlertSlotStatus.nextUp;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: isHighlighted ? 28 : 22,
                  height: isHighlighted ? 28 : 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(isHighlighted ? 0.2 : 0.1),
                    border: Border.all(
                      color: color.withOpacity(isHighlighted ? 0.8 : 0.4),
                      width: isHighlighted ? 2.5 : 1.5,
                    ),
                  ),
                  child: Icon(icon, size: isHighlighted ? 14 : 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: isHighlighted
                  ? BoxDecoration(
                      color: color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.15)),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              slot.label,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isHighlighted
                                    ? color
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            if (slot.isAlarm) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFE53935).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ALARM',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE53935),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEE, MMM d · h:mm a')
                              .format(slot.dateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isHighlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEXT',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  if (slot.status == AlertSlotStatus.fired)
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: color.withOpacity(0.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (slot.status) {
      case AlertSlotStatus.fired:
        return Colors.grey;
      case AlertSlotStatus.nextUp:
        return const Color(0xFF1E88E5);
      case AlertSlotStatus.scheduled:
        return const Color(0xFF66BB6A);
      case AlertSlotStatus.skipped:
        return Colors.grey.withOpacity(0.5);
    }
  }

  IconData _statusIcon() {
    switch (slot.status) {
      case AlertSlotStatus.fired:
        return Icons.check_rounded;
      case AlertSlotStatus.nextUp:
        return Icons.notifications_active_rounded;
      case AlertSlotStatus.scheduled:
        return Icons.schedule_rounded;
      case AlertSlotStatus.skipped:
        return Icons.skip_next_rounded;
    }
  }
}

// =============================================================================
// ADD/EDIT DIALOG
// =============================================================================

void _showAddEditReminderDialog(BuildContext context,
    {ServiceReminder? reminder}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AddEditReminderDialog(reminder: reminder),
  );
}

class _AddEditReminderDialog extends StatefulWidget {
  final ServiceReminder? reminder;
  const _AddEditReminderDialog({this.reminder});

  @override
  State<_AddEditReminderDialog> createState() => _AddEditReminderDialogState();
}

class _AddEditReminderDialogState extends State<_AddEditReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDateTime;

  bool get isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.reminder!.title;
      _notesController.text = widget.reminder!.notes ?? '';
      _selectedDateTime = widget.reminder!.serviceDateTime;
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;

    if (!context.mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(pickedDate.year, pickedDate.month,
          pickedDate.day, pickedTime.hour, pickedTime.minute);
    });
  }

  bool _submitted = false;

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_selectedDateTime == null) return;
    if (_formKey.currentState!.validate()) {
      final provider =
          Provider.of<ServiceReminderProvider>(context, listen: false);

      if (provider.hasConflict(_selectedDateTime!,
          excludeReminderId: isEditing ? widget.reminder!.id : null)) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(AppLocalizations.of(context)?.confirmSchedule ?? 'Confirm Schedule'),
            content: const Text(
                'You already have a service scheduled for this hour. Are you sure you want to add another one?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppLocalizations.of(context)?.addAnyway ?? 'Add Anyway')),
            ],
          ),
        );
        if (confirm != true) return;
      }

      ServiceReminder savedReminder;
      if (isEditing) {
        savedReminder = ServiceReminder(
          id: widget.reminder!.id,
          title: _titleController.text.trim(),
          serviceDateTime: _selectedDateTime!,
          notes: _notesController.text.trim(),
        );
        await provider.updateReminder(savedReminder);
      } else {
        savedReminder = ServiceReminder.create(
          title: _titleController.text.trim(),
          serviceDateTime: _selectedDateTime!,
          notes: _notesController.text.trim(),
        );
        await provider.addReminder(savedReminder);
      }

      if (mounted) Navigator.pop(context);

      // Show the confirmation bottom sheet with the alert schedule.
      if (mounted) {
        _showConfirmationSheet(context, savedReminder, isEditing);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.08),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.edit_notifications_rounded
                        : Icons.add_alert_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing ? 'Edit Reminder' : 'Set New Reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You\'ll receive 7 alerts starting 5 days before',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)?.serviceTitleLabel ?? 'Service Title',
                    hintText: AppLocalizations.of(context)?.serviceTitleHint ?? 'e.g., Sunday Worship',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.dateTimeLabel ?? 'Date & Time',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                      errorText: (_submitted && _selectedDateTime == null)
                          ? 'Please select a date and time'
                          : null,
                    ),
                    child: Text(
                      _selectedDateTime == null
                          ? 'Tap to select'
                          : DateFormat.yMMMd()
                              .add_jm()
                              .format(_selectedDateTime!),
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            _selectedDateTime == null ? theme.hintColor : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)?.reminderNotesLabel ?? 'Notes (Optional)',
                    hintText: AppLocalizations.of(context)?.reminderNotesHint ?? 'Song set, rehearsal notes, etc.',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selectedDateTime == null ? null : _submit,
                      icon: Icon(isEditing
                          ? Icons.save_rounded
                          : Icons.alarm_add_rounded),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Set Reminder',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CONFIRMATION BOTTOM SHEET — shows all armed alerts after save
// =============================================================================

void _showConfirmationSheet(
    BuildContext context, ServiceReminder reminder, bool wasEdit) {
  final provider =
      Provider.of<ServiceReminderProvider>(context, listen: false);
  final timeline = provider.getNotificationTimeline(reminder);
  final alertCount = provider.scheduledAlertCount(reminder);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;

      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Success icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF66BB6A).withOpacity(0.1),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF66BB6A), size: 40),
              )
                  .animate()
                  .scale(begin: const Offset(0, 0), curve: Curves.elasticOut, duration: 600.ms),
              const SizedBox(height: 16),
              Text(
                wasEdit ? 'Reminder Updated!' : 'Reminder Armed!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reminder.title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$alertCount alert${alertCount == 1 ? '' : 's'} armed & active',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Mini timeline
              ...timeline
                  .where((s) =>
                      s.status == AlertSlotStatus.scheduled ||
                      s.status == AlertSlotStatus.nextUp)
                  .map((slot) {
                final isNext = slot.status == AlertSlotStatus.nextUp;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNext
                        ? const Color(0xFF1E88E5).withOpacity(0.06)
                        : theme.colorScheme.onSurface.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: isNext
                        ? Border.all(
                            color: const Color(0xFF1E88E5).withOpacity(0.2))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        slot.isAlarm
                            ? Icons.alarm_rounded
                            : Icons.notifications_outlined,
                        size: 18,
                        color: isNext
                            ? const Color(0xFF1E88E5)
                            : theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.label,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isNext
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isNext
                                    ? const Color(0xFF1E88E5)
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            Text(
                              DateFormat('EEE, MMM d · h:mm a')
                                  .format(slot.dateTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isNext)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NEXT',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                      if (slot.isAlarm)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ALARM',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Alerts will fire even when the app is closed',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.35),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(AppLocalizations.of(context)?.gotIt ?? 'Got it',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}