import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/suggestion_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'widgets/admin_ui_kit.dart';

class ReviewSuggestionsScreen extends StatefulWidget {
  const ReviewSuggestionsScreen({super.key});

  @override
  State<ReviewSuggestionsScreen> createState() => _ReviewSuggestionsScreenState();
}

class _ReviewSuggestionsScreenState extends State<ReviewSuggestionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Review Suggestions',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13233D) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: '⏳ ${AppLocalizations.of(context)?.pendingTab ?? "Pending"}'),
                Tab(text: '✅ ${AppLocalizations.of(context)?.approvedTab ?? "Approved"}'),
                Tab(text: '❌ ${AppLocalizations.of(context)?.rejectedTab ?? "Rejected"}'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Suggestion>>(
        stream: firebaseService.getSuggestionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminUiKit.goldAccent));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return AdminEmptyState(
              icon: Icons.rate_review_outlined,
              title: AppLocalizations.of(context)?.noSuggestionsSubmitted ?? 'No Suggestions Submitted',
              description: 'User song suggestions and lyric corrections will appear here for moderation.',
            );
          }
          final allSuggestions = snapshot.data!;
          final pending = allSuggestions.where((s) => s.status == SuggestionStatus.pending).toList();
          final approved = allSuggestions.where((s) => s.status == SuggestionStatus.approved).toList();
          final rejected = allSuggestions.where((s) => s.status == SuggestionStatus.rejected).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _SuggestionList(suggestions: pending, firebaseService: firebaseService, emptyLabel: 'No pending suggestions to review! 🎉'),
              _SuggestionList(suggestions: approved, firebaseService: firebaseService, emptyLabel: 'No approved suggestions yet.'),
              _SuggestionList(suggestions: rejected, firebaseService: firebaseService, emptyLabel: 'No rejected suggestions.'),
            ],
          );
        },
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<Suggestion> suggestions;
  final FirebaseService firebaseService;
  final String emptyLabel;

  const _SuggestionList({
    required this.suggestions,
    required this.firebaseService,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return AdminEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: AppLocalizations.of(context)?.allClear ?? 'All Clear',
        description: emptyLabel,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return _SuggestionCard(suggestion: suggestion, firebaseService: firebaseService);
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final FirebaseService firebaseService;

  const _SuggestionCard({
    required this.suggestion,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    switch (suggestion.status) {
      case SuggestionStatus.approved:
        statusColor = AdminUiKit.emeraldGreen;
        statusText = 'Approved';
        break;
      case SuggestionStatus.rejected:
        statusColor = AdminUiKit.roseRed;
        statusText = 'Rejected';
        break;
      case SuggestionStatus.pending:
      default:
        statusColor = AdminUiKit.amberOrange;
        statusText = 'Pending Review';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AdminGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 18,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.music_note_rounded, color: statusColor, size: 20),
            ),
            title: Text(
              suggestion.songTitle,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  suggestion.artistName,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 8),
                AdminStatusBadge(label: statusText, color: statusColor, fontSize: 9.5),
              ],
            ),
            trailing: Text(
              DateFormat('MMM d').format(suggestion.submittedAt.toDate()),
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.grey),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              Text(
                'Submitted Lyrics / Content:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Text(
                  suggestion.lyrics,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AdminUiKit.roseRed,
                    tooltip: 'Delete Suggestion',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(AppLocalizations.of(context)?.deleteSuggestionPrompt ?? 'Delete Suggestion?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                          content: Text(AppLocalizations.of(context)?.deleteSuggestionConfirm ?? 'Are you sure you want to permanently delete this submission?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AdminUiKit.roseRed,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(AppLocalizations.of(context)?.deleteAction ?? 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        if (authProvider.currentUser != null) {
                          firebaseService.logActivity(
                            moderatorId: authProvider.currentUser!.uid,
                            moderatorName: authProvider.currentModerator?.fullName ?? 'Moderator',
                            action: 'DELETE_SUGGESTION',
                            details: 'Deleted suggestion: "${suggestion.songTitle}"',
                          );
                        }
                        await firebaseService.deleteSuggestion(suggestion.id);
                        if (context.mounted) {
                          CustomSnackbar.show(context, 'Suggestion deleted.');
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.video_library_rounded, size: 20),
                    tooltip: AppLocalizations.of(context)?.searchYouTubeForAudioRef ?? 'Search YouTube for Audio Reference',
                    color: AdminUiKit.royalBlue,
                    onPressed: () async {
                      final query = Uri.encodeComponent('${suggestion.songTitle} ${suggestion.artistName} lyrics');
                      final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
                      try {
                        if (await canLaunchUrl(url)) await launchUrl(url);
                      } catch (e) {
                        if (context.mounted) {
                          CustomSnackbar.show(context, 'Could not open YouTube reference.', isError: true);
                        }
                      }
                    },
                  ),
                  const Spacer(),
                  if (suggestion.status != SuggestionStatus.rejected)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminUiKit.roseRed,
                        side: BorderSide(color: AdminUiKit.roseRed.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(AppLocalizations.of(context)?.rejectAction ?? 'Reject'),
                      onPressed: () async {
                        try {
                          await firebaseService.updateSuggestionStatus(suggestion.id, SuggestionStatus.rejected);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          if (authProvider.currentModerator != null) {
                            firebaseService.logActivity(
                              moderatorId: authProvider.currentUser!.uid,
                              moderatorName: authProvider.currentModerator!.fullName,
                              action: 'REJECT_SUGGESTION',
                              details: 'Rejected suggestion: "${suggestion.songTitle}" by ${suggestion.artistName}',
                            );
                          }
                          if (context.mounted) {
                            CustomSnackbar.show(context, 'Suggestion marked as rejected.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackbar.show(context, 'Failed: $e', isError: true);
                          }
                        }
                      },
                    ),
                  const SizedBox(width: 8),
                  if (suggestion.status != SuggestionStatus.approved)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminUiKit.emeraldGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(AppLocalizations.of(context)?.approve ?? 'Approve'),
                      onPressed: () async {
                        try {
                          await firebaseService.updateSuggestionStatus(suggestion.id, SuggestionStatus.approved);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          if (authProvider.currentModerator != null) {
                            firebaseService.logActivity(
                              moderatorId: authProvider.currentUser!.uid,
                              moderatorName: authProvider.currentModerator!.fullName,
                              action: 'APPROVE_SUGGESTION',
                              details: 'Approved suggestion: "${suggestion.songTitle}" by ${suggestion.artistName}',
                            );
                          }
                          if (context.mounted) {
                            CustomSnackbar.show(context, 'Suggestion approved!');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackbar.show(context, 'Failed: $e', isError: true);
                          }
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}