import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/providers/language_provider.dart';
import 'package:mahlete_semay_project/screens/admin/portal_home_screen.dart';
import 'package:mahlete_semay_project/screens/auth/login_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/suggest_lyrics_screen.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import '../../providers/auth_proveider.dart';
import '../../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';

const int dailyReminderNotificationId = 100;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadReminderPreference();
  }

  Future<void> _loadReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
              () => _remindersEnabled = prefs.getBool('dailyRemindersEnabled') ?? true);
    }
  }

  Future<void> _toggleReminders(bool value) async {
    setState(() => _remindersEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyRemindersEnabled', value);
    if (value) {
      await NotificationService.scheduleStyledDailyReminder(
          id: dailyReminderNotificationId,
          title: "Daily Vocal Workout Reminder",
          body: "Time to train your voice and keep up the progress!");
      if (mounted)
        CustomSnackbar.show(context, 'Daily reminders enabled for 10 AM.');
    } else {
      await NotificationService.cancelNotification(dailyReminderNotificationId);
      if (mounted) CustomSnackbar.show(context, 'Daily reminders disabled.');
    }
  }

  void _showLanguagePicker() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.language, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  languageProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
                trailing: languageProvider.currentLocale.languageCode == 'en'
                    ? const Icon(Icons.check_circle)
                    : null,
              ),
              ListTile(
                title: const Text('አማርኛ'),
                onTap: () {
                  languageProvider.setLocale(const Locale('am'));
                  Navigator.pop(context);
                },
                trailing: languageProvider.currentLocale.languageCode == 'am'
                    ? const Icon(Icons.check_circle)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final moderator = authProvider.currentModerator;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (moderator != null) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                          moderator.firstName.isNotEmpty
                              ? moderator.firstName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(height: 12),
                    Text(moderator.fullName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(moderator.username,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                            label: Text('Role: ${moderator.role.toUpperCase()}'),
                            avatar: const Icon(Icons.shield_outlined)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(moderator.status.toUpperCase()),
                          avatar: Icon(
                              moderator.status == 'active'
                                  ? Icons.check_circle
                                  : Icons.block,
                              size: 16),
                          backgroundColor: moderator.status == 'active'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.language, color: theme.colorScheme.primary),
              title: Text(l10n.language),
              onTap: _showLanguagePicker,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: theme.colorScheme.primary),
              title: Text(l10n.darkMode),
              trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.toggleTheme()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              secondary: Icon(Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary),
              title: Text(l10n.dailyReminders),
              subtitle: Text(l10n.remindersDesc),
              value: _remindersEnabled,
              onChanged: _toggleReminders,
            ),
          ),

          const SizedBox(height: 20),

          if (authProvider.currentUser == null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.add_comment_outlined,
                    color: theme.colorScheme.primary),
                title: Text(l10n.suggestASong),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SuggestLyricsScreen())),
              ),
            ),

          Card(
            elevation: 2,
            margin: const EdgeInsets.only(top: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.shield_outlined,
                  color: theme.colorScheme.secondary),
              title:
              Text(l10n.moderatorPortal),
              onTap: () {
                if (authProvider.currentUser == null) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()));
                } else if (authProvider.userStatus == 'active') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PortalHomeScreen()));
                } else {
                  CustomSnackbar.show(
                      context, 'Your access has been revoked by an admin.',
                      isError: true);
                }
              },
            ),
          ),

          if (authProvider.currentUser != null)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: TextButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(l10n.signOut),
                onPressed: () => authProvider.signOut(),
              ),
            ),
        ],
      ),
    );
  }
}