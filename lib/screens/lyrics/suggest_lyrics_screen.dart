import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/models/submission_history_model.dart';
import 'package:mahlete_semay_project/models/suggestion_model.dart';
import 'package:mahlete_semay_project/screens/lyrics/my_submissions_screen.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahlete_semay_project/widgets/web_content_wrapper.dart';

class SuggestLyricsScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialArtist;

  const SuggestLyricsScreen({super.key, this.initialTitle, this.initialArtist});

  @override
  State<SuggestLyricsScreen> createState() => _SuggestLyricsScreenState();
}

class _SuggestLyricsScreenState extends State<SuggestLyricsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _lyricsController = TextEditingController();
  bool _isLoading = false;
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
    if (widget.initialArtist != null) _artistController.text = widget.initialArtist!;

    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _titleController.dispose();
    _artistController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(() => _isOffline = !result.contains(ConnectivityResult.mobile) && !result.contains(ConnectivityResult.wifi));
    }
  }

  Future<void> _saveToLocalHistory(Suggestion suggestion) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('submissionHistory') ?? [];

    final newEntry = SubmissionHistoryEntry(
      songTitle: suggestion.songTitle,
      artistName: suggestion.artistName,
      submittedAt: DateTime.now(),
    );

    historyJson.add(newEntry.toJson());
    await prefs.setStringList('submissionHistory', historyJson);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final suggestion = Suggestion(
          id: '',
          songTitle: _titleController.text.trim(),
          artistName: _artistController.text.trim(),
          lyrics: _lyricsController.text.trim(),
          submittedAt: DateTime.now(),
        );
        await _firebaseService.addLyricSuggestion(suggestion);
        await _saveToLocalHistory(suggestion);

        if (mounted) {
          Navigator.pop(context, true);
          CustomSnackbar.show(context, l10n.submissionSuccess);
        }
      } catch (e) {
        if (mounted) CustomSnackbar.show(context, l10n.submissionFailed, isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suggestASong),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.mySubmissions,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySubmissionsScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : WebContentWrapper(
              maxWidth: 700,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(controller: _titleController, decoration: _inputDecoration('${l10n.title} *', Icons.music_note), validator: (v) => v!.isEmpty ? l10n.pleaseEnterEmail : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _artistController, decoration: _inputDecoration('${l10n.artist} *', Icons.person), validator: (v) => v!.isEmpty ? l10n.pleaseEnterEmail : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _lyricsController, decoration: _inputDecoration('${l10n.lyrics} *', Icons.text_fields, alignLabel: true), minLines: 10, maxLines: 20, validator: (v) => v!.isEmpty ? l10n.pleaseEnterEmail : null),
                    const SizedBox(height: 24),
                    ElevatedButton(
                        onPressed: _isOffline ? null : _submit,
                        child: Text(l10n.submitForReview),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      prefixIcon: Icon(icon),
      alignLabelWithHint: alignLabel,
    );
  }
}