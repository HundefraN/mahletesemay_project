import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import '../../models/song_model.dart';
import '../../providers/setlist_provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/custom_snackbar.dart';
import 'share_image_preview_screen.dart';

class _LyricsStanza {
  final String? header;
  final String? cleanHeader;
  final String? repetition;
  final List<int> lineIndices;

  const _LyricsStanza({
    this.header,
    this.cleanHeader,
    this.repetition,
    required this.lineIndices,
  });
}

class SongDetailScreen extends StatefulWidget {
  final Song song;
  final String? heroTag;
  final String? albumCoverUrl;

  const SongDetailScreen({
    super.key,
    required this.song,
    this.heroTag,
    this.albumCoverUrl,
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  bool _showAppBarTitle = false;
  bool _isFullscreen = false;

  // Active line for Spotify-style karaoke highlight (-1 means no line currently selected)
  int _activeLineIndex = -1;

  // Auto-scroll sing-along state
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0; // 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
  Timer? _autoScrollTimer;
  bool _isUserDragging = false;
  bool _isAutoScrollPausedByUser = false;
  late AnimationController _playPulseController;
  late Animation<double> _playPulseAnimation;

  // Spotify Share Mode (Line selection mode)
  bool _isShareSelectionMode = false;
  final Set<int> _selectedLineIndices = {};
  int? _lastSelectedLineIndex;
  static const int _maxSelectableLines = 8;

  // Reading & Typography state
  String _selectedFontFamily = 'Outfit';
  TextAlign _textAlign = TextAlign.left;
  double _lineHeight = 1.6;

  late List<String> _rawLines;
  late List<String> _displayLines;
  List<_LyricsStanza> _stanzas = [];

  // Regex patterns for Ethiopic & International lyric processing
  static final RegExp _headerRegex = RegExp(
    r'^\s*(\[|\()?\s*(አዝማች|ተቀባይ|ምልልስ|ዝማሬ|መርጊያ|ክፍል\s*[፩-፲\d]+|መዝሙር|ሃሌ\s*ሉያ|Chorus|Verse\s*\d*|Bridge|Outro|Intro|Pre-Chorus|Hook|Refrain|Interlude)(\s*:\s*|\s*-\s*|\s*|\s*[\]\)])\s*(\(?\s*[\d፪-፱xX]+(?:\s*ጊዜ)?\s*\)?)?\s*$',
    caseSensitive: false,
  );

  static final RegExp _repetitionRegex = RegExp(
    r'[\(\[\{]\s*(\d+|[፩-፲]+)\s*(?:x|X|ጊዜ)\s*[\)\]\}]$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    songProvider.addToHistory(widget.song);
    songProvider.incrementViewCount(widget.song.id);

    _playPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _playPulseAnimation = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(
          parent: _playPulseController, curve: Curves.easeInOutSine),
    );

    _parseLyrics();
    _scrollController.addListener(_onScroll);
  }

  bool _isHeaderLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('(') && trimmed.endsWith(')'))) {
      return true;
    }
    return _headerRegex.hasMatch(trimmed) ||
        trimmed.toLowerCase().startsWith('chorus') ||
        trimmed.toLowerCase().startsWith('verse') ||
        trimmed.toLowerCase().startsWith('bridge') ||
        trimmed.startsWith('አዝማች') ||
        trimmed.startsWith('ተቀባይ') ||
        trimmed.startsWith('ምልልስ') ||
        trimmed.startsWith('ዝማሬ') ||
        trimmed.startsWith('ክፍል');
  }

  String _cleanHeaderTitle(String raw) {
    var clean = raw.trim();
    clean = clean.replaceAll(RegExp(r'^[\[\(\{\s]+|[\]\)\}\s]+$'), '');
    clean = clean.replaceAll(RegExp(r'[\:\-]$'), '').trim();
    return clean;
  }

  String? _extractRepetition(String text) {
    final match = _repetitionRegex.firstMatch(text.trim());
    if (match != null) {
      final count = match.group(1);
      return '${count}x';
    }
    return null;
  }

  void _parseLyrics() {
    _rawLines = widget.song.lyrics.split('\n');
    _displayLines = _rawLines;
    _stanzas = [];
    _lineKeys.clear();

    String? currentHeader;
    List<int> currentLineIndices = [];

    for (int i = 0; i < _rawLines.length; i++) {
      final trimmed = _rawLines[i].trim();
      _lineKeys[i] = GlobalKey();

      if (trimmed.isEmpty) {
        if (currentLineIndices.isNotEmpty || currentHeader != null) {
          final cleanH =
              currentHeader != null ? _cleanHeaderTitle(currentHeader) : null;
          final rep =
              currentHeader != null ? _extractRepetition(currentHeader) : null;
          _stanzas.add(_LyricsStanza(
            header: currentHeader,
            cleanHeader: cleanH,
            repetition: rep,
            lineIndices: List.from(currentLineIndices),
          ));
          currentHeader = null;
          currentLineIndices.clear();
        }
        continue;
      }

      final isHeader = _isHeaderLine(trimmed);

      if (isHeader) {
        if (currentLineIndices.isNotEmpty || currentHeader != null) {
          final cleanH =
              currentHeader != null ? _cleanHeaderTitle(currentHeader) : null;
          final rep =
              currentHeader != null ? _extractRepetition(currentHeader) : null;
          _stanzas.add(_LyricsStanza(
            header: currentHeader,
            cleanHeader: cleanH,
            repetition: rep,
            lineIndices: List.from(currentLineIndices),
          ));
          currentLineIndices.clear();
        }
        currentHeader = trimmed;
      } else {
        currentLineIndices.add(i);
      }
    }

    if (currentLineIndices.isNotEmpty || currentHeader != null) {
      final cleanH =
          currentHeader != null ? _cleanHeaderTitle(currentHeader) : null;
      final rep =
          currentHeader != null ? _extractRepetition(currentHeader) : null;
      _stanzas.add(_LyricsStanza(
        header: currentHeader,
        cleanHeader: cleanH,
        repetition: rep,
        lineIndices: List.from(currentLineIndices),
      ));
    }
  }

  void _onScroll() {
    final shouldShowTitle =
        _scrollController.hasClients && _scrollController.offset > 180;
    if (shouldShowTitle != _showAppBarTitle) {
      setState(() => _showAppBarTitle = shouldShowTitle);
    }
  }

  void _scrollToActiveLine(int lineIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final key = _lineKeys[lineIndex];
      final context = key?.currentContext;

      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 650),
          curve: Curves.fastOutSlowIn,
          alignment: 0.35,
        );
      } else {
        // Smooth fallback target calculation when context is offscreen
        final totalLines = _rawLines.length;
        if (totalLines > 0 && _scrollController.position.maxScrollExtent > 0) {
          final targetFraction = (lineIndex / totalLines).clamp(0.0, 1.0);
          final targetOffset =
              targetFraction * _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 650),
            curve: Curves.fastOutSlowIn,
          );
        }
      }
    });
  }

  // --- Dynamic Adaptive Auto-Scroll Sing-Along Engine ---

  Duration _calculateLineDuration(String line, double speedMultiplier) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return Duration(milliseconds: (850 / speedMultiplier).round());
    }

    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = trimmed.length;

    // Smooth natural sing-along reading pace
    double baseMs = 1500.0 + (words * 240.0) + (chars * 25.0);

    // Ethiopic & Standard punctuation pauses (፣ ። ፤ , . ! ?)
    final punctuationCount = RegExp(r'[፣።፤,!?\.]').allMatches(trimmed).length;
    baseMs += punctuationCount * 300.0;

    final clampedMs = baseMs.clamp(1800.0, 5500.0);
    final scaledMs = clampedMs / speedMultiplier;

    return Duration(milliseconds: scaledMs.round());
  }

  void _scheduleNextAutoScrollTick() {
    _autoScrollTimer?.cancel();
    if (!_isAutoScrolling || _isUserDragging || _isAutoScrollPausedByUser)
      return;

    final currentLine =
        (_activeLineIndex >= 0 && _activeLineIndex < _rawLines.length)
            ? _rawLines[_activeLineIndex]
            : '';
    final duration = _calculateLineDuration(currentLine, _scrollSpeed);

    _autoScrollTimer = Timer(duration, () {
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isAutoScrolling ||
          _isUserDragging ||
          _isAutoScrollPausedByUser) {
        return;
      }

      int nextLine = _activeLineIndex + 1;
      while (nextLine < _rawLines.length &&
          (_rawLines[nextLine].trim().isEmpty ||
              _isHeaderLine(_rawLines[nextLine]))) {
        nextLine++;
      }

      if (nextLine >= _rawLines.length) {
        setState(() {
          _isAutoScrolling = false;
          _playPulseController.stop();
          _playPulseController.reset();
        });
        return;
      }

      setState(() {
        _activeLineIndex = nextLine;
      });
      _scrollToActiveLine(nextLine);
      _scheduleNextAutoScrollTick();
    });
  }

  void _toggleAutoScroll() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
      _isAutoScrollPausedByUser = false;
      if (_isAutoScrolling && _activeLineIndex == -1) {
        // Find first valid line if none active
        for (int i = 0; i < _rawLines.length; i++) {
          if (_rawLines[i].trim().isNotEmpty && !_isHeaderLine(_rawLines[i])) {
            _activeLineIndex = i;
            break;
          }
        }
      }
    });

    if (_isAutoScrolling) {
      _playPulseController.repeat(reverse: true);
      if (_activeLineIndex != -1) {
        _scrollToActiveLine(_activeLineIndex);
      }
      _scheduleNextAutoScrollTick();
    } else {
      _playPulseController.stop();
      _playPulseController.reset();
      _autoScrollTimer?.cancel();
    }
  }

  void _resumeAutoScrollAfterDrag() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAutoScrollPausedByUser = false;
    });
    if (_isAutoScrolling) {
      _playPulseController.repeat(reverse: true);
      if (_activeLineIndex != -1) {
        _scrollToActiveLine(_activeLineIndex);
      }
      _scheduleNextAutoScrollTick();
    }
  }

  void _changeScrollSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_scrollSpeed == 1.0) {
        _scrollSpeed = 1.25;
      } else if (_scrollSpeed == 1.25) {
        _scrollSpeed = 1.5;
      } else if (_scrollSpeed == 1.5) {
        _scrollSpeed = 2.0;
      } else if (_scrollSpeed == 2.0) {
        _scrollSpeed = 0.75;
      } else {
        _scrollSpeed = 1.0;
      }
    });
    if (_isAutoScrolling) {
      _scheduleNextAutoScrollTick();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _playPulseController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // --- Spotify Line & Share Selection Helpers & Range Selection ---

  void _onLineTapped(int lineIndex) {
    HapticFeedback.selectionClick();
    if (_isShareSelectionMode) {
      _toggleLineSelectionForShare(lineIndex);
    } else {
      setState(() {
        if (_activeLineIndex == lineIndex) {
          _activeLineIndex = -1; // Deselect if tapped again
        } else {
          _activeLineIndex = lineIndex;
        }
      });
      if (_activeLineIndex != -1) {
        _scrollToActiveLine(lineIndex);
      }
    }
  }

  void _onLineLongPressed(int lineIndex) {
    HapticFeedback.heavyImpact();
    if (!_isShareSelectionMode) {
      setState(() {
        _isShareSelectionMode = true;
        _selectedLineIndices.clear();
        _selectedLineIndices.add(lineIndex);
        _lastSelectedLineIndex = lineIndex;
      });
    } else {
      // Smart Range Selection: Select continuous block between last selected and this line
      if (_lastSelectedLineIndex != null &&
          _lastSelectedLineIndex != lineIndex) {
        final start = _lastSelectedLineIndex! < lineIndex
            ? _lastSelectedLineIndex!
            : lineIndex;
        final end = _lastSelectedLineIndex! < lineIndex
            ? lineIndex
            : _lastSelectedLineIndex!;

        setState(() {
          for (int i = start; i <= end; i++) {
            if (_rawLines[i].trim().isNotEmpty &&
                !_isHeaderLine(_rawLines[i])) {
              if (_selectedLineIndices.length < _maxSelectableLines) {
                _selectedLineIndices.add(i);
              }
            }
          }
          _lastSelectedLineIndex = lineIndex;
        });
        HapticFeedback.mediumImpact();
        CustomSnackbar.show(
          context,
          'Selected ${_selectedLineIndices.length} lines in range',
        );
      } else {
        _toggleLineSelectionForShare(lineIndex);
      }
    }
  }

  void _toggleLineSelectionForShare(int lineIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedLineIndices.contains(lineIndex)) {
        _selectedLineIndices.remove(lineIndex);
        if (_selectedLineIndices.isEmpty) {
          _isShareSelectionMode = false;
          _lastSelectedLineIndex = null;
        }
      } else {
        if (_selectedLineIndices.length >= _maxSelectableLines) {
          CustomSnackbar.show(context,
              'Maximum $_maxSelectableLines lines can be selected for share card.');
          return;
        }
        _selectedLineIndices.add(lineIndex);
        _lastSelectedLineIndex = lineIndex;
      }
    });
  }

  void _enterShareMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isShareSelectionMode = true;
      _selectedLineIndices.clear();
      // Select current active line by default if valid
      if (_activeLineIndex >= 0 &&
          _activeLineIndex < _rawLines.length &&
          _rawLines[_activeLineIndex].trim().isNotEmpty &&
          !_isHeaderLine(_rawLines[_activeLineIndex])) {
        _selectedLineIndices.add(_activeLineIndex);
        _lastSelectedLineIndex = _activeLineIndex;
      }
    });
  }

  void _exitShareMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isShareSelectionMode = false;
      _selectedLineIndices.clear();
      _lastSelectedLineIndex = null;
    });
  }

  void _selectStanzaLines(_LyricsStanza stanza) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isShareSelectionMode = true;
      _selectedLineIndices.clear();
      for (final idx in stanza.lineIndices) {
        if (_selectedLineIndices.length < _maxSelectableLines) {
          _selectedLineIndices.add(idx);
        }
      }
      if (stanza.lineIndices.isNotEmpty) {
        _lastSelectedLineIndex = stanza.lineIndices.last;
      }
    });
    CustomSnackbar.show(
      context,
      'Selected ${stanza.cleanHeader ?? "stanza"} (${_selectedLineIndices.length} lines)',
    );
  }

  void _copyStanzaDirectly(_LyricsStanza stanza) {
    HapticFeedback.mediumImpact();
    final text = stanza.lineIndices.map((i) => _rawLines[i].trim()).join('\n');
    final stanzaName = stanza.cleanHeader ?? 'Lyrics';
    final shareContent =
        '“$text”\n\n— "${widget.song.title}" ($stanzaName) by ${widget.song.artistName}\n#MahleteSemay #Mezmur';
    Clipboard.setData(ClipboardData(text: shareContent));
    CustomSnackbar.show(context, 'Copied $stanzaName to clipboard!');
  }

  String _getSelectedLinesText() {
    final sortedIndices = _selectedLineIndices.toList()..sort();
    return sortedIndices.map((idx) => _rawLines[idx].trim()).join('\n');
  }

  void _copySelectedLines() {
    final text = _getSelectedLinesText();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final shareContent =
        '“$text”\n\n— "${widget.song.title}" by ${widget.song.artistName}\nShared via Mahlete Semay';
    Clipboard.setData(ClipboardData(text: shareContent));
    CustomSnackbar.show(
      context,
      'Copied ${_selectedLineIndices.length} line${_selectedLineIndices.length > 1 ? "s" : ""} to clipboard!',
    );
  }

  void _shareSelectedLinesDirectly() {
    final text = _getSelectedLinesText();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final shareContent =
        '“$text”\n\n— "${widget.song.title}" by ${widget.song.artistName}\nShared via Mahlete Semay';
    Share.share(shareContent);
  }

  void _copyFullSongClean() {
    HapticFeedback.mediumImpact();
    final cleanLines = _rawLines
        .where((l) => !_isHeaderLine(l) && l.trim().isNotEmpty)
        .map((l) => l.trim())
        .join('\n');
    final formatted =
        '${widget.song.title} — ${widget.song.artistName}\n\n$cleanLines\n\nShared via Mahlete Semay';
    Clipboard.setData(ClipboardData(text: formatted));
    CustomSnackbar.show(
      context,
      AppLocalizations.of(context)?.fullLyricsCopied ??
          'Full clean lyrics copied to clipboard!',
    );
  }

  void _copyFullSongStructured() {
    HapticFeedback.mediumImpact();
    final formatted =
        '${widget.song.title} — ${widget.song.artistName}\n\n${widget.song.lyrics.trim()}\n\nShared via Mahlete Semay';
    Clipboard.setData(ClipboardData(text: formatted));
    CustomSnackbar.show(
      context,
      AppLocalizations.of(context)?.structuredLyricsCopied ??
          'Full structured lyrics copied to clipboard!',
    );
  }

  void _shareFullSongText() {
    HapticFeedback.mediumImpact();
    final shareContent =
        '🎵 "${widget.song.title}"\n👤 ${widget.song.artistName}\n\n${widget.song.lyrics.trim()}\n\nShared via Mahlete Semay App';
    Share.share(shareContent);
  }

  void _openStudioWithSelectedLines() {
    final sortedIndices = _selectedLineIndices.toList()..sort();
    final selectedLinesList =
        sortedIndices.map((idx) => _rawLines[idx].trim()).toList();
    final text = selectedLinesList.join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareImagePreviewScreen(
          song: widget.song,
          albumCoverUrl: widget.albumCoverUrl ?? '',
          initialSelectedText: text.isNotEmpty ? text : null,
          initialSelectedLines:
              selectedLinesList.isNotEmpty ? selectedLinesList : null,
        ),
      ),
    );
  }

  TextStyle _getLyricsTextStyle(double fontSize, Color textColor,
      {FontWeight? fontWeight}) {
    final weight = fontWeight ?? FontWeight.w800;
    switch (_selectedFontFamily) {
      case 'Lora':
        return GoogleFonts.lora(
          fontSize: fontSize,
          height: _lineHeight,
          color: textColor,
          fontWeight: weight,
        );
      case 'Montserrat':
        return GoogleFonts.montserrat(
          fontSize: fontSize,
          height: _lineHeight,
          color: textColor,
          fontWeight: weight,
          letterSpacing: -0.3,
        );
      case 'Poppins':
        return GoogleFonts.poppins(
          fontSize: fontSize,
          height: _lineHeight,
          color: textColor,
          fontWeight: weight,
          letterSpacing: -0.3,
        );
      case 'Noto Serif Ethiopic':
        return GoogleFonts.notoSerifEthiopic(
          fontSize: fontSize,
          height: _lineHeight,
          color: textColor,
          fontWeight: weight,
        );
      default: // Outfit (Spotify standard feel)
        return GoogleFonts.outfit(
          fontSize: fontSize,
          height: _lineHeight,
          color: textColor,
          fontWeight: weight,
          letterSpacing: -0.4,
        );
    }
  }

  // --- Modals & Sheets ---

  // 2026 Unified Modern Share & Copy Hub Modal
  void _showModernShareOptionsModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = theme.colorScheme.primary;
        final onSurface = theme.colorScheme.onSurface;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1D33).withOpacity(0.96)
                  : Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : onSurface.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.25)
                          : onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(IconsaxPlusBold.export_1,
                          color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.shareAndCopyHub ?? 'Share & Copy Hub',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: isDark ? Colors.white : onSurface,
                            ),
                          ),
                          Text(
                            '${widget.song.title} • ${widget.song.artistName}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withOpacity(0.65)
                                  : onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.white70
                              : onSurface.withOpacity(0.6)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Hero Action: Share Studio Card
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openStudioWithSelectedLines();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                primaryColor.withOpacity(0.28),
                                const Color(0xFF1E1035).withOpacity(0.85),
                              ]
                            : [
                                primaryColor.withOpacity(0.14),
                                primaryColor.withOpacity(0.06),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primaryColor.withOpacity(isDark ? 0.5 : 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, const Color(0xFFE0AAFF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(IconsaxPlusBold.gallery_export,
                                color: Colors.black, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    AppLocalizations.of(context)?.quoteCardStudio ?? 'Quote Card Studio',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 9.5,
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'STUDIO PRO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Design aesthetic cards for Instagram, Stories & Telegram',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.7)
                                      : onSurface.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white60
                                : onSurface.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Grid of Copy & Share Options
                Row(
                  children: [
                    Expanded(
                      child: _buildShareHubOptionTile(
                        icon: IconsaxPlusBold.tick_circle,
                        title: AppLocalizations.of(context)?.selectLinesTitle ?? AppLocalizations.of(context)?.selectLines ?? 'Select Lines',
                        subtitle: AppLocalizations.of(context)?.selectLinesSubtitle ?? 'Pick exact verses',
                        isDark: isDark,
                        onSurface: onSurface,
                        primaryColor: primaryColor,
                        onTap: () {
                          Navigator.pop(ctx);
                          _enterShareMode();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildShareHubOptionTile(
                        icon: IconsaxPlusBold.quote_down,
                        title: AppLocalizations.of(context)?.copyQuoteTitle ?? AppLocalizations.of(context)?.copyQuote ?? 'Copy Quote',
                        subtitle: AppLocalizations.of(context)?.copyQuoteSubtitle ?? 'With artist credit',
                        isDark: isDark,
                        onSurface: onSurface,
                        primaryColor: primaryColor,
                        onTap: () {
                          Navigator.pop(ctx);
                          final sample = _rawLines
                              .where((l) =>
                                  !_isHeaderLine(l) && l.trim().isNotEmpty)
                              .take(4)
                              .join('\n');
                          final formatted =
                              '“$sample”\n\n— "${widget.song.title}" by ${widget.song.artistName}\n#MahleteSemay';
                          Clipboard.setData(ClipboardData(text: formatted));
                          CustomSnackbar.show(
                              context, 'Quote lyrics copied to clipboard!');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildShareHubOptionTile(
                        icon: IconsaxPlusBold.document_copy,
                        title: AppLocalizations.of(context)?.cleanLyricsTitle ?? AppLocalizations.of(context)?.cleanLyrics ?? 'Clean Lyrics',
                        subtitle: AppLocalizations.of(context)?.cleanLyricsSubtitle ?? 'Without tags',
                        isDark: isDark,
                        onSurface: onSurface,
                        primaryColor: primaryColor,
                        onTap: () {
                          Navigator.pop(ctx);
                          _copyFullSongClean();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildShareHubOptionTile(
                        icon: IconsaxPlusBold.textalign_left,
                        title: AppLocalizations.of(context)?.fullStructureTitle ?? AppLocalizations.of(context)?.fullStructure ?? 'Full Structure',
                        subtitle: AppLocalizations.of(context)?.fullStructureSubtitle ?? 'Verses & Chorus',
                        isDark: isDark,
                        onSurface: onSurface,
                        primaryColor: primaryColor,
                        onTap: () {
                          Navigator.pop(ctx);
                          _copyFullSongStructured();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Direct System Share Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareFullSongText();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.18)
                            : onSurface.withOpacity(0.15),
                      ),
                    ),
                    icon: Icon(IconsaxPlusBold.send_2,
                        size: 16, color: isDark ? Colors.white : onSurface),
                    label: Text(
                      AppLocalizations.of(context)?.shareFullText ?? 'Share Full Text via Apps...',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareHubOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color onSurface,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : onSurface.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryColor, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: isDark ? Colors.white : onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : onSurface.withOpacity(0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLyricsAppearanceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final primaryColor = theme.colorScheme.primary;
            final onSurface = theme.colorScheme.onSurface;

            final themeProvider = Provider.of<ThemeProvider>(context);
            final currentSize = themeProvider.lyricsFontSize;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1D33).withOpacity(0.96)
                      : Colors.white.withOpacity(0.98),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : onSurface.withOpacity(0.08),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.25)
                              : onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.lyricsTypographyStyle ?? 'Lyrics Typography & Style',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark ? Colors.white : onSurface,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.close_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white70
                                  : onSurface.withOpacity(0.6)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Font Family Selector
                    Text(
                      AppLocalizations.of(context)?.fontFamily ?? 'Font Family',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          'Outfit',
                          'Poppins',
                          'Montserrat',
                          'Lora',
                          'Noto Serif Ethiopic'
                        ].map((font) {
                          final isSelected = _selectedFontFamily == font;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(font),
                              labelStyle: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark
                                        ? Colors.white
                                        : onSurface.withOpacity(0.9)),
                              ),
                              selected: isSelected,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              side: BorderSide(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                        ? Colors.white.withOpacity(0.15)
                                        : onSurface.withOpacity(0.12)),
                              ),
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : onSurface.withOpacity(0.05),
                              selectedColor: primaryColor,
                              onSelected: (val) {
                                setState(() => _selectedFontFamily = font);
                                setModalState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Font Size Edit
                    Text(
                      AppLocalizations.of(context)?.lyricsSize ?? 'Lyrics Size',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSizeStepButton(
                          icon: Icons.remove_rounded,
                          enabled: currentSize > 14.0,
                          isDark: isDark,
                          onSurface: onSurface,
                          onTap: () {
                            final newSize = (currentSize - 2).clamp(14.0, 34.0);
                            themeProvider.setLyricsFontSize(newSize);
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                primaryColor.withOpacity(isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: primaryColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${currentSize.round()} pt',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildSizeStepButton(
                          icon: Icons.add_rounded,
                          enabled: currentSize < 34.0,
                          isDark: isDark,
                          onSurface: onSurface,
                          onTap: () {
                            final newSize = (currentSize + 2).clamp(14.0, 34.0);
                            themeProvider.setLyricsFontSize(newSize);
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildSizePresetChip(
                                  label: 'S',
                                  size: 16.0,
                                  currentSize: currentSize,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  onSurface: onSurface,
                                  onTap: () {
                                    themeProvider.setLyricsFontSize(16.0);
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(width: 6),
                                _buildSizePresetChip(
                                  label: 'M (Spotify)',
                                  size: 21.0,
                                  currentSize: currentSize,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  onSurface: onSurface,
                                  onTap: () {
                                    themeProvider.setLyricsFontSize(21.0);
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(width: 6),
                                _buildSizePresetChip(
                                  label: 'L',
                                  size: 26.0,
                                  currentSize: currentSize,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  onSurface: onSurface,
                                  onTap: () {
                                    themeProvider.setLyricsFontSize(26.0);
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(width: 6),
                                _buildSizePresetChip(
                                  label: 'XL',
                                  size: 30.0,
                                  currentSize: currentSize,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  onSurface: onSurface,
                                  onTap: () {
                                    themeProvider.setLyricsFontSize(30.0);
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Text Alignment & Line Spacing Row
                    Row(
                      children: [
                        // Alignment Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)?.alignment ?? 'Alignment',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStyleOptionChip(
                                    label: AppLocalizations.of(context)?.alignLeft ?? 'Left',
                                    icon: Icons.format_align_left_rounded,
                                    isSelected: _textAlign == TextAlign.left,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    onSurface: onSurface,
                                    onTap: () {
                                      setState(
                                          () => _textAlign = TextAlign.left);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStyleOptionChip(
                                    label: AppLocalizations.of(context)?.alignCenter ?? 'Center',
                                    icon: Icons.format_align_center_rounded,
                                    isSelected: _textAlign == TextAlign.center,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    onSurface: onSurface,
                                    onTap: () {
                                      setState(
                                          () => _textAlign = TextAlign.center);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Line Spacing Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)?.spacing ?? 'Spacing',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStyleOptionChip(
                                    label: '1.6x',
                                    isSelected: (_lineHeight - 1.6).abs() < 0.1,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    onSurface: onSurface,
                                    onTap: () {
                                      setState(() => _lineHeight = 1.6);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStyleOptionChip(
                                    label: '1.85x',
                                    isSelected:
                                        (_lineHeight - 1.85).abs() < 0.1,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    onSurface: onSurface,
                                    onTap: () {
                                      setState(() => _lineHeight = 1.85);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStyleOptionChip(
                                    label: '2.1x',
                                    isSelected: (_lineHeight - 2.1).abs() < 0.1,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    onSurface: onSurface,
                                    onTap: () {
                                      setState(() => _lineHeight = 2.1);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSizeStepButton({
    required IconData icon,
    required bool enabled,
    required bool isDark,
    required Color onSurface,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? (isDark
                  ? Colors.white.withOpacity(0.1)
                  : onSurface.withOpacity(0.06))
              : (isDark
                  ? Colors.white.withOpacity(0.03)
                  : onSurface.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : onSurface.withOpacity(0.1),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? (isDark ? Colors.white : onSurface)
              : (isDark ? Colors.white30 : onSurface.withOpacity(0.25)),
        ),
      ),
    );
  }

  Widget _buildSizePresetChip({
    required String label,
    required double size,
    required double currentSize,
    required bool isDark,
    required Color primaryColor,
    required Color onSurface,
    required VoidCallback onTap,
  }) {
    final isSelected = (currentSize - size).abs() < 1.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : onSurface.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? Colors.white.withOpacity(0.12)
                    : onSurface.withOpacity(0.08)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white : onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildStyleOptionChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required bool isDark,
    required Color primaryColor,
    required Color onSurface,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : onSurface.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? Colors.white.withOpacity(0.12)
                    : onSurface.withOpacity(0.1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white : onSurface),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white : onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToSetlistDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = theme.colorScheme.primary;
        final onSurface = theme.colorScheme.onSurface;

        final setlistProvider = Provider.of<SetlistProvider>(context);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1D33).withOpacity(0.96)
                  : Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : onSurface.withOpacity(0.08),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.25)
                          : onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)?.addToSetlist ?? 'Add to Setlist',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (setlistProvider.setlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        AppLocalizations.of(context)?.noSetlistsCreatedYet ?? "No setlists created yet.",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white60
                              : onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: setlistProvider.setlists.length,
                        itemBuilder: (context, index) {
                          final setlist = setlistProvider.setlists[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            leading: Icon(IconsaxPlusBold.music_playlist,
                                size: 20, color: primaryColor),
                            title: Text(
                              setlist.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDark ? Colors.white : onSurface,
                              ),
                            ),
                            onTap: () {
                              setlistProvider.addSongToSetlist(
                                  setlist.id!, widget.song.id);
                              Navigator.pop(modalCtx);
                              CustomSnackbar.show(context,
                                  AppLocalizations.of(context)?.addedSongToSetlist(widget.song.title, setlist.name) ?? 'Added "${widget.song.title}" to "${setlist.name}"');
                            },
                          );
                        },
                      ),
                    ),
                  Divider(
                    height: 18,
                    color:
                        isDark ? Colors.white12 : onSurface.withOpacity(0.08),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    leading: Icon(IconsaxPlusBold.add_circle,
                        color: primaryColor, size: 20),
                    title: Text(
                      AppLocalizations.of(context)?.createNewSetlist ?? 'Create New Setlist',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      _showCreateSetlistDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateSetlistDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13233D) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Text(
            AppLocalizations.of(context)?.newSetlist ?? 'New Setlist',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: isDark ? Colors.white : onSurface,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isDark ? Colors.white : onSurface,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.setlistNameHint ?? 'Setlist Name',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : onSurface.withOpacity(0.4),
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.08)
                    : onSurface.withOpacity(0.04),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : onSurface.withOpacity(0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (AppLocalizations.of(context)?.pleaseEnterName ?? 'Please enter a name')
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : onSurface.withOpacity(0.7),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nav = Navigator.of(dialogCtx);
                  final setlistProvider =
                      Provider.of<SetlistProvider>(context, listen: false);
                  final setlistId = await setlistProvider
                      .createSetlist(controller.text.trim());
                  setlistProvider.addSongToSetlist(setlistId, widget.song.id);
                  nav.pop();
                  if (context.mounted) {
                    CustomSnackbar.show(
                        context, AppLocalizations.of(context)?.setlistCreatedAndSongAdded ?? 'Setlist created and song added!');
                  }
                }
              },
              child: Text(
                AppLocalizations.of(context)?.create ?? 'Create',
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Build UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontSize = themeProvider.lyricsFontSize;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Ambient atmospheric glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor.withOpacity(isDark ? 0.16 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Main Scrollable Lyrics Body with Drag/Gesture Notification
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  if (notification.dragDetails != null && _isAutoScrolling) {
                    _isUserDragging = true;
                    _autoScrollTimer?.cancel();
                  }
                } else if (notification is ScrollEndNotification) {
                  if (_isUserDragging && _isAutoScrolling) {
                    _isUserDragging = false;
                    _isAutoScrollPausedByUser = true;
                    setState(() {});
                  }
                }
                return false;
              },
              child: GestureDetector(
                onTap: () {
                  if (!_isShareSelectionMode) {
                    setState(() => _isFullscreen = !_isFullscreen);
                  }
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Spotify Top Header Bar (collapsible)
                    SliverAppBar(
                      expandedHeight: _isFullscreen ? 0 : 200,
                      pinned: true,
                      stretch: true,
                      backgroundColor: _showAppBarTitle
                          ? (isDark
                              ? theme.colorScheme.surface.withOpacity(0.92)
                              : theme.scaffoldBackgroundColor.withOpacity(0.95))
                          : Colors.transparent,
                      elevation: 0,
                      leading: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.85),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.15)
                                      : onSurface.withOpacity(0.08),
                                ),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: isDark ? Colors.white : onSurface,
                                  size: 17,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        // Animated Favorite Button (pinned) / Exit selection
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.white.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.15)
                                        : onSurface.withOpacity(0.08),
                                  ),
                                  boxShadow: isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: _isShareSelectionMode
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color:
                                              isDark ? Colors.white : onSurface,
                                          size: 18,
                                        ),
                                        tooltip: 'Exit selection',
                                        onPressed: _exitShareMode,
                                      )
                                    : Center(
                                        child: _AnimatedFavoriteButton(
                                          songId: widget.song.id,
                                          size: 19,
                                          isDark: isDark,
                                          primaryColor: primaryColor,
                                          onSurface: onSurface,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      title: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _showAppBarTitle
                            ? Column(
                                key: const ValueKey('appbar-title-visible'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.song.title,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    widget.song.artistName,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.7)
                                          : onSurface.withOpacity(0.65),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('appbar-title-hidden'),
                              ),
                      ),
                      flexibleSpace: _isFullscreen
                          ? null
                          : FlexibleSpaceBar(
                              background: _buildSpotifyParallaxHeader(
                                primaryColor: primaryColor,
                                isDark: isDark,
                                onSurface: onSurface,
                              ),
                            ),
                    ),

                    // Spotify Share Mode Guidance Banner (when active)
                    if (_isShareSelectionMode)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                primaryColor.withOpacity(isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  primaryColor.withOpacity(isDark ? 0.4 : 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(IconsaxPlusBold.info_circle,
                                  color: primaryColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tap lines to select (up to $_maxSelectableLines) or long-press for range',
                                  style: GoogleFonts.outfit(
                                    color: isDark ? Colors.white : onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedLineIndices.length}/$_maxSelectableLines',
                                style: GoogleFonts.outfit(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Lyrics Stream Body
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          _isShareSelectionMode ? 10 : 24,
                          20,
                          160,
                        ),
                        child: Column(
                          crossAxisAlignment: _textAlign == TextAlign.center
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            for (int sIdx = 0;
                                sIdx < _stanzas.length;
                                sIdx++) ...[
                              _buildSpotifyStanza(
                                _stanzas[sIdx],
                                sIdx,
                                fontSize,
                                primaryColor: primaryColor,
                                isDark: isDark,
                                onSurface: onSurface,
                              ),
                              if (sIdx < _stanzas.length - 1)
                                const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating User Auto-Scroll Resume Chip (if paused during scroll)
          if (_isAutoScrolling && _isAutoScrollPausedByUser)
            Positioned(
              bottom: 84,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _resumeAutoScrollAfterDrag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Auto-scroll paused • Tap to resume',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
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

          // 4. Floating Bottom Controls (Spotify Player Bar or Share Banner)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            bottom: _isFullscreen && !_isShareSelectionMode ? -100 : 18,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _isShareSelectionMode
                  ? _buildSpotifyShareBottomBar(
                      context,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onSurface: onSurface,
                    )
                  : _buildSpotifyFloatingPill(
                      context,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onSurface: onSurface,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Background & Visual Layer ---

  Widget _buildSpotifyParallaxHeader({
    required Color primaryColor,
    required bool isDark,
    required Color onSurface,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Album Cover Card
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : primaryColor.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.albumCoverUrl != null &&
                      widget.albumCoverUrl!.isNotEmpty
                  ? CachedImage(
                      imageUrl: widget.albumCoverUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(isDark ? 0.2 : 0.12),
                      ),
                      child: Center(
                        child: Icon(
                          IconsaxPlusBold.music,
                          color: isDark ? Colors.white : primaryColor,
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Song Info Details
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'song-title-${widget.song.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      widget.song.title,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: isDark
                            ? const [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                  color: Colors.black54,
                                ),
                              ]
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.song.artistName,
                  style: GoogleFonts.outfit(
                    color: isDark
                        ? Colors.white.withOpacity(0.85)
                        : onSurface.withOpacity(0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (widget.song.scale != null &&
                        widget.song.scale!.isNotEmpty) ...[
                      _buildMiniBadge(
                        'Scale: ${widget.song.scale!}',
                        isDark: isDark,
                        primaryColor: primaryColor,
                        onSurface: onSurface,
                      ),
                      const SizedBox(width: 6),
                    ],
                    _buildMiniBadge(
                      '${NumberFormat.compact().format(widget.song.viewCount)} ${AppLocalizations.of(context)?.plays ?? "plays"}',
                      icon: IconsaxPlusLinear.eye,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onSurface: onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(
    String label, {
    IconData? icon,
    required bool isDark,
    required Color primaryColor,
    required Color onSurface,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.12)
            : onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : onSurface.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 10.5,
              color: isDark ? Colors.white70 : onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white.withOpacity(0.9) : onSurface,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Stanza & Line Widgets ---

  Widget _buildSpotifyStanza(
    _LyricsStanza stanza,
    int stanzaIndex,
    double fontSize, {
    required Color primaryColor,
    required bool isDark,
    required Color onSurface,
  }) {
    final title = (stanza.cleanHeader ?? stanza.header)?.toUpperCase();

    return Column(
      crossAxisAlignment: _textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        // Section Header Bar
        if (title != null && title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.12)
                          : primaryColor.withOpacity(0.16),
                    ),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (stanza.repetition != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stanza.repetition!,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Spotify Lyric Lines
        for (final lineIndex in stanza.lineIndices)
          _buildSpotifyLine(
            lineIndex,
            fontSize,
            primaryColor: primaryColor,
            isDark: isDark,
            onSurface: onSurface,
          ),
      ],
    );
  }

  Widget _buildSpotifyLine(
    int lineIndex,
    double fontSize, {
    required Color primaryColor,
    required bool isDark,
    required Color onSurface,
  }) {
    final line = _rawLines[lineIndex].trim();
    if (line.isEmpty) return const SizedBox.shrink();

    final isActive = _activeLineIndex == lineIndex;
    final isSelectedForShare = _selectedLineIndices.contains(lineIndex);

    // Dynamic Spotify styling
    final Color textColor = _isShareSelectionMode
        ? (isSelectedForShare
            ? (isDark ? Colors.white : onSurface)
            : (isDark
                ? Colors.white.withOpacity(0.32)
                : onSurface.withOpacity(0.32)))
        : (_activeLineIndex == -1
            ? (isDark ? Colors.white.withOpacity(0.92) : onSurface)
            : (isActive
                ? (isDark ? Colors.white : onSurface)
                : (isDark
                    ? Colors.white.withOpacity(0.42)
                    : onSurface.withOpacity(0.40))));

    final FontWeight fontWeight = (isActive || isSelectedForShare)
        ? FontWeight.w900
        : (_activeLineIndex == -1 ? FontWeight.w700 : FontWeight.w600);

    final double effectiveSize = isActive ? (fontSize + 1.0) : fontSize;

    return Padding(
      key: _lineKeys[lineIndex],
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onLineTapped(lineIndex),
          onLongPress: () => _onLineLongPressed(lineIndex),
          borderRadius: BorderRadius.circular(14),
          splashColor: primaryColor.withOpacity(0.15),
          highlightColor: isDark
              ? Colors.white.withOpacity(0.05)
              : onSurface.withOpacity(0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelectedForShare
                  ? primaryColor.withOpacity(isDark ? 0.22 : 0.12)
                  : (isActive && !_isShareSelectionMode
                      ? (isDark
                          ? primaryColor.withOpacity(0.16)
                          : primaryColor.withOpacity(0.09))
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
              border: isSelectedForShare
                  ? Border.all(color: primaryColor, width: 1.5)
                  : (isActive && !_isShareSelectionMode
                      ? Border.all(
                          color: primaryColor.withOpacity(isDark ? 0.35 : 0.22),
                          width: 1.2,
                        )
                      : Border.all(color: Colors.transparent, width: 1.2)),
              boxShadow: isSelectedForShare ||
                      (isActive && !_isShareSelectionMode)
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(isDark ? 0.2 : 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Karaoke active line indicator bar
                if (isActive && !_isShareSelectionMode)
                  Container(
                    width: 3.5,
                    height: effectiveSize * 1.3,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                if (_isShareSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelectedForShare
                            ? primaryColor
                            : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : onSurface.withOpacity(0.05)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelectedForShare
                              ? primaryColor
                              : (isDark
                                  ? Colors.white38
                                  : onSurface.withOpacity(0.25)),
                          width: 1.5,
                        ),
                      ),
                      child: isSelectedForShare
                          ? Icon(
                              Icons.check,
                              size: 13,
                              color: isDark ? Colors.black : Colors.white,
                            )
                          : null,
                    ),
                  ),
                Expanded(
                  child: Text(
                    line,
                    textAlign: _textAlign,
                    style: _getLyricsTextStyle(
                      effectiveSize,
                      textColor,
                      fontWeight: fontWeight,
                    ).copyWith(
                      shadows: isActive && !_isShareSelectionMode
                          ? (isDark
                              ? [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.7),
                                    blurRadius: 10,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : [
                                  Shadow(
                                    color: primaryColor.withOpacity(0.12),
                                    blurRadius: 6,
                                  ),
                                ])
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Bottom Control Bars ---

  Widget _buildSpotifyFloatingPill(
    BuildContext context, {
    required Color primaryColor,
    required bool isDark,
    required Color onSurface,
  }) {
    return ClipRRect(
      key: const ValueKey('spotify-controls-pill'),
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1D33).withOpacity(0.92)
                : Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : onSurface.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.45)
                    : onSurface.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Animated Play/Pause Auto-Scroll Group
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _playPulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isAutoScrolling)
                            Container(
                              width: 44 * _playPulseAnimation.value,
                              height: 44 * _playPulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(
                                  (0.35 * (1.3 - _playPulseAnimation.value))
                                      .clamp(0.0, 0.35),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleAutoScroll,
                              borderRadius: BorderRadius.circular(22),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isAutoScrolling
                                      ? primaryColor
                                      : (isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : onSurface.withOpacity(0.06)),
                                  border: Border.all(
                                    color: _isAutoScrolling
                                        ? primaryColor
                                        : (isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : onSurface.withOpacity(0.08)),
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: child),
                                  child: Icon(
                                    _isAutoScrolling
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    key: ValueKey<bool>(_isAutoScrolling),
                                    color: _isAutoScrolling
                                        ? (isDark ? Colors.black : Colors.white)
                                        : (isDark ? Colors.white : onSurface),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Animated Speed Multiplier Chip
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: _isAutoScrolling
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: _changeScrollSpeed,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor
                                      .withOpacity(isDark ? 0.22 : 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: primaryColor
                                        .withOpacity(isDark ? 0.5 : 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.speed_rounded,
                                      size: 11,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${_scrollSpeed}x',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              // Add to Setlist
              IconButton(
                icon: const Icon(IconsaxPlusBold.music_playlist, size: 20),
                color: isDark ? Colors.white70 : onSurface.withOpacity(0.7),
                tooltip: AppLocalizations.of(context)?.addToSetlist ?? 'Add to Setlist',
                onPressed: () => _showAddToSetlistDialog(context),
              ),

              // Typography & Lyrics Size
              IconButton(
                icon: const Icon(IconsaxPlusBold.text, size: 20),
                color: isDark ? Colors.white70 : onSurface.withOpacity(0.7),
                tooltip: AppLocalizations.of(context)?.typographyAndSize ?? 'Typography & Size',
                onPressed: () => _showLyricsAppearanceModal(context),
              ),

              // Unified Share & Copy Hub Trigger
              IconButton(
                icon: const Icon(IconsaxPlusBold.export_1, size: 20),
                color: isDark ? Colors.white : onSurface,
                tooltip: AppLocalizations.of(context)?.shareAndCopyHub ?? 'Share & Copy Hub',
                onPressed: () => _showModernShareOptionsModal(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyShareBottomBar(
    BuildContext context, {
    required Color primaryColor,
    required bool isDark,
    required Color onSurface,
  }) {
    final count = _selectedLineIndices.length;

    return ClipRRect(
      key: const ValueKey('spotify-share-banner'),
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1D33).withOpacity(0.96)
                : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryColor.withOpacity(isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.5)
                    : onSurface.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Count Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count / $_maxSelectableLines',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: primaryColor,
                  ),
                ),
              ),
              const Spacer(),

              // Primary Share Studio Button (Creates image card)
              FilledButton.icon(
                onPressed: count > 0 ? _openStudioWithSelectedLines : null,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(IconsaxPlusBold.gallery_export, size: 15),
                label: Text(
                  AppLocalizations.of(context)?.shareCardButton ?? 'Share Card',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Copy selected
              IconButton(
                icon: const Icon(IconsaxPlusBold.copy, size: 18),
                color: isDark ? Colors.white : onSurface,
                tooltip: AppLocalizations.of(context)?.copyButton ?? 'Copy',
                visualDensity: VisualDensity.compact,
                onPressed: count > 0 ? _copySelectedLines : null,
              ),

              // Share text directly
              IconButton(
                icon: const Icon(IconsaxPlusBold.send_2, size: 18),
                color: isDark ? Colors.white : onSurface,
                tooltip: AppLocalizations.of(context)?.shareTextButton ?? 'Share Text',
                visualDensity: VisualDensity.compact,
                onPressed: count > 0 ? _shareSelectedLinesDirectly : null,
              ),

              // Close selection mode
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: isDark ? Colors.white70 : onSurface.withOpacity(0.6),
                tooltip: 'Cancel',
                visualDensity: VisualDensity.compact,
                onPressed: _exitShareMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedFavoriteButton extends StatefulWidget {
  final String songId;
  final double size;
  final bool isDark;
  final Color primaryColor;
  final Color onSurface;

  const _AnimatedFavoriteButton({
    required this.songId,
    this.size = 22,
    required this.isDark,
    required this.primaryColor,
    required this.onSurface,
  });

  @override
  State<_AnimatedFavoriteButton> createState() =>
      _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<_AnimatedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.72)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.38)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 48,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.38, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 30,
      ),
    ]).animate(_controller);

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.75, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0.0);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    songProvider.toggleFavorite(widget.songId);
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final isFav = songProvider.isFavorite(widget.songId);
    final favColor =
        widget.isDark ? const Color(0xFFFF4D6D) : const Color(0xFFE63946);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(widget.size + 12),
        splashColor: favColor.withOpacity(0.2),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Expanding Halo Ripple on Favorite
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  if (_controller.value == 0 || _controller.value == 1) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    width: widget.size * (1 + _rippleAnimation.value),
                    height: widget.size * (1 + _rippleAnimation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: favColor.withOpacity(
                        _opacityAnimation.value.clamp(0.0, 1.0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: favColor.withOpacity(
                            (_opacityAnimation.value * 0.5).clamp(0.0, 1.0),
                          ),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Animated Scaled Heart Icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey<bool>(isFav),
                    color: isFav
                        ? favColor
                        : (widget.isDark
                            ? Colors.white70
                            : widget.onSurface.withOpacity(0.65)),
                    size: widget.size,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
