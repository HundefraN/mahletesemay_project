import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/suggestion_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_proveider.dart';

class ReviewSuggestionsScreen extends StatelessWidget {
  const ReviewSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Suggestions'),
          bottom: TabBar(
            indicatorColor: theme.colorScheme.secondary,
            tabs: const [
              Tab(text: 'PENDING'),
              Tab(text: 'APPROVED'),
              Tab(text: 'REJECTED'),
            ],
          ),
        ),
        body: StreamBuilder<List<Suggestion>>(
          stream: firebaseService.getSuggestionsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No suggestions found.'));
            }
            final allSuggestions = snapshot.data!;
            final pending = allSuggestions.where((s) => s.status == SuggestionStatus.pending).toList();
            final approved = allSuggestions.where((s) => s.status == SuggestionStatus.approved).toList();
            final rejected = allSuggestions.where((s) => s.status == SuggestionStatus.rejected).toList();

            return TabBarView(
              children: [
                _SuggestionList(suggestions: pending, firebaseService: firebaseService, key: const ValueKey('pending')),
                _SuggestionList(suggestions: approved, firebaseService: firebaseService, key: const ValueKey('approved')),
                _SuggestionList(suggestions: rejected, firebaseService: firebaseService, key: const ValueKey('rejected')),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<Suggestion> suggestions;
  final FirebaseService firebaseService;
  const _SuggestionList({super.key, required this.suggestions, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Center(
        child: Text('No suggestions in this category.', style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
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
  const _SuggestionCard({required this.suggestion, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    switch(suggestion.status) {
      case SuggestionStatus.approved: statusColor = Colors.green; statusIcon = Icons.check_circle; break;
      case SuggestionStatus.rejected: statusColor = Colors.red; statusIcon = Icons.cancel; break;
      case SuggestionStatus.pending:
      default: statusColor = Colors.orange; statusIcon = Icons.pending; break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: statusColor, child: Icon(statusIcon, color: Colors.white, size: 20)),
        title: Text(suggestion.songTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(suggestion.artistName),
        trailing: Text(DateFormat('MMM d, y').format(suggestion.submittedAt.toDate()), style: theme.textTheme.bodySmall),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(suggestion.lyrics, style: const TextStyle(height: 1.5)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(icon: const Icon(Icons.delete_outline), color: Colors.red, tooltip: 'Delete', onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirm Delete'), content: const Text('Are you sure you want to permanently delete this suggestion?'), actions: [TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red))]));
                if (confirm == true) {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  firebaseService.logActivity(
                    moderatorId: authProvider.currentUser!.uid,
                    moderatorName: authProvider.currentModerator!.fullName,
                    action: 'DELETE_SUGGESTION',
                    details: 'Deleted suggestion: "${suggestion.songTitle}"',
                  );
                  await firebaseService.deleteSuggestion(suggestion.id);
                  CustomSnackbar.show(context, 'Suggestion deleted.');
                }
              }),
              IconButton(icon: const Icon(Icons.search), tooltip: 'Search on YouTube', onPressed: () async {
                final query = Uri.encodeComponent('${suggestion.songTitle} ${suggestion.artistName} lyrics');
                final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
                try {
                  if (await canLaunchUrl(url)) await launchUrl(url);
                } catch(e) {
                  CustomSnackbar.show(context, 'Could not open YouTube.', isError: true);
                }
              }),
              const Spacer(),
              if (suggestion.status != SuggestionStatus.rejected)
                TextButton(child: const Text('Reject'), onPressed: () => firebaseService.updateSuggestionStatus(suggestion.id, SuggestionStatus.rejected)),
              const SizedBox(width: 8),
              if (suggestion.status != SuggestionStatus.approved)
                ElevatedButton(child: const Text('Approve'), onPressed: () => firebaseService.updateSuggestionStatus(suggestion.id, SuggestionStatus.approved)),
            ],
          ),
        ],
      ),
    );
  }
}