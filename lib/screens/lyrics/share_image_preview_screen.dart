import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song_model.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/custom_snackbar.dart';

enum ShareTemplate {
  spotifyGlass,
  minimalistQuote,
  neonAurora,
  vinylShowcase,
  amharicGold,
}

enum AspectRatioPreset {
  story(9 / 16, '9:16 (Story)'),
  square(1 / 1, '1:1 (Square)'),
  portrait(4 / 5, '4:5 (Post)');

  final double ratio;
  final String label;
  const AspectRatioPreset(this.ratio, this.label);
}

class ShareImagePreviewScreen extends StatefulWidget {
  final Song song;
  final String albumCoverUrl;
  final List<String>? initialSelectedLines;

  const ShareImagePreviewScreen({
    super.key,
    required this.song,
    required this.albumCoverUrl,
    this.initialSelectedLines,
  });

  @override
  State<ShareImagePreviewScreen> createState() => _ShareImagePreviewScreenState();
}

class _ShareImagePreviewScreenState extends State<ShareImagePreviewScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;

  late List<String> _allLines;
  late List<String> _selectedLines;

  ShareTemplate _selectedTemplate = ShareTemplate.spotifyGlass;
  AspectRatioPreset _aspectRatio = AspectRatioPreset.story;

  String _fontFamily = 'Poppins';
  TextAlign _textAlign = TextAlign.center;
  bool _showBranding = true;
  bool _showSongInfo = true;
  Color _customTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _allLines = widget.song.lyrics
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (widget.initialSelectedLines != null && widget.initialSelectedLines!.isNotEmpty) {
      _selectedLines = List.from(widget.initialSelectedLines!);
    } else {
      // Default to first 4 lines
      _selectedLines = _allLines.take(4).toList();
    }
  }

  TextStyle _getGoogleFontStyle({double fontSize = 18, FontWeight fontWeight = FontWeight.w600, Color? color}) {
    final effectiveColor = color ?? _customTextColor;
    switch (_fontFamily) {
      case 'Lora':
        return GoogleFonts.lora(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor, height: 1.6);
      case 'Montserrat':
        return GoogleFonts.montserrat(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor, height: 1.5);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor, height: 1.5);
      case 'Outfit':
        return GoogleFonts.outfit(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor, height: 1.5);
      case 'Noto Serif Ethiopic':
        return GoogleFonts.notoSerifEthiopic(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor, height: 1.6);
      case 'Poppins':
      default:
        return GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: effectiveColor, height: 1.5);
    }
  }

  Future<void> _shareGeneratedImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // Wait one frame to ensure RepaintBoundary is clean
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Unable to capture render object');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to generate PNG data');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/lyrics_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(filePath).create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        text: '🎵 "${widget.song.title}" - ${widget.song.artistName}\n#MahleteSemay',
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Could not create image. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _openLineSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface.withOpacity(0.95) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Select Lines to Share', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedLines.clear();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap consecutive lines to highlight lyrics (${_selectedLines.length} selected)',
                      style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _allLines.length,
                        itemBuilder: (context, index) {
                          final line = _allLines[index];
                          final isSelected = _selectedLines.contains(line);

                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  _selectedLines.remove(line);
                                } else {
                                  _selectedLines.add(line);
                                }
                              });
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary.withOpacity(0.4)
                                      : Colors.grey.withOpacity(0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? theme.colorScheme.primary : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Apply Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Share Studio', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _isSharing
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(IconsaxPlusBold.export_1),
                  tooltip: 'Share Image',
                  onPressed: _shareGeneratedImage,
                ),
        ],
      ),
      body: Column(
        children: [
          // Aspect Ratio & Line Pick Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AspectRatioPreset.values.map((preset) {
                        final isSelected = _aspectRatio == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(preset.label, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (val) => setState(() => _aspectRatio = preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(IconsaxPlusBold.textalign_left, size: 16),
                  label: Text('${_selectedLines.length} lines'),
                  onPressed: _openLineSelector,
                ),
              ],
            ),
          ),

          // Main Canvas Preview Area
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: AspectRatio(
                  aspectRatio: _aspectRatio.ratio,
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildTemplateCanvas(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Template & Style Toolbar
          _buildControlToolbar(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildTemplateCanvas() {
    switch (_selectedTemplate) {
      case ShareTemplate.minimalistQuote:
        return _buildMinimalistQuoteTemplate();
      case ShareTemplate.neonAurora:
        return _buildNeonAuroraTemplate();
      case ShareTemplate.vinylShowcase:
        return _buildVinylShowcaseTemplate();
      case ShareTemplate.amharicGold:
        return _buildAmharicGoldTemplate();
      case ShareTemplate.spotifyGlass:
      default:
        return _buildSpotifyGlassTemplate();
    }
  }

  // Template 1: Spotify Glassmorphism
  Widget _buildSpotifyGlassTemplate() {
    final lyricsText = _selectedLines.join('\n');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred Album Backdrop
        if (widget.albumCoverUrl.isNotEmpty)
          CachedImage(
            imageUrl: widget.albumCoverUrl,
            fit: BoxFit.cover,
            memCacheWidth: 600,
            memCacheHeight: 900,
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1DB954), Color(0xFF191414)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

        // Dark Frost Ambient
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.75),
                ],
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Song Badge
              if (_showSongInfo)
                Row(
                  children: [
                    if (widget.albumCoverUrl.isNotEmpty)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedImage(
                            imageUrl: widget.albumCoverUrl,
                            memCacheWidth: 150,
                            memCacheHeight: 150,
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.song.artistName,
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(IconsaxPlusBold.musicnote, color: Colors.greenAccent.shade400, size: 24),
                  ],
                ),

              // Lyrics Text Center
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      lyricsText.isEmpty ? widget.song.lyrics : lyricsText,
                      textAlign: _textAlign,
                      style: _getGoogleFontStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              // Footer Watermark
              if (_showBranding)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(IconsaxPlusBold.music, size: 16, color: Colors.greenAccent.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Mahlete Semay',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Template 2: Minimalist Quote
  Widget _buildMinimalistQuoteTemplate() {
    final lyricsText = _selectedLines.join('\n');

    return Container(
      color: const Color(0xFF141416),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Big Serif Quotation Mark
          Text(
            '“',
            style: GoogleFonts.playfairDisplay(fontSize: 56, color: Colors.white38, height: 0.8),
          ),

          // Central Lyrics in Serif
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  lyricsText.isEmpty ? widget.song.lyrics : lyricsText,
                  textAlign: _textAlign,
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                    fontStyle: FontStyle.italic,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ),

          // Divider Line & Song Info
          if (_showSongInfo) ...[
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    Text(
                      widget.song.artistName,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
                if (_showBranding)
                  Text(
                    'MAHLETE SEMAY',
                    style: GoogleFonts.outfit(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w800, color: Colors.white38),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Template 3: Neon Aurora Gradient
  Widget _buildNeonAuroraTemplate() {
    final lyricsText = _selectedLines.join('\n');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E0854),
            Color(0xFF180B3B),
            Color(0xFF0D1B44),
          ],
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSongInfo)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC77DFF).withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.song.title,
                    style: const TextStyle(color: Color(0xFFE0AAFF), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  lyricsText.isEmpty ? widget.song.lyrics : lyricsText,
                  textAlign: _textAlign,
                  style: GoogleFonts.montserrat(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.6,
                    shadows: [
                      Shadow(color: const Color(0xFF00F5D4).withOpacity(0.5), blurRadius: 16),
                      Shadow(color: const Color(0xFF7B2CBF).withOpacity(0.6), blurRadius: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '•  ${widget.song.artistName}  |  Mahlete Semay  •',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Template 4: Vinyl Showcase Record
  Widget _buildVinylShowcaseTemplate() {
    final lyricsText = _selectedLines.join('\n');

    return Container(
      color: const Color(0xFF1E1C1A),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Vinyl Disc Top Artwork
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.grey.shade800, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_showSongInfo)
            Text(
              '${widget.song.title} — ${widget.song.artistName}',
              style: GoogleFonts.outfit(color: const Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  lyricsText.isEmpty ? widget.song.lyrics : lyricsText,
                  textAlign: _textAlign,
                  style: GoogleFonts.lora(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF1E9D2),
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Text(
              'MAHLETE SEMAY VINYL COLLECTION',
              style: GoogleFonts.outfit(fontSize: 9, letterSpacing: 2, color: Colors.white30, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }

  // Template 5: Amharic Gold Heritage
  Widget _buildAmharicGoldTemplate() {
    final lyricsText = _selectedLines.join('\n');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF231F20),
        border: Border.all(color: const Color(0xFFC5A059), width: 3),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFC5A059)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.song.title,
              style: GoogleFonts.notoSerifEthiopic(color: const Color(0xFFC5A059), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  lyricsText.isEmpty ? widget.song.lyrics : lyricsText,
                  textAlign: _textAlign,
                  style: GoogleFonts.notoSerifEthiopic(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF5E6CC),
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Text(
              '${widget.song.artistName} • ማህሌተ ሰማይ',
              style: GoogleFonts.notoSerifEthiopic(color: const Color(0xFFC5A059), fontSize: 11, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  // Bottom Control Toolbar
  Widget _buildControlToolbar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161626) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template Selector Pills
          Text('Templates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTemplatePill(ShareTemplate.spotifyGlass, 'Spotify Glass', IconsaxPlusBold.music),
                _buildTemplatePill(ShareTemplate.minimalistQuote, 'Minimalist', IconsaxPlusBold.quote_down),
                _buildTemplatePill(ShareTemplate.neonAurora, 'Neon Aurora', IconsaxPlusBold.flash_1),
                _buildTemplatePill(ShareTemplate.vinylShowcase, 'Vinyl Record', IconsaxPlusBold.music_circle),
                _buildTemplatePill(ShareTemplate.amharicGold, 'Gold Heritage', IconsaxPlusBold.crown),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Toggles & Alignment Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Alignment buttons
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.format_align_left, color: _textAlign == TextAlign.left ? theme.colorScheme.primary : Colors.grey),
                    onPressed: () => setState(() => _textAlign = TextAlign.left),
                  ),
                  IconButton(
                    icon: Icon(Icons.format_align_center, color: _textAlign == TextAlign.center ? theme.colorScheme.primary : Colors.grey),
                    onPressed: () => setState(() => _textAlign = TextAlign.center),
                  ),
                  IconButton(
                    icon: Icon(Icons.format_align_right, color: _textAlign == TextAlign.right ? theme.colorScheme.primary : Colors.grey),
                    onPressed: () => setState(() => _textAlign = TextAlign.right),
                  ),
                ],
              ),

              // Branding & Header Toggles
              Row(
                children: [
                  FilterChip(
                    label: const Text('Title', style: TextStyle(fontSize: 11)),
                    selected: _showSongInfo,
                    onSelected: (val) => setState(() => _showSongInfo = val),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Logo', style: TextStyle(fontSize: 11)),
                    selected: _showBranding,
                    onSelected: (val) => setState(() => _showBranding = val),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePill(ShareTemplate template, String label, IconData icon) {
    final isSelected = _selectedTemplate == template;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedTemplate = template),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? theme.colorScheme.primary : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}