import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_settings_provider.dart';
import '../../providers/service_reminder_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'service_reminder_screen.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
                : [const Color(0xFFF4F6F8), const Color(0xFFE3F2FD)],
          ),
        ),
        child: Consumer2<NotificationSettingsProvider, ServiceReminderProvider>(
          builder: (context, settings, reminders, _) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: theme.appBarTheme.titleTextStyle?.color,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _PermissionBanner(settings: settings),
                      _SectionHeader('Practice', theme),
                      _Card(
                        theme: theme,
                        children: [
                          _SwitchTile(
                            icon: Icons.notifications_active_outlined,
                            title: 'Daily practice reminder',
                            subtitle: settings.dailyRemindersEnabled
                                ? 'Every day at ${settings.dailyReminderTime.format(context)}'
                                : 'Off',
                            value: settings.dailyRemindersEnabled,
                            onChanged: settings.setDailyRemindersEnabled,
                          ),
                          if (settings.dailyRemindersEnabled) ...[
                            _Divider(),
                            _NavTile(
                              icon: Icons.schedule_outlined,
                              title: 'Reminder time',
                              subtitle:
                                  settings.dailyReminderTime.format(context),
                              onTap: () => _pickTime(context, settings),
                            ),
                          ],
                          _Divider(),
                          _SwitchTile(
                            icon: Icons.replay_circle_filled_outlined,
                            title: 'Unfinished session nudge',
                            subtitle:
                                'Remind me to come back if I leave a vocal plan halfway',
                            value: settings.practiceFollowUpsEnabled,
                            onChanged: settings.setPracticeFollowUpsEnabled,
                          ),
                        ],
                      ),
                      _SectionHeader('Services', theme),
                      _Card(
                        theme: theme,
                        children: [
                          _NavTile(
                            icon: Icons.event_available_outlined,
                            title: 'Service reminders',
                            subtitle: _serviceSubtitle(reminders),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServiceReminderScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _SectionHeader('Library', theme),
                      _Card(
                        theme: theme,
                        children: [
                          _SwitchTile(
                            icon: Icons.library_music_outlined,
                            title: 'New songs & content',
                            subtitle:
                                'Tell me when new songs are added to the library',
                            value: settings.newContentAlertsEnabled,
                            onChanged: settings.setNewContentAlertsEnabled,
                          ),
                        ],
                      ),
                      _SectionHeader('Troubleshooting', theme),
                      _Card(
                        theme: theme,
                        children: [
                          _NavTile(
                            icon: Icons.send_outlined,
                            title: 'Send a test notification',
                            subtitle:
                                'Check that alerts reach this device correctly',
                            onTap: () => _sendTest(context, settings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ScheduledSummary(reminders: reminders),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _serviceSubtitle(ServiceReminderProvider reminders) {
    final count = reminders.upcomingReminders.length;
    if (count == 0) return 'No upcoming services scheduled';
    return count == 1
        ? '1 upcoming service'
        : '$count upcoming services';
  }

  static Future<void> _pickTime(
    BuildContext context,
    NotificationSettingsProvider settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.dailyReminderTime,
      helpText: 'Daily reminder time',
    );
    if (picked == null) return;

    await settings.setDailyReminderTime(picked);
    if (!context.mounted) return;
    CustomSnackbar.show(
      context,
      'Daily reminder moved to ${picked.format(context)}.',
    );
  }

  static Future<void> _sendTest(
    BuildContext context,
    NotificationSettingsProvider settings,
  ) async {
    if (!settings.permission.notificationsEnabled) {
      final granted = await settings.requestPermission();
      if (!context.mounted) return;
      if (!granted) {
        CustomSnackbar.show(
          context,
          'Notifications are turned off for this app. Enable them in system settings.',
          isError: true,
        );
        return;
      }
    }

    await NotificationService.showTestNotification();
    if (!context.mounted) return;
    CustomSnackbar.show(context, 'Test notification sent.');
  }
}

/// Explains, and offers a fix for, anything the operating system is currently
/// blocking. Renders nothing when notifications are fully working.
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.settings});

  final NotificationSettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permission = settings.permission;

    if (!permission.notificationsEnabled) {
      return _Banner(
        color: theme.colorScheme.error,
        icon: Icons.notifications_off_outlined,
        title: 'Notifications are blocked',
        message:
            'Mahlete Semay cannot send reminders until notifications are allowed for this app.',
        actionLabel: 'Allow notifications',
        onAction: () async {
          final granted = await settings.requestPermission();
          if (!context.mounted) return;
          if (!granted) {
            CustomSnackbar.show(
              context,
              'Open your device settings and allow notifications for Mahlete Semay.',
              isError: true,
            );
          }
        },
      );
    }

    if (!permission.canScheduleExactAlarms) {
      return _Banner(
        color: theme.colorScheme.secondary,
        icon: Icons.timer_outlined,
        title: 'Reminders may arrive late',
        message:
            'Your device is batching scheduled alarms to save battery, so reminders can be delayed by a few minutes. Allow precise alarms for on-time delivery.',
        actionLabel: 'Allow precise timing',
        onAction: settings.requestExactAlarmPermission,
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer showing how many alerts are actually queued, so the user can tell at
/// a glance that their settings took effect.
class _ScheduledSummary extends StatelessWidget {
  const _ScheduledSummary({required this.reminders});

  final ServiceReminderProvider reminders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<dynamic>>(
      future: NotificationService.pendingNotifications(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 20);
        final count = snapshot.data!.length;
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  count == 0
                      ? 'No alerts currently scheduled'
                      : '$count alert${count == 1 ? '' : 's'} scheduled and active',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.theme);

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.children});

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 20,
      color: Colors.grey.withOpacity(0.1),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TileShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
