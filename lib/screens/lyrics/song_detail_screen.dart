import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song_model.dart';
import '../../providers/setlist_provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/custom_snackbar.dart';
import 'share_image_preview_screen.dart';

/// Preset color themes inspired by Spotify's vibrant dynamic lyrics backdrops
class SpotifyLyricsPalette {
  final String name;
  final List<Color> gradientColors;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final Color accentColor;

  const SpotifyLyricsPalette({
    required this.name,
    required this.gradientColors,
    this.activeTextColor = Colors.white,
    this.inactiveTextColor = const Color(0x75FFFFFF),
    this.accentColor = const Color(0xFF1DB954),
  });
}

const List<SpotifyLyricsPalette> kSpotifyPalettes = [
  SpotifyLyricsPalette(
    name: 'Spotify Green',
    gradientColors: [Color(0xFF0F3822), Color(0xFF06180E), Color(0xFF020905)],
    accentColor: Color(0xFF1DB954),
  ),
  SpotifyLyricsPalette(
    name: 'Deep Amethyst',
    gradientColors: [Color(0xFF3B1259), Color(0xFF1E0831), Color(0xFF0B0314)],
    accentColor: Color(0xFFC084FC),
  ),
  SpotifyLyricsPalette(
    name: 'Midnight Navy',
    gradientColors: [Color(0xFF0F2B48), Color(0xFF081829), Color(0xFF030B14)],
    accentColor: Color(0xFF38BDF8),
  ),
  SpotifyLyricsPalette(
    name: 'Crimson Ruby',
    gradientColors: [Color(0xFF540D1D), Color(0xFF2C040D), Color(0xFF120104)],
    accentColor: Color(0xFFFB7185),
  ),
  SpotifyLyricsPalette(
    name: 'Sunset Amber',
    gradientColors: [Color(0xFF592D08), Color(0xFF2E1502), Color(0xFF140801)],
    accentColor: Color(0xFFFBBF24),
  ),
  SpotifyLyricsPalette(
    name: 'Teal Aurora',
    gradientColors: [Color(0xFF0E3D3A), Color(0xFF061F1E), Color(0xFF020C0C)],
    accentColor: Color(0xFF2DD4BF),
  ),
  SpotifyLyricsPalette(
    name: 'Charcoal Minimal',
    gradientColors: [Color(0xFF262626), Color(0xFF141414), Color(0xFF0A0A0A)],
    accentColor: Color(0xFFFFFFFF),
  ),
];

class _LyricsStanza {
  final String? header;
  final List<int> lineIndices;
  const _LyricsStanza({this.header, required this.lineIndices});
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

class _SongDetailScreenState extends State<SongDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  bool _showAppBarTitle = false;
  bool _isFullscreen = false;

  // Active line for Spotify-style karaoke highlight
  int _activeLineIndex = 0;

  // Auto-scroll sing-along state
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0; // 1x, 1.5x, 2x
  Timer? _autoScrollTimer;

  // Spotify Share Mode (Line selection mode)
  bool _isShareSelectionMode = false;
  final Set<int> _selectedLineIndices = {};
  static const int _maxSelectableLines = 5;

  // Active Spotify color palette index
  int _selectedPaletteIndex = 0;

  // Reading & Typography state
  String _selectedFontFamily = 'Outfit';
  TextAlign _textAlign = TextAlign.left;
  double _lineHeight = 1.85;

  late List<String> _rawLines;
  late List<String> _displayLines;
  List<_LyricsStanza> _stanzas = [];

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    songProvider.addToHistory(widget.song);
    songProvider.incrementViewCount(widget.song.id);

    _parseLyrics();
    _pickInitialPalette();
    _scrollController.addListener(_onScroll);
  }

  void _pickInitialPalette() {
    // Generate a stable color palette index based on song id hash
    final hash = widget.song.id.hashCode.abs();
    _selectedPaletteIndex = hash % kSpotifyPalettes.length;
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
          _stanzas.add(_LyricsStanza(
            header: currentHeader,
            lineIndices: List.from(currentLineIndices),
          ));
          currentHeader = null;
          currentLineIndices.clear();
        }
        continue;
      }

      final isHeader = (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('(') && trimmed.endsWith(')')) ||
          trimmed.toLowerCase().startsWith('chorus') ||
          trimmed.toLowerCase().startsWith('verse') ||
          trimmed.startsWith('አዝማች') ||
          trimmed.startsWith('ዝማሬ');

      if (isHeader) {
        if (currentLineIndices.isNotEmpty || currentHeader != null) {
          _stanzas.add(_LyricsStanza(
            header: currentHeader,
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
      _stanzas.add(_LyricsStanza(
        header: currentHeader,
        lineIndices: List.from(currentLineIndices),
      ));
    }

    // Set first valid lyric line as active
    for (int i = 0; i < _rawLines.length; i++) {
      if (_rawLines[i].trim().isNotEmpty &&
          !_rawLines[i].trim().startsWith('[') &&
          !_rawLines[i].trim().startsWith('(')) {
        _activeLineIndex = i;
        break;
      }
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
    final key = _lineKeys[lineIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    if (_isAutoScrolling) {
      _startAutoScrollTimer();
    } else {
      _autoScrollTimer?.cancel();
    }
  }

  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    // Advance active line periodically in Spotify sing-along fashion
    final interval = (_scrollSpeed == 2.0)
        ? const Duration(milliseconds: 2200)
        : (_scrollSpeed == 1.5)
            ? const Duration(milliseconds: 3000)
            : const Duration(milliseconds: 4000);

    _autoScrollTimer = Timer.periodic(interval, (timer) {
      if (!_scrollController.hasClients || !_isAutoScrolling) {
        timer.cancel();
        return;
      }

      int nextLine = _activeLineIndex + 1;
      while (nextLine < _rawLines.length && _rawLines[nextLine].trim().isEmpty) {
        nextLine++;
      }

      if (nextLine >= _rawLines.length) {
        setState(() => _isAutoScrolling = false);
        timer.cancel();
        return;
      }

      setState(() {
        _activeLineIndex = nextLine;
      });
      _scrollToActiveLine(nextLine);
    });
  }

  void _changeScrollSpeed() {
    setState(() {
      if (_scrollSpeed == 1.0) {
        _scrollSpeed = 1.5;
      } else if (_scrollSpeed == 1.5) {
        _scrollSpeed = 2.0;
      } else {
        _scrollSpeed = 1.0;
      }
    });
    if (_isAutoScrolling) {
      _startAutoScrollTimer();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // --- Spotify Line & Share Selection Helpers ---

  void _onLineTapped(int lineIndex) {
    HapticFeedback.selectionClick();
    if (_isShareSelectionMode) {
      _toggleLineSelectionForShare(lineIndex);
    } else {
      setState(() {
        _activeLineIndex = lineIndex;
      });
      _scrollToActiveLine(lineIndex);
    }
  }

  void _onLineLongPressed(int lineIndex) {
    HapticFeedback.mediumImpact();
    if (!_isShareSelectionMode) {
      setState(() {
        _isShareSelectionMode = true;
        _selectedLineIndices.clear();
        _selectedLineIndices.add(lineIndex);
      });
    } else {
      _toggleLineSelectionForShare(lineIndex);
    }
  }

  void _toggleLineSelectionForShare(int lineIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedLineIndices.contains(lineIndex)) {
        _selectedLineIndices.remove(lineIndex);
        if (_selectedLineIndices.isEmpty) {
          _isShareSelectionMode = false;
        }
      } else {
        if (_selectedLineIndices.length >= _maxSelectableLines) {
          CustomSnackbar.show(
              context, 'Maximum $_maxSelectableLines lines can be selected.');
          return;
        }
        _selectedLineIndices.add(lineIndex);
      }
    });
  }

  void _enterShareMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isShareSelectionMode = true;
      _selectedLineIndices.clear();
      // Select current active line by default
      if (_activeLineIndex >= 0 &&
          _activeLineIndex < _rawLines.length &&
          _rawLines[_activeLineIndex].trim().isNotEmpty) {
        _selectedLineIndices.add(_activeLineIndex);
      }
    });
  }

  void _exitShareMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isShareSelectionMode = false;
      _selectedLineIndices.clear();
    });
  }

  String _getSelectedLinesText() {
    final sortedIndices = _selectedLineIndices.toList()..sort();
    return sortedIndices.map((idx) => _rawLines[idx].trim()).join('\n');
  }

  void _copySelectedLines() {
    final text = _getSelectedLinesText();
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    CustomSnackbar.show(
      context,
      'Copied ${_selectedLineIndices.length} line${_selectedLineIndices.length > 1 ? "s" : ""} to clipboard!',
    );
  }

  void _shareSelectedLinesDirectly() {
    final text = _getSelectedLinesText();
    if (text.isEmpty) return;

    final shareContent =
        '$text\n\n— "${widget.song.title}" by ${widget.song.artistName}\nShared via Mahlete Semay';
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

  void _showPaletteSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF181818).withOpacity(0.96),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spotify Gradient Theme',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(kSpotifyPalettes.length, (index) {
                    final palette = kSpotifyPalettes[index];
                    final isSelected = _selectedPaletteIndex == index;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedPaletteIndex = index);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 76) / 2,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: palette.gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? palette.accentColor
                                : Colors.white.withOpacity(0.12),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: palette.accentColor.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: palette.accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 11, color: Colors.black)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                palette.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
            final themeProvider = Provider.of<ThemeProvider>(context);
            final currentSize = themeProvider.lyricsFontSize;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818).withOpacity(0.96),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lyrics Typography & Style',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Font Family Selector
                    Text(
                      'Font Family',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
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
                                color: isSelected ? Colors.black : Colors.white,
                              ),
                              selected: isSelected,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF1DB954)
                                    : Colors.white.withOpacity(0.15),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.06),
                              selectedColor: const Color(0xFF1DB954),
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
                      'Lyrics Size',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSizeStepButton(
                          icon: Icons.remove_rounded,
                          enabled: currentSize > 14.0,
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
                            color: const Color(0xFF1DB954).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1DB954).withOpacity(0.4)),
                          ),
                          child: Text(
                            '${currentSize.round()} pt',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1DB954),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildSizeStepButton(
                          icon: Icons.add_rounded,
                          enabled: currentSize < 34.0,
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
                                'Alignment',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStyleOptionChip(
                                    label: 'Left',
                                    icon: Icons.format_align_left_rounded,
                                    isSelected: _textAlign == TextAlign.left,
                                    onTap: () {
                                      setState(
                                          () => _textAlign = TextAlign.left);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStyleOptionChip(
                                    label: 'Center',
                                    icon: Icons.format_align_center_rounded,
                                    isSelected: _textAlign == TextAlign.center,
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
                                'Spacing',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStyleOptionChip(
                                    label: '1.6x',
                                    isSelected: (_lineHeight - 1.6).abs() < 0.1,
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
                                    onTap: () {
                                      setState(() => _lineHeight = 1.85);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStyleOptionChip(
                                    label: '2.1x',
                                    isSelected: (_lineHeight - 2.1).abs() < 0.1,
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
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : Colors.white30,
        ),
      ),
    );
  }

  Widget _buildSizePresetChip({
    required String label,
    required double size,
    required double currentSize,
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
              ? const Color(0xFF1DB954)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStyleOptionChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1DB954)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1DB954)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.black : Colors.white,
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
        final setlistProvider = Provider.of<SetlistProvider>(context);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF181818).withOpacity(0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Add to Setlist',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (setlistProvider.setlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "No setlists created yet.",
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: Colors.white60),
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
                            leading: const Icon(IconsaxPlusBold.music_playlist,
                                size: 20, color: Color(0xFF1DB954)),
                            title: Text(
                              setlist.name,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.white),
                            ),
                            onTap: () {
                              setlistProvider.addSongToSetlist(
                                  setlist.id!, widget.song.id);
                              Navigator.pop(modalCtx);
                              CustomSnackbar.show(context,
                                  'Added "${widget.song.title}" to "${setlist.name}"');
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(height: 18, color: Colors.white12),
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    leading: const Icon(IconsaxPlusBold.add_circle,
                        color: Color(0xFF1DB954), size: 20),
                    title: Text(
                      'Create New Setlist',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF1DB954),
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
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Text('New Setlist',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.white)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Setlist Name',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a name'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.white70)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
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
                        context, 'Setlist created and song added!');
                  }
                }
              },
              child: Text('Create',
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  // --- Build UI ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentPalette = kSpotifyPalettes[_selectedPaletteIndex];
    final fontSize = themeProvider.lyricsFontSize;

    return Scaffold(
      backgroundColor: currentPalette.gradientColors.last,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Spotify Dynamic Fluid Gradient Mesh Background
          Positioned.fill(
            child: _buildSpotifyGradientBackground(currentPalette),
          ),

          // 2. Main Scrollable Lyrics Body
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_isShareSelectionMode) {
                  // Keep share mode active for line picking
                } else {
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
                        ? currentPalette.gradientColors.first.withOpacity(0.95)
                        : Colors.transparent,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 17),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      // Share mode trigger / Fullscreen toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isShareSelectionMode
                                      ? Icons.close_rounded
                                      : IconsaxPlusLinear.export_1,
                                  color: Colors.white,
                                  size: 19,
                                ),
                                tooltip: _isShareSelectionMode
                                    ? 'Exit selection'
                                    : 'Share lyrics',
                                onPressed: () {
                                  if (_isShareSelectionMode) {
                                    _exitShareMode();
                                  } else {
                                    _enterShareMode();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    title: AnimatedOpacity(
                      opacity: _showAppBarTitle ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.song.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.song.artistName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    flexibleSpace: _isFullscreen
                        ? null
                        : FlexibleSpaceBar(
                            background: _buildSpotifyParallaxHeader(currentPalette),
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
                          color: const Color(0xFF1DB954).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF1DB954).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(IconsaxPlusBold.info_circle,
                                color: Color(0xFF1DB954), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tap lines to select (up to $_maxSelectableLines) to share',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Text(
                              '${_selectedLineIndices.length}/$_maxSelectableLines',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1DB954),
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
                          for (int sIdx = 0; sIdx < _stanzas.length; sIdx++) ...[
                            _buildSpotifyStanza(
                              _stanzas[sIdx],
                              sIdx,
                              fontSize,
                              currentPalette,
                            ),
                            if (sIdx < _stanzas.length - 1)
                              const SizedBox(height: 28),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Bottom Controls (Spotify Player Bar or Share Banner)
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
                  ? _buildSpotifyShareBottomBar(context, currentPalette)
                  : _buildSpotifyFloatingPill(context, currentPalette),
            ),
          ),
        ],
      ),
    );
  }

  // --- Background & Visual Layer ---

  Widget _buildSpotifyGradientBackground(SpotifyLyricsPalette palette) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark backdrop
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: palette.gradientColors,
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Glowing radial ambient top light
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          height: 380,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.accentColor.withOpacity(0.22),
                  palette.accentColor.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Blurred noise/ambient texture overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildSpotifyParallaxHeader(SpotifyLyricsPalette palette) {
    final songProvider = Provider.of<SongProvider>(context);
    final isFav = songProvider.isFavorite(widget.song.id);

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
                  color: Colors.black.withOpacity(0.5),
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
                        gradient: LinearGradient(
                          colors: palette.gradientColors,
                        ),
                      ),
                      child: const Center(
                        child: Icon(IconsaxPlusBold.music,
                            color: Colors.white, size: 28),
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
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: const [
                          Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 6,
                              color: Colors.black54),
                        ],
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
                    color: Colors.white.withOpacity(0.85),
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
                      _buildMiniBadge('Scale: ${widget.song.scale!}'),
                      const SizedBox(width: 6),
                    ],
                    _buildMiniBadge(
                      '${NumberFormat.compact().format(widget.song.viewCount)} plays',
                      icon: IconsaxPlusLinear.eye,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Favorite Heart Button on Header
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? const Color(0xFF1DB954) : Colors.white70,
              size: 22,
            ),
            tooltip: 'Favorite',
            onPressed: () => songProvider.toggleFavorite(widget.song.id),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.5, color: Colors.white70),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.9),
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
    double fontSize,
    SpotifyLyricsPalette palette,
  ) {
    return Column(
      crossAxisAlignment: _textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        // Section Header (e.g. [Chorus], [Verse 1], [አዝማች])
        if (stanza.header != null && stanza.header!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                stanza.header!.replaceAll('[', '').replaceAll(']', '').toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.accentColor,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),

        // Spotify Lyric Lines
        for (final lineIndex in stanza.lineIndices)
          _buildSpotifyLine(
            lineIndex,
            fontSize,
            palette,
          ),
      ],
    );
  }

  Widget _buildSpotifyLine(
    int lineIndex,
    double fontSize,
    SpotifyLyricsPalette palette,
  ) {
    final line = _rawLines[lineIndex].trim();
    if (line.isEmpty) return const SizedBox.shrink();

    final isActive = _activeLineIndex == lineIndex;
    final isSelectedForShare = _selectedLineIndices.contains(lineIndex);

    // Dynamic Spotify styling:
    // In share mode: Selected lines are bright with Spotify green badge/border.
    // In normal mode: Active line is 100% white bold; inactive lines are dimmed translucent (~0.45).
    final Color textColor = _isShareSelectionMode
        ? (isSelectedForShare ? Colors.white : Colors.white.withOpacity(0.35))
        : (isActive ? Colors.white : palette.inactiveTextColor);

    final FontWeight fontWeight = (isActive || isSelectedForShare)
        ? FontWeight.w900
        : FontWeight.w700;

    final double effectiveSize = isActive ? (fontSize + 1.0) : fontSize;

    return Padding(
      key: _lineKeys[lineIndex],
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onLineTapped(lineIndex),
          onLongPress: () => _onLineLongPressed(lineIndex),
          borderRadius: BorderRadius.circular(12),
          splashColor: palette.accentColor.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelectedForShare
                  ? palette.accentColor.withOpacity(0.2)
                  : (isActive && !_isShareSelectionMode
                      ? Colors.white.withOpacity(0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: isSelectedForShare
                  ? Border.all(color: palette.accentColor, width: 1.5)
                  : (isActive && !_isShareSelectionMode
                      ? Border.all(color: Colors.white.withOpacity(0.12), width: 1)
                      : Border.all(color: Colors.transparent, width: 1)),
              boxShadow: isSelectedForShare
                  ? [
                      BoxShadow(
                        color: palette.accentColor.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isShareSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelectedForShare
                            ? palette.accentColor
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelectedForShare
                              ? palette.accentColor
                              : Colors.white38,
                          width: 1.5,
                        ),
                      ),
                      child: isSelectedForShare
                          ? const Icon(Icons.check,
                              size: 13, color: Colors.black)
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
                          ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ]
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
      BuildContext context, SpotifyLyricsPalette palette) {
    return ClipRRect(
      key: const ValueKey('spotify-controls-pill'),
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Palette / Gradient Theme Switcher
              IconButton(
                icon: const Icon(IconsaxPlusBold.colorfilter, size: 20),
                color: palette.accentColor,
                tooltip: 'Theme & Colors',
                onPressed: () => _showPaletteSelector(context),
              ),

              // Auto-Scroll Sing-Along Play/Pause
              IconButton(
                icon: Icon(
                  _isAutoScrolling
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: _isAutoScrolling
                      ? palette.accentColor
                      : Colors.white,
                  size: 24,
                ),
                tooltip: _isAutoScrolling
                    ? 'Pause sing-along'
                    : 'Auto sing-along karaoke',
                onPressed: _toggleAutoScroll,
              ),

              // Speed Badge (when auto-scrolling)
              if (_isAutoScrolling)
                GestureDetector(
                  onTap: _changeScrollSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: palette.accentColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${_scrollSpeed}x',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: palette.accentColor,
                      ),
                    ),
                  ),
                ),

              // Add to Setlist
              IconButton(
                icon: const Icon(IconsaxPlusBold.music_playlist, size: 20),
                color: Colors.white70,
                tooltip: 'Add to Setlist',
                onPressed: () => _showAddToSetlistDialog(context),
              ),

              // Typography & Lyrics Size
              IconButton(
                icon: const Icon(IconsaxPlusBold.text, size: 20),
                color: Colors.white70,
                tooltip: 'Typography & Size',
                onPressed: () => _showLyricsAppearanceModal(context),
              ),

              // Spotify Share Lyrics Button
              IconButton(
                icon: const Icon(IconsaxPlusBold.export_1, size: 20),
                color: Colors.white,
                tooltip: 'Share Lyrics',
                onPressed: _enterShareMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyShareBottomBar(
      BuildContext context, SpotifyLyricsPalette palette) {
    final count = _selectedLineIndices.length;

    return ClipRRect(
      key: const ValueKey('spotify-share-banner'),
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF181818).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: palette.accentColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
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
                  color: palette.accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count / $_maxSelectableLines lines',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: palette.accentColor,
                  ),
                ),
              ),
              const Spacer(),

              // Primary Share Studio Button (Creates image card)
              FilledButton.icon(
                onPressed: count > 0 ? _openStudioWithSelectedLines : null,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accentColor,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(IconsaxPlusBold.gallery_export, size: 15),
                label: Text(
                  'Share Card',
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
                color: Colors.white,
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                onPressed: count > 0 ? _copySelectedLines : null,
              ),

              // Share text directly
              IconButton(
                icon: const Icon(IconsaxPlusBold.send_2, size: 18),
                color: Colors.white,
                tooltip: 'Share Text',
                visualDensity: VisualDensity.compact,
                onPressed: count > 0 ? _shareSelectedLinesDirectly : null,
              ),

              // Close selection mode
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: Colors.white70,
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
