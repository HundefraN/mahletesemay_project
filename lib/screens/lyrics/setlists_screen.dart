import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/setlist_model.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
import 'package:mahlete_semay_project/screens/lyrics/setlist_detail_screen.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/widgets/web_content_wrapper.dart';

class SetlistsScreen extends StatelessWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
          elevation: 0,
          pinned: true,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                centerTitle: false,
                title: Text(
                  l10n.mySetlists,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: theme.appBarTheme.titleTextStyle?.color,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverWebContentWrapper(
          maxWidth: 850,
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(context.w(16), context.w(16), context.w(16), context.w(120)),
            sliver: Consumer<SetlistProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }

                if (provider.setlists.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.queue_music_rounded,
                      title: l10n.noSetlistsYet,
                      message: l10n.noSetlistsDesc,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final setlist = provider.setlists[index];
                      return _SetlistCard(setlist: setlist)
                          .animate()
                          .fadeIn(delay: (100 * index).ms, duration: 500.ms)
                          .slideY(begin: 0.2, curve: Curves.easeOutCubic);
                    },
                    childCount: provider.setlists.length,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SetlistCard extends StatelessWidget {
  final Setlist setlist;
  const _SetlistCard({required this.setlist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final setlistProvider = Provider.of<SetlistProvider>(context);
    final songCount = setlistProvider.getSongsForSetlist(setlist.id!).length;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 500),
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: theme.scaffoldBackgroundColor,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.w(20))),
      openBuilder: (ctx, action) => SetlistDetailScreen(setlist: setlist),
      closedBuilder: (ctx, openContainer) {
        return GestureDetector(
          onTap: openContainer,
          child: Container(
            margin: EdgeInsets.only(bottom: context.w(16)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.w(20)),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.w(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.all(context.w(20)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.w(20)),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                    color: theme.cardColor.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: context.w(56),
                        height: context.w(56),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(context.w(16)),
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.playlist_play_rounded, color: Colors.white, size: context.w(32)),
                      ),
                      SizedBox(width: context.w(16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              setlist.name,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: context.sp(18)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: context.w(4)),
                            Text(
                              '$songCount song${songCount == 1 ? '' : 's'} • Created ${DateFormat.yMMMd().format(setlist.createdAt)}',
                              style: TextStyle(
                                fontSize: context.sp(12),
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: context.w(18), color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
              ),
              child: Icon(icon, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 600.ms),
      ),
    );
  }
}