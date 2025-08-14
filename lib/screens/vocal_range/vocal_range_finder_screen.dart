import 'package:flutter/material.dart';
import 'dart:async';

class VocalRangeFinderScreen extends StatefulWidget {
  const VocalRangeFinderScreen({super.key});

  @override
  State<VocalRangeFinderScreen> createState() => _VocalRangeFinderScreenState();
}

class _VocalRangeFinderScreenState extends State<VocalRangeFinderScreen> {
  String _lowestNote = '';
  String _highestNote = '';
  String _vocalRange = '';
  String _voiceType = '';
  bool _isFindingLowest = false;
  bool _isFindingHighest = false;

  void _findLowestNote() {
    setState(() {
      _isFindingLowest = true;
      _lowestNote = '';
      _vocalRange = '';
      _voiceType = '';
    });
    Timer(const Duration(seconds: 3), () {
      setState(() {
        _lowestNote = 'E2';
        _isFindingLowest = false;
      });
    });
  }

  void _findHighestNote() {
    setState(() {
      _isFindingHighest = true;
      _highestNote = '';
      _vocalRange = '';
      _voiceType = '';
    });
    Timer(const Duration(seconds: 3), () {
      setState(() {
        _highestNote = 'G4';
        _isFindingHighest = false;
        _calculateRange();
      });
    });
  }

  void _calculateRange() {
    if (_lowestNote.isNotEmpty && _highestNote.isNotEmpty) {
      setState(() {
        _vocalRange = '$_lowestNote - $_highestNote';
        _voiceType = 'Baritone';
      });
    }
  }

  void _reset() {
    setState(() {
      _lowestNote = '';
      _highestNote = '';
      _vocalRange = '';
      _voiceType = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocal Range Finder'),
        actions: [IconButton(onPressed: _reset, icon: const Icon(Icons.refresh))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionCard(
              context,
              '1. Find Your Lowest Note',
              'Hum or sing the lowest note you can comfortably produce without straining.',
              _isFindingLowest,
              _lowestNote,
              _findLowestNote,
              _lowestNote.isEmpty,
            ),
            const SizedBox(height: 20),
            _buildInstructionCard(
              context,
              '2. Find Your Highest Note',
              'Now, find the highest note you can sing comfortably, without pushing into falsetto (unless that\'s part of your usable range).',
              _isFindingHighest,
              _highestNote,
              _findHighestNote,
              _lowestNote.isNotEmpty,
            ),
            const SizedBox(height: 40),
            if (_vocalRange.isNotEmpty) _buildResultCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(BuildContext context, String title, String instruction,
      bool isLoading, String result, VoidCallback onPressed, bool isEnabled) {
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
                ElevatedButton.icon(
                  onPressed: isEnabled && !isLoading ? onPressed : null,
                  icon: Icon(isLoading ? Icons.mic_none : Icons.mic),
                  label: Text(isLoading ? 'Listening...' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                if (result.isNotEmpty)
                  Chip(
                    label: Text(result, style: const TextStyle(fontWeight: FontWeight.bold)),
                    avatar: Icon(Icons.music_note, color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
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
            const Text('Your Results', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Vocal Range', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text(_vocalRange, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            const SizedBox(height: 20),
            Text('Probable Voice Type', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text(_voiceType, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text(
              '(This is an estimate. A professional vocal coach can provide a more accurate classification.)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}