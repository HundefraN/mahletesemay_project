import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:mahlete_semay_project/utils/constants.dart';

class VocalPianoRoll extends StatelessWidget {
  final String? lowestNote;
  final String? highestNote;
  final String? currentNote;
  final VoiceTypeRange? voiceTypeRange;

  const VocalPianoRoll({
    super.key,
    this.lowestNote,
    this.highestNote,
    this.currentNote,
    this.voiceTypeRange,
  });

  int _noteToMidi(String note) {
    if (note.isEmpty) return -1;
    const notesMap = {
      'C': 0,
      'C#': 1,
      'D': 2,
      'D#': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'G': 7,
      'G#': 8,
      'A': 9,
      'A#': 10,
      'B': 11
    };
    try {
      final octaveStr = note.substring(note.length - 1);
      final key = note.substring(0, note.length - 1);
      if (!notesMap.containsKey(key)) return -1;
      final octave = int.parse(octaveStr);
      return (octave + 1) * 12 + notesMap[key]!;
    } catch (_) {
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final lowMidi = _noteToMidi(lowestNote ?? '');
    final highMidi = _noteToMidi(highestNote ?? '');
    final currentMidi = _noteToMidi(currentNote ?? '');

    const startMidi = 36; // C2
    const endMidi = 84; // C6

    final List<int> whiteKeysMidi = [];
    final List<int> allKeysMidi = [];

    for (int m = startMidi; m <= endMidi; m++) {
      allKeysMidi.add(m);
      final noteInOctave = m % 12;
      final isBlack = (noteInOctave == 1 ||
          noteInOctave == 3 ||
          noteInOctave == 6 ||
          noteInOctave == 8 ||
          noteInOctave == 10);
      if (!isBlack) {
        whiteKeysMidi.add(m);
      }
    }

    return Card(
      elevation: 3,
      shadowColor: theme.colorScheme.primary.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with flex protection against RenderFlex overflows
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Vocal Range Roll',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (voiceTypeRange != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primaryContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        '${voiceTypeRange!.name} (${voiceTypeRange!.lowNote}-${voiceTypeRange!.highNote})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Piano Keyboard Visualizer Box
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SizedBox(
                height: 115,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWhiteKeys = whiteKeysMidi.length;
                    final keyWidth = constraints.maxWidth / totalWhiteKeys;

                    return Stack(
                      children: [
                        // White Keys Layer
                        Row(
                          children: whiteKeysMidi.map((midi) {
                            final isCurrent = (midi == currentMidi);
                            final isInUserRange = (lowMidi != -1 &&
                                highMidi != -1 &&
                                midi >= lowMidi &&
                                midi <= highMidi);
                            final isLowest = (midi == lowMidi);
                            final isHighest = (midi == highMidi);

                            Color baseColor =
                                isDark ? Colors.grey.shade800 : Colors.white;
                            if (isInUserRange) {
                              baseColor =
                                  theme.colorScheme.primary.withOpacity(0.28);
                            }
                            if (isLowest || isHighest) {
                              baseColor =
                                  theme.colorScheme.secondary.withOpacity(0.45);
                            }
                            if (isCurrent) {
                              baseColor = theme.colorScheme.primary;
                            }

                            final isC = (midi % 12 == 0);
                            final octaveNum = (midi ~/ 12) - 1;

                            return Container(
                              width: keyWidth,
                              height: 108,
                              decoration: BoxDecoration(
                                color: baseColor,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    baseColor.withOpacity(0.85),
                                    baseColor,
                                  ],
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                  width: 0.5,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(5),
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  if (isC)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6.0),
                                      child: Text(
                                        'C$octaveNum',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent
                                              ? Colors.white
                                              : (isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                  if (isLowest)
                                    Positioned(
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.blueAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_downward_rounded,
                                          size: 8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (isHighest)
                                    Positioned(
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.purpleAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        // Black Keys Layer
                        ...allKeysMidi
                            .where((m) => (m % 12 == 1 ||
                                m % 12 == 3 ||
                                m % 12 == 6 ||
                                m % 12 == 8 ||
                                m % 12 == 10))
                            .map((midi) {
                          int whiteIndexBefore = 0;
                          for (int w = 0; w < whiteKeysMidi.length; w++) {
                            if (whiteKeysMidi[w] < midi) {
                              whiteIndexBefore = w;
                            }
                          }

                          final leftOffset =
                              (whiteIndexBefore + 0.62) * keyWidth;
                          final blackWidth = keyWidth * 0.72;

                          final isCurrent = (midi == currentMidi);
                          final isInUserRange = (lowMidi != -1 &&
                              highMidi != -1 &&
                              midi >= lowMidi &&
                              midi <= highMidi);

                          Color keyColor =
                              isDark ? Colors.black : Colors.grey.shade900;
                          if (isInUserRange) {
                            keyColor =
                                theme.colorScheme.primary.withOpacity(0.9);
                          }
                          if (isCurrent) {
                            keyColor = theme.colorScheme.secondary;
                          }

                          return Positioned(
                            left: leftOffset,
                            top: 0,
                            width: blackWidth,
                            height: 68,
                            child: Container(
                              decoration: BoxDecoration(
                                color: keyColor,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(4),
                                ),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 3,
                                    offset: const Offset(1, 3),
                                  )
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Modern Styled Legend Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendPill(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  label: AppLocalizations.of(context)?.analyzedRange ?? 'Analyzed Range',
                ),
                const SizedBox(width: 12),
                _LegendPill(
                  color: Colors.blueAccent,
                  label: AppLocalizations.of(context)?.lowNote ?? 'Low Note',
                ),
                const SizedBox(width: 12),
                _LegendPill(
                  color: Colors.purpleAccent,
                  label: AppLocalizations.of(context)?.highNote ?? 'High Note',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
              )
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
