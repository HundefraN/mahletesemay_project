import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/web_content_wrapper.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const _developerWebsite = 'https://eben-dev.vercel.app';

  String? _version;
  String? _buildNumber;
  bool _openingWebsite = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _version = null;
        _buildNumber = null;
      });
    }
  }

  Future<void> _openWebsite() async {
    if (_openingWebsite) return;
    setState(() => _openingWebsite = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final opened = await launchUrl(
        Uri.parse(_developerWebsite),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        CustomSnackbar.show(context, l10n.aboutCouldNotOpenWebsite, isError: true);
      }
    } catch (_) {
      if (mounted) {
        CustomSnackbar.show(context, l10n.aboutCouldNotOpenWebsite, isError: true);
      }
    } finally {
      if (mounted) setState(() => _openingWebsite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final versionLabel = _version == null
        ? '—'
        : (_buildNumber != null && _buildNumber!.isNotEmpty
            ? l10n.aboutVersionLine(_version!, _buildNumber!)
            : _version!);

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
                titlePadding: const EdgeInsets.only(left: 56, bottom: 12),
                title: Text(
                  l10n.about,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.appBarTheme.titleTextStyle?.color,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverWebContentWrapper(
                maxWidth: 700,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HeroCard(
                      theme: theme,
                      appName: l10n.aboutAppName,
                      tagline: l10n.aboutAppTagline,
                      versionLabel: l10n.aboutVersion,
                      versionValue: versionLabel,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      theme: theme,
                      children: [
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: l10n.aboutDeveloper,
                          title: l10n.aboutDeveloperName,
                          subtitle: l10n.aboutDeveloperRole,
                          theme: theme,
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 52,
                          endIndent: 16,
                          color: Colors.grey.withValues(alpha: 0.12),
                        ),
                        _InfoRow(
                          icon: Icons.language_rounded,
                          label: l10n.aboutWebsite,
                          title: 'eben-dev.vercel.app',
                          subtitle: l10n.aboutVisitWebsite,
                          theme: theme,
                          onTap: _openWebsite,
                          trailing: _openingWebsite
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ThemeData theme;
  final String appName;
  final String tagline;
  final String versionLabel;
  final String versionValue;

  const _HeroCard({
    required this.theme,
    required this.appName,
    required this.tagline,
    required this.versionLabel,
    required this.versionValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/logo/logo.png',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            appName,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$versionLabel $versionValue',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ThemeData theme;
  final List<Widget> children;

  const _InfoCard({required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final ThemeData theme;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.theme,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
