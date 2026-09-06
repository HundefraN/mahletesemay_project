import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/models/submission_history_model.dart';
import 'package:mahlete_semay_project/models/suggestion_model.dart';
import 'package:mahlete_semay_project/screens/lyrics/my_submissions_screen.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:mahlete_semay_project/widgets/web_content_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuggestLyricsScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialArtist;

  const SuggestLyricsScreen({
    super.key,
    this.initialTitle,
    this.initialArtist,
  });

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
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialArtist != null) {
      _artistController.text = widget.initialArtist!;
    }

    _checkInitialConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
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
    if (!mounted) return;
    setState(() {
      _isOffline = !result.contains(ConnectivityResult.mobile) &&
          !result.contains(ConnectivityResult.wifi) &&
          !result.contains(ConnectivityResult.ethernet) &&
          !result.contains(ConnectivityResult.vpn);
    });
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
    if (!_formKey.currentState!.validate()) return;

    if (_isOffline) {
      CustomSnackbar.show(context, l10n.reportOffline, isError: true);
      return;
    }

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

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
      CustomSnackbar.show(context, l10n.submissionSuccess);
    } catch (e) {
      debugPrint('Error submitting lyrics: $e');
      if (mounted) {
        CustomSnackbar.show(context, l10n.submissionFailed, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF080E1A) : const Color(0xFFF7F9FC);
    final cardBg = isDark ? const Color(0xFF10192A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2E45) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF152238) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black87,
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: Text(
          l10n.suggestASong,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF0B192C),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: l10n.mySubmissions,
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF152238) : Colors.white,
                foregroundColor: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
              ),
              icon: const Icon(Icons.history_rounded, size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebContentWrapper(
            maxWidth: 720,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 130),
                children: [
                  _HeroHeaderCard(isDark: isDark, l10n: l10n),
                  const SizedBox(height: 20),

                  if (_isOffline) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.reportOffline,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFEF4444),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Song Title
                  _SectionTitle(
                    icon: Icons.music_note_rounded,
                    title: '${l10n.title} *',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _inputDecoration(
                      hint: l10n.title,
                      icon: Icons.subtitles_rounded,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '${l10n.title} *'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // 2. Artist / Singer
                  _SectionTitle(
                    icon: Icons.person_rounded,
                    title: '${l10n.artist} *',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _artistController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _inputDecoration(
                      hint: l10n.artist,
                      icon: Icons.mic_rounded,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '${l10n.artist} *'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // 3. Lyrics
                  _SectionTitle(
                    icon: Icons.format_quote_rounded,
                    title: '${l10n.lyrics} *',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lyricsController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 8,
                    maxLines: 22,
                    style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                    decoration: _inputDecoration(
                      hint: l10n.lyrics,
                      icon: Icons.edit_note_rounded,
                      alignLabel: true,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '${l10n.lyrics} *'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.reportPrivacyNote,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating Glassmorphic Submit Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    14 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF080E1A).withValues(alpha: 0.82)
                        : Colors.white.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF1F2E45) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading || _isOffline ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
                        foregroundColor:
                            isDark ? const Color(0xFF080E1A) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: isDark ? const Color(0xFF080E1A) : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.reportSubmitting,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isOffline
                                        ? Icons.wifi_off_rounded
                                        : Icons.send_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isOffline ? l10n.reportOffline : l10n.submitForReview,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color cardBg,
    required Color borderColor,
    bool alignLabel = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        fontSize: 13.5,
      ),
      alignLabelWithHint: alignLabel,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
      ),
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
          width: 1.6,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _HeroHeaderCard extends StatelessWidget {
  final bool isDark;
  final AppLocalizations l10n;

  const _HeroHeaderCard({required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF14243F), Color(0xFF0B1424)]
              : const [Color(0xFF0B1D3A), Color(0xFF1B3B6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE092), Color(0xFFDFB76C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDFB76C).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.queue_music_rounded, color: Color(0xFF0A1E3F), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.suggestASong,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.reportHeroSubtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}