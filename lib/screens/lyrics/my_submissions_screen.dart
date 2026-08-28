import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/lyrics/suggest_lyrics_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mahlete_semay_project/models/submission_history_model.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  late Future<List<SubmissionHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<SubmissionHistoryEntry>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('submissionHistory') ?? [];
    return historyJson
        .map((json) => SubmissionHistoryEntry.fromJson(json))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  Future<void> _editSubmission(SubmissionHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('submissionHistory') ?? [];

    historyJson.removeWhere((json) {
      final decoded = SubmissionHistoryEntry.fromJson(json);
      return decoded.songTitle == entry.songTitle && decoded.artistName == entry.artistName && decoded.submittedAt == entry.submittedAt;
    });

    await prefs.setStringList('submissionHistory', historyJson);

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SuggestLyricsScreen(
            initialTitle: entry.songTitle,
            initialArtist: entry.artistName,
          ),
        ),
      );
      if (result == true) { // A new submission was made
        setState(() {
          _historyFuture = _loadHistory();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mySubmissions),
      ),
      body: FutureBuilder<List<SubmissionHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noSubmissionsYet));
          }

          final history = snapshot.data!;

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              return ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: Text(entry.songTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(entry.artistName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeago.format(entry.submittedAt, locale: Localizations.localeOf(context).languageCode), style: Theme.of(context).textTheme.bodySmall),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: l10n.recallAndEdit,
                      onPressed: () => _editSubmission(entry),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}