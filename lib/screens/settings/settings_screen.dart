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
              expandedHeight: 90,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
                title: Text(l10n.settings, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: theme.appBarTheme.titleTextStyle?.color)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
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

                          const SizedBox(height: 16),
                          _buildSectionHeader(l10n.preferences, theme),
                          const SizedBox(height: 8),
                          _buildSettingsCard(
                            theme: theme,
                            children: [
                              _buildSettingsTile(icon: Icon(Icons.language_outlined, size: 20, color: theme.colorScheme.primary), title: l10n.language, subtitle: Provider.of<LanguageProvider>(context).currentLocale.languageCode == 'en' ? 'English' : 'አማርኛ', onTap: _showLanguagePicker, trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14)),
                              _buildDivider(),
                              _buildSettingsTile(icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 20, color: theme.colorScheme.primary), title: l10n.darkMode, trailing: Transform.scale(scale: 0.75, child: Switch.adaptive(value: isDark, onChanged: (_) => themeProvider.toggleTheme(), activeColor: theme.colorScheme.primary))),
                              _buildDivider(),
                              Consumer<NotificationSettingsProvider>(
                                builder: (context, settings, _) => _buildSettingsTile(
                                  icon: Icon(
                                    settings.permission.notificationsEnabled
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_off_outlined,
                                    size: 20,
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
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          _buildSectionHeader(l10n.account, theme),
                          const SizedBox(height: 8),
                          _buildSettingsCard(
                            theme: theme,
                            children: [
                              if (authProvider.currentUser == null)
                                _buildSettingsTile(icon: Icon(Icons.add_comment_outlined, size: 20, color: theme.colorScheme.primary), title: l10n.suggestASong, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestLyricsScreen())), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14)),
                              if (authProvider.currentUser == null) _buildDivider(),
                              _buildSettingsTile(
                                icon: Icon(Icons.shield_outlined, size: 20, color: theme.colorScheme.secondary),
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
                                trailing: authProvider.isLoadingUser ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              ),
                              _buildDivider(),
                              _buildSettingsTile(
                                icon: Icon(Icons.share_rounded, size: 20, color: theme.colorScheme.primary),
                                title: "Share The App",
                                onTap: _shareApp,
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Center(
                              child: authProvider.currentUser != null && !authProvider.isLoadingUser
                                  ? ElevatedButton.icon(
                                onPressed: () => authProvider.signOut(),
                                icon: const Icon(Icons.logout_rounded, size: 18),
                                label: Text(l10n.signOut, style: const TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error.withOpacity(0.1), foregroundColor: theme.colorScheme.error, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                              )
                                  : ElevatedButton.icon(
                                onPressed: _showExitDialog,
                                icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                                label: const Text('Exit App', style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error.withOpacity(0.1), foregroundColor: theme.colorScheme.error, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/logo/logo.png',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mahlete Semay v1.0.0',
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                                    fontSize: 11,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moderator.fullName,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '@${moderator.username}',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 13),
          ),
          const Divider(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(moderator.role.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCardPlaceholder(ThemeData theme) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0, bottom: 2.0),
      child: Text(title.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: theme.colorScheme.primary)),
    );
  }

  Widget _buildSettingsCard({required ThemeData theme, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.dividerColor.withOpacity(0.5), width: 1)),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({required Icon? icon, required String title, String? subtitle, VoidCallback? onTap, Widget? trailing}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12.5, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)))],
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
    return Divider(height: 1, thickness: 1, indent: 46, endIndent: 14, color: Colors.grey.withOpacity(0.1));
  }
}