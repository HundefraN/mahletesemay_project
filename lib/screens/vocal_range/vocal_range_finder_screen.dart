import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/services/pitch_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';

enum FinderState { idle, findingLowest, findingHighest, finished }

class VocalRangeFinderScreen extends StatefulWidget {
  const VocalRangeFinderScreen({super.key});

  @override
  State<VocalRangeFinderScreen> createState() => _VocalRangeFinderScreenState();
}

class _VocalRangeFinderScreenState extends State<VocalRangeFinderScreen> {
  final PitchService _pitchService = PitchService();
  FinderState _currentState = FinderState.idle;

  String _lowestNote = '';
  String _highestNote = '';
  String _currentNote = '';

  String _stableNote = '';
  int _stabilityCounter = 0;

  @override
  void dispose() {
    _pitchService.dispose();
    super.dispose();
  }

  void _startFindingLowest() {
    setState(() {
      _currentState = FinderState.findingLowest;
      _lowestNote = '';
      _highestNote = '';
    });
    _startListening();
  }

  void _startFindingHighest() {
    setState(() => _currentState = FinderState.findingHighest);
    _startListening();
  }

  void _startListening() {
    _pitchService.startListening((pitch) {
      if (!mounted) return;

      final note = _pitchService.getNoteFromPitch(pitch);

      if (note != _stableNote) {
        _stableNote = note;
        _stabilityCounter = 0;
      } else {
        _stabilityCounter++;
      }

      if (_stabilityCounter > 5) {
        if(mounted) {
          setState(() => _currentNote = note);
        }
      }
    });
  }

  void _stopAndSetNote() {
    _pitchService.stopListening();
    if (_currentNote.isEmpty) {
      CustomSnackbar.show(context, "Couldn't detect a stable note. Please try again.", isError: true);
      _reset();
      return;
    }

    if (_currentState == FinderState.findingLowest) {
      setState(() {
        _lowestNote = _currentNote;
        _currentState = FinderState.idle;
        _currentNote = '';
      });
    } else if (_currentState == FinderState.findingHighest) {
      setState(() {
        _highestNote = _currentNote;
        _currentState = FinderState.finished;
        _currentNote = '';
      });
    }
  }

  void _reset() {
    _pitchService.stopListening();
    setState(() {
      _currentState = FinderState.idle;
      _lowestNote = '';
      _highestNote = '';
      _currentNote = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    bool isFinding = _currentState == FinderState.findingLowest || _currentState == FinderState.findingHighest;
    String voiceType = _currentState == FinderState.finished ? _pitchService.getVoiceType(_lowestNote, _highestNote) : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vocalRangeFinder),
        actions: [IconButton(onPressed: _reset, icon: const Icon(Icons.refresh))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionCard(
              context,
              l10n,
              title: '1. ${l10n.findLowestNote}',
              instruction: l10n.findLowestNoteDesc,
              buttonText: l10n.startFindingLowest,
              onPressed: _startFindingLowest,
              showStop: _currentState == FinderState.findingLowest,
              isComplete: _lowestNote.isNotEmpty,
              noteResult: _lowestNote,
            ),
            const SizedBox(height: 20),
            _buildInstructionCard(
              context,
              l10n,
              title: '2. ${l10n.findHighestNote}',
              instruction: l10n.findHighestNoteDesc,
              buttonText: l10n.startFindingHighest,
              onPressed: _lowestNote.isNotEmpty ? _startFindingHighest : null,
              showStop: _currentState == FinderState.findingHighest,
              isComplete: _highestNote.isNotEmpty,
              noteResult: _highestNote,
            ),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: isFinding
                  ? _buildLivePitchIndicator(theme)
                  : _currentState == FinderState.finished
                  ? _buildResultCard(theme, voiceType, l10n)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(BuildContext context, AppLocalizations l10n, {required String title, required String instruction, required String buttonText, required VoidCallback? onPressed, required bool showStop, required bool isComplete, required String noteResult}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(instruction, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!showStop && !isComplete)
                  ElevatedButton(onPressed: onPressed, child: Text(buttonText))
                else if (showStop)
                  ElevatedButton(onPressed: _stopAndSetNote, style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error), child: const Text('Stop & Set Note'))
                else
                  const SizedBox(),
                if (isComplete)
                  Chip(
                    label: Text(noteResult, style: const TextStyle(fontWeight: FontWeight.bold)),
                    avatar: Icon(Icons.music_note, color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePitchIndicator(ThemeData theme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Listening...', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
              _currentNote.isNotEmpty ? _currentNote : '--',
              style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, String voiceType, AppLocalizations l10n) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0), side: BorderSide(color: theme.colorScheme.primary, width: 2)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.0),
          gradient: LinearGradient(
            colors: [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(l10n.yourResults, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text(l10n.vocalRange, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text('$_lowestNote - $_highestNote', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            const SizedBox(height: 20),
            Text(l10n.probableVoiceType, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text(voiceType, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
              l10n.voiceTypeDisclaimer,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}