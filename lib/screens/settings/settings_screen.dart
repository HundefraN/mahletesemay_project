import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/providers/language_provider.dart';
import 'package:mahlete_semay_project/screens/admin/portal_home_screen.dart';
import 'package:mahlete_semay_project/screens/auth/login_screen.dart';
import 'package:mahlete_semay_project/screens/auth/waiting_for_approval_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/suggest_lyrics_screen.dart';
import 'package:mahlete_semay_project/screens/settings/notification_settings_screen.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_proveider.dart';
import '../../providers/theme_provider.dart';
import 'package:mahlete_semay_project/providers/notification_settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Summarises the notification setup for the settings row, so the state is
  /// visible without opening the sub-screen.
  String _notificationSummary(NotificationSettingsProvider settings) {
    if (!settings.permission.notificationsEnabled) return 'Blocked by system';
    if (!settings.dailyRemindersEnabled) return 'Daily reminder off';
    return 'Daily reminder at ${settings.dailyReminderTime.format(context)}';
  }

  Future<void> _shareApp() {
    const String appUrl = "https://play.google.com/store/apps/details?id=your.package.name";
    const String message = "Check out Mahlete Semay, the ultimate app for worship singers! Download it here: $appUrl";
    return Share.share(message);
  }

  Future<void> _showExitDialog() async {
    final didRequestExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to close the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (didRequestExit ?? false) {
      SystemNavigator.pop();
    }
  }

  void _showLanguagePicker() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.language,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildLanguageOption(languageProvider, 'English', 'en'),
                _buildLanguageOption(languageProvider, 'አማርኛ', 'am'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(LanguageProvider provider, String language, String code) {
    final isSelected = provider.currentLocale.languageCode == code;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        provider.setLocale(Locale(code));
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(code == 'en' ? '🇺🇸' : '🇪🇹', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                language,
                style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final moderator = authProvider.currentModerator;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F1D33), const Color(0xFF070E1B)]
                : [const Color(0xFFF5F7FB), const Color(0xFFE8EEF5)],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(l10n.settings, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: theme.appBarTheme.titleTextStyle?.color)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_animationController),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authProvider.currentUser != null)
                            authProvider.isLoadingUser
                                ? _buildProfileCardPlaceholder(theme)
                                : (moderator != null
                                ? _buildSimpleProfileCard(moderator, theme)
                                : const SizedBox.shrink()),

                          const SizedBox(height: 24),
                          _buildSectionHeader(l10n.preferences, theme),
                          const SizedBox(height: 16),
                          _buildSettingsCard(
                            theme: theme,
                            children: [
                              _buildSettingsTile(icon: Icon(Icons.language_outlined, color: theme.colorScheme.primary), title: l10n.language, subtitle: Provider.of<LanguageProvider>(context).currentLocale.languageCode == 'en' ? 'English' : 'አማርኛ', onTap: _showLanguagePicker, trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16)),
                              _buildDivider(),
                              _buildSettingsTile(icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: theme.colorScheme.primary), title: l10n.darkMode, trailing: Transform.scale(scale: 0.8, child: Switch.adaptive(value: isDark, onChanged: (_) => themeProvider.toggleTheme(), activeColor: theme.colorScheme.primary))),
                              _buildDivider(),
                              Consumer<NotificationSettingsProvider>(
                                builder: (context, settings, _) => _buildSettingsTile(
                                  icon: Icon(
                                    settings.permission.notificationsEnabled
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_off_outlined,
                                    color: settings.isBlockedBySystem
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                  ),
                                  title: 'Notifications',
                                  subtitle: _notificationSummary(settings),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationSettingsScreen(),
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          _buildSectionHeader(l10n.account, theme),
                          const SizedBox(height: 16),
                          _buildSettingsCard(
                            theme: theme,
                            children: [
                              if (authProvider.currentUser == null)
                                _buildSettingsTile(icon: Icon(Icons.add_comment_outlined, color: theme.colorScheme.primary), title: l10n.suggestASong, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestLyricsScreen())), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16)),
                              if (authProvider.currentUser == null) _buildDivider(),
                              _buildSettingsTile(
                                icon: Icon(Icons.shield_outlined, color: theme.colorScheme.secondary),
                                title: l10n.moderatorPortal,
                                onTap: () {
                                  if (authProvider.currentUser == null) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                                  } else if (authProvider.isLoadingUser) {
                                    // User status is loading
                                  } else if (authProvider.currentModerator != null && (authProvider.userStatus == 'active' || authProvider.isAdmin)) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalHomeScreen()));
                                  } else if (authProvider.userStatus == 'review') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => WaitingForApprovalScreen()));
                                  } else if (authProvider.userStatus == 'blocked') {
                                    CustomSnackbar.show(context, 'Your account has been blocked by an administrator.', isError: true);
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                                  }
                                },
                                trailing: authProvider.isLoadingUser ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                              ),
                              _buildDivider(),
                              _buildSettingsTile(
                                icon: Icon(Icons.share_rounded, color: theme.colorScheme.primary),
                                title: "Share The App",
                                onTap: _shareApp,
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.only(top: 40.0),
                            child: Center(
                              child: authProvider.currentUser != null && !authProvider.isLoadingUser
                                  ? ElevatedButton.icon(
                                onPressed: () => authProvider.signOut(),
                                icon: const Icon(Icons.logout_rounded),
                                label: Text(l10n.signOut),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error.withOpacity(0.1), foregroundColor: theme.colorScheme.error, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                              )
                                  : ElevatedButton.icon(
                                onPressed: _showExitDialog,
                                icon: const Icon(Icons.exit_to_app_rounded),
                                label: const Text('Exit App'),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error.withOpacity(0.1), foregroundColor: theme.colorScheme.error, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/logo/logo.png',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Mahlete Semay v1.0.0',
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleProfileCard(dynamic moderator, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moderator.fullName,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '@${moderator.username}',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 14),
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(moderator.role.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCardPlaceholder(ThemeData theme) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Text(title.toUpperCase(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: theme.colorScheme.primary)),
    );
  }

  Widget _buildSettingsCard({required ThemeData theme, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1)),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({required Icon? icon, required String title, String? subtitle, VoidCallback? onTap, Widget? trailing}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)))],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, indent: 56, endIndent: 20, color: Colors.grey.withOpacity(0.1));
  }
}