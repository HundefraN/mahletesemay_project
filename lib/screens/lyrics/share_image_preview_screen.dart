import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song_model.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/custom_snackbar.dart';

enum ShareTemplate {
  spotifyGlass('Spotify Glass', IconsaxPlusBold.music),
  minimalistQuote('Minimalist', IconsaxPlusBold.quote_down),
  neonAurora('Neon Aurora', IconsaxPlusBold.flash_1),
  vinylShowcase('Vinyl Record', IconsaxPlusBold.music_circle),
  amharicGold('Gold Heritage', IconsaxPlusBold.crown),
  sunsetTwilight('Sunset Glow', IconsaxPlusBold.sun_1),
  polaroidStory('Polaroid Card', IconsaxPlusBold.gallery),
  monochromeLuxury('Luxury Dark', IconsaxPlusBold.diamonds);

  final String label;
  final IconData icon;
  const ShareTemplate(this.label, this.icon);
}

enum AspectRatioPreset {
  story(9 / 16, '9:16 Story'),
  square(1 / 1, '1:1 Square'),
  portrait(4 / 5, '4:5 Portrait'),
  landscape(16 / 9, '16:9 Banner');

  final double ratio;
  final String label;
  const AspectRatioPreset(this.ratio, this.label);
}

class ShareImagePreviewScreen extends StatefulWidget {
  final Song song;
  final String albumCoverUrl;
  final String? initialSelectedText;
  final List<String>? initialSelectedLines;

  const ShareImagePreviewScreen({
    super.key,
    required this.song,
    required this.albumCoverUrl,
    this.initialSelectedText,
    this.initialSelectedLines,
  });

  @override
  State<ShareImagePreviewScreen> createState() =>
      _ShareImagePreviewScreenState();
}

class _ShareImagePreviewScreenState extends State<ShareImagePreviewScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;
  bool _isSaving = false;

  late List<String> _allLines;
  late String _currentQuoteText;

  // Customization State
  ShareTemplate _selectedTemplate = ShareTemplate.spotifyGlass;
  AspectRatioPreset _aspectRatio = AspectRatioPreset.story;

  String _fontFamily = 'Poppins';
  double _fontSize = 20.0;
  FontWeight _fontWeight = FontWeight.w700;
  TextAlign _textAlign = TextAlign.center;
  Color _selectedTextColor = Colors.white;

  // Toggles
  bool _showBranding = true;
  bool _showSongInfo = true;
  bool _showArtistName = true;
  bool _showVisualizer = true;

  // Toolbar active tab: 0: Templates, 1: Typography, 2: Colors, 3: Layout/Toggles
  int _activeToolbarTab = 0;

  final List<Color> _colorPalette = const [
    Colors.white,
    Color(0xFFFFD700), // Gold
    Color(0xFF00F5D4), // Cyan
    Color(0xFFFF80BF), // Pink
    Color(0xFF70E000), // Mint
    Color(0xFFFF9E00), // Coral Orange
    Color(0xFFE0AAFF), // Lavender
    Color(0xFFF5E6CC), // Vintage Cream
  ];

  @override
  void initState() {
    super.initState();
    _allLines = widget.song.lyrics
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (widget.initialSelectedText != null &&
        widget.initialSelectedText!.trim().isNotEmpty) {
      _currentQuoteText = widget.initialSelectedText!.trim();
    } else if (widget.initialSelectedLines != null &&
        widget.initialSelectedLines!.isNotEmpty) {
      _currentQuoteText = widget.initialSelectedLines!.join('\n');
    } else {
      // Default to the first 3-4 lines or whole lyrics if short
      _currentQuoteText = _allLines.take(4).join('\n');
    }

    _autoAdjustFontSize();
  }

  void _autoAdjustFontSize() {
    final length = _currentQuoteText.length;
    if (length > 250) {
      _fontSize = 15.0;
    } else if (length > 150) {
      _fontSize = 17.0;
    } else if (length > 80) {
      _fontSize = 19.0;
    } else if (length > 30) {
      _fontSize = 22.0;
    } else {
      _fontSize = 26.0;
    }
  }

  TextStyle _getLyricsStyle(
      {double? fontSize, FontWeight? fontWeight, Color? color, double? height}) {
    final effectiveColor = color ?? _selectedTextColor;
    final effectiveSize = fontSize ?? _fontSize;
    final effectiveWeight = fontWeight ?? _fontWeight;
    final effectiveHeight = height ?? 1.55;

    switch (_fontFamily) {
      case 'Lora':
        return GoogleFonts.lora(
            fontSize: effectiveSize,
            fontWeight: effectiveWeight,
            color: effectiveColor,
            height: effectiveHeight);
      case 'Montserrat':
        return GoogleFonts.montserrat(
            fontSize: effectiveSize,
            fontWeight: effectiveWeight,
            color: effectiveColor,
            height: effectiveHeight);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(
            fontSize: effectiveSize,
            fontWeight: effectiveWeight,
            color: effectiveColor,
            height: effectiveHeight);
      case 'Outfit':
        return GoogleFonts.outfit(
            fontSize: effectiveSize,
            fontWeight: effectiveWeight,
            color: effectiveColor,
            height: effectiveHeight);
      case 'Noto Serif Ethiopic':
        return GoogleFonts.notoSerifEthiopic(
            fontSize: effectiveSize,
            fontWeight: effectiveWeight,
            color: effectiveColor,
            height: effectiveHeight);
      case 'Poppins':
      default:
        return GoogleFonts.poppins(
            fontSize: effectiveSize,
            fontWeight: effectiveWeight,
            color: effectiveColor,
            height: effectiveHeight);
    }
  }

  Future<Uint8List?> _capturePngBytes() async {
    try {
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _shareGeneratedImage() async {
    if (_isSharing || _isSaving) return;
    setState(() => _isSharing = true);

    try {
      final pngBytes = await _capturePngBytes();
      if (pngBytes == null) {
        throw Exception('Failed to generate image bytes');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/mahletesemay_lyrics_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(filePath).create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        text:
            '🎵 "${widget.song.title}" - ${widget.song.artistName}\n#MahleteSemay #Worship',
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
            context, 'Could not share image. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _saveImageToDevice() async {
    if (_isSharing || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final pngBytes = await _capturePngBytes();
      if (pngBytes == null) {
        throw Exception('Failed to generate image bytes');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/saved_lyrics_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(filePath).create();
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        CustomSnackbar.show(context, 'Image created successfully!');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
            context, 'Could not save image. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _copyQuoteText() {
    Clipboard.setData(ClipboardData(text: _currentQuoteText));
    CustomSnackbar.show(context, 'Quote lyrics copied to clipboard!');
  }

  void _openTextAndWordEditor() {
    final textController = TextEditingController(text: _currentQuoteText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surface.withOpacity(0.96)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit & Pick Lyrics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Type custom text or tap lines below to quickly insert:',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom editable text area
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.12)),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: textController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter or edit lyrics quote here...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Line Pick Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tap Lines to Toggle',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            textController.clear();
                            setModalState(() {});
                          },
                          child: const Text('Clear All',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    // Line selection list
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _allLines.length,
                        itemBuilder: (context, index) {
                          final line = _allLines[index];
                          final isInText = textController.text.contains(line);

                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                if (isInText) {
                                  textController.text = textController.text
                                      .replaceFirst(line, '')
                                      .trim();
                                } else {
                                  if (textController.text.trim().isEmpty) {
                                    textController.text = line;
                                  } else {
                                    textController.text =
                                        '${textController.text}\n$line';
                                  }
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2.5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isInText
                                    ? theme.colorScheme.primary
                                        .withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isInText
                                      ? theme.colorScheme.primary
                                          .withOpacity(0.4)
                                      : theme.colorScheme.onSurface
                                          .withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isInText
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isInText
                                        ? theme.colorScheme.primary
                                        : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isInText
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isInText
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface,
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
                    const SizedBox(height: 10),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _currentQuoteText = textController.text.trim();
                            _autoAdjustFontSize();
                          });
                          Navigator.pop(modalCtx);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Apply Lyrics Text',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: isDark ? const Color(0xFF090912) : const Color(0xFFF4F4F8),
      appBar: AppBar(
        title: const Text('Share Studio',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(IconsaxPlusBold.copy, size: 18),
            tooltip: 'Copy Text',
            onPressed: _copyQuoteText,
          ),
          IconButton(
            icon: const Icon(IconsaxPlusBold.document_download, size: 19),
            tooltip: 'Save Image',
            onPressed: _saveImageToDevice,
          ),
          _isSharing || _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(IconsaxPlusBold.export_1, size: 19),
                  tooltip: 'Share',
                  onPressed: _shareGeneratedImage,
                ),
        ],
      ),
      body: Column(
        children: [
          // Top Quick Utility Bar (Aspect Ratio Chips + Text Picker Pill)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: AspectRatioPreset.values.map((preset) {
                        final isSelected = _aspectRatio == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(preset.label,
                                style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            onSelected: (val) =>
                                setState(() => _aspectRatio = preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(IconsaxPlusBold.edit_2, size: 13),
                  label: const Text('Edit Text',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: _openTextAndWordEditor,
                ),
              ],
            ),
          ),

          // Main Canvas Preview Area
          Expanded(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: AspectRatio(
                  aspectRatio: _aspectRatio.ratio,
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _buildTemplateCanvas(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Customization Control Center
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
      case ShareTemplate.sunsetTwilight:
        return _buildSunsetTwilightTemplate();
      case ShareTemplate.polaroidStory:
        return _buildPolaroidStoryTemplate();
      case ShareTemplate.monochromeLuxury:
        return _buildMonochromeLuxuryTemplate();
      case ShareTemplate.spotifyGlass:
      default:
        return _buildSpotifyGlassTemplate();
    }
  }

  // --- Official App Logo Watermark Component ---
  Widget _buildAppLogoWatermark({
    Color? textColor,
    double logoSize = 22,
    bool showText = true,
    String? customSubtext,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: logoSize + 4,
          height: logoSize + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.12),
            border: Border.all(
                color: Colors.white.withOpacity(0.2), width: 1),
          ),
          padding: const EdgeInsets.all(2.5),
          child: ClipOval(
            child: Image.asset(
              'assets/logo/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(IconsaxPlusBold.music,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MAHLETE SEMAY',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: (textColor ?? Colors.white).withOpacity(0.9),
                  letterSpacing: 1.2,
                ),
              ),
              if (customSubtext != null && customSubtext.isNotEmpty)
                Text(
                  customSubtext,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    color: (textColor ?? Colors.white).withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // Template 1: Spotify Glassmorphism
  Widget _buildSpotifyGlassTemplate() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop
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
                colors: [Color(0xFF1DB954), Color(0xFF121212), Color(0xFF000000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

        // Dark Frost Ambient
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.78),
                ],
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Song Info Header
              if (_showSongInfo)
                Row(
                  children: [
                    if (widget.albumCoverUrl.isNotEmpty)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8),
                          ],
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_showArtistName)
                            Text(
                              widget.song.artistName,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (_showVisualizer)
                      Row(
                        children: [
                          _buildVisualizerBar(12, 0.4),
                          _buildVisualizerBar(20, 0.8),
                          _buildVisualizerBar(16, 0.6),
                          _buildVisualizerBar(24, 1.0),
                          _buildVisualizerBar(14, 0.5),
                        ],
                      ),
                  ],
                ),

              // Lyrics Text Center
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Text(
                      _currentQuoteText,
                      textAlign: _textAlign,
                      style: _getLyricsStyle(),
                    ),
                  ),
                ),
              ),

              // Official Logo Branding
              if (_showBranding)
                Center(
                  child: _buildAppLogoWatermark(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisualizerBar(double height, double opacity) {
    return Container(
      width: 3.5,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: Colors.greenAccent.shade400.withOpacity(opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // Template 2: Minimalist Quote
  Widget _buildMinimalistQuoteTemplate() {
    return Container(
      color: const Color(0xFF141416),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Big Serif Quotation Mark
          Text(
            '“',
            style: GoogleFonts.playfairDisplay(
                fontSize: 52, color: Colors.white24, height: 0.8),
          ),

          // Central Lyrics
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle(
                    color: _selectedTextColor,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ),

          // Divider Line & Song Info + Logo
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_showSongInfo)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_showArtistName)
                        Text(
                          widget.song.artistName,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: Colors.white60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              if (_showBranding)
                _buildAppLogoWatermark(
                    textColor: Colors.white70, logoSize: 18, showText: true),
            ],
          ),
        ],
      ),
    );
  }

  // Template 3: Neon Aurora Gradient
  Widget _buildNeonAuroraTemplate() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E0854),
            Color(0xFF180B3B),
            Color(0xFF0A1E4A),
          ],
        ),
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSongInfo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFC77DFF).withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.song.title,
                    style: const TextStyle(
                        color: Color(0xFFE0AAFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5),
                  ),
                ),
                if (_showArtistName)
                  Text(
                    widget.song.artistName,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle().copyWith(
                    shadows: [
                      Shadow(
                          color: const Color(0xFF00F5D4).withOpacity(0.6),
                          blurRadius: 18),
                      Shadow(
                          color: const Color(0xFF7B2CBF).withOpacity(0.7),
                          blurRadius: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Center(
              child: _buildAppLogoWatermark(
                  textColor: const Color(0xFFE0AAFF), logoSize: 22),
            ),
        ],
      ),
    );
  }

  // Template 4: Vinyl Showcase Record
  Widget _buildVinylShowcaseTemplate() {
    return Container(
      color: const Color(0xFF1A1816),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Vinyl Disc Top Artwork with App Logo in center
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.grey.shade800, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10)
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD4AF37),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            IconsaxPlusBold.music,
                            color: Colors.black,
                            size: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showSongInfo)
            Text(
              '${widget.song.title}${_showArtistName ? " — ${widget.song.artistName}" : ""}',
              style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle(
                    color: _selectedTextColor == Colors.white
                        ? const Color(0xFFF1E9D2)
                        : _selectedTextColor,
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            _buildAppLogoWatermark(
                textColor: const Color(0xFFD4AF37),
                logoSize: 18,
                customSubtext: 'VINYL MASTER'),
        ],
      ),
    );
  }

  // Template 5: Amharic Gold Heritage
  Widget _buildAmharicGoldTemplate() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A1B),
        border: Border.all(color: const Color(0xFFC5A059), width: 3),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          if (_showSongInfo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFC5A059)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.song.title,
                style: GoogleFonts.notoSerifEthiopic(
                    color: const Color(0xFFC5A059),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle(
                    color: _selectedTextColor == Colors.white
                        ? const Color(0xFFF5E6CC)
                        : _selectedTextColor,
                    height: 1.75,
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC5A059), width: 1),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: Image.asset('assets/logo/logo.png',
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_showArtistName ? "${widget.song.artistName} • " : ""}ማህሌተ ሰማይ',
                  style: GoogleFonts.notoSerifEthiopic(
                      color: const Color(0xFFC5A059),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Template 6: Sunset Twilight Glow
  Widget _buildSunsetTwilightTemplate() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B1B3A),
            Color(0xFF432371),
            Color(0xFF9E363A),
            Color(0xFFFA6E59),
          ],
          stops: [0.0, 0.4, 0.75, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSongInfo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.song.title.toUpperCase(),
                  style: GoogleFonts.outfit(
                      color: const Color(0xFFFFD166),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontSize: 12),
                ),
                if (_showArtistName)
                  Text(
                    widget.song.artistName,
                    style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle().copyWith(
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Center(
              child: _buildAppLogoWatermark(
                  textColor: const Color(0xFFFFD166), logoSize: 22),
            ),
        ],
      ),
    );
  }

  // Template 7: Polaroid Story Card
  Widget _buildPolaroidStoryTemplate() {
    return Container(
      color: const Color(0xFFF7F5F0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          // Album Photo Frame
          if (widget.albumCoverUrl.isNotEmpty)
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedImage(
                    imageUrl: widget.albumCoverUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 400,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Lyrics Text in Polaroid Handcrafted Font
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle(
                    color: _selectedTextColor == Colors.white
                        ? const Color(0xFF2B2B2B)
                        : _selectedTextColor,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_showSongInfo)
                Expanded(
                  child: Text(
                    '${widget.song.title}${_showArtistName ? " — ${widget.song.artistName}" : ""}',
                    style: GoogleFonts.lora(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_showBranding)
                Row(
                  children: [
                    Image.asset('assets/logo/logo.png',
                        width: 16, height: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Mahlete Semay',
                      style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Template 8: Luxury Dark Monochrome
  Widget _buildMonochromeLuxuryTemplate() {
    return Container(
      color: const Color(0xFF0E0E10),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 2,
                color: Colors.white54,
              ),
              if (_showSongInfo)
                Text(
                  widget.song.title.toUpperCase(),
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold),
                ),
              Container(
                width: 28,
                height: 2,
                color: Colors.white54,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  _currentQuoteText,
                  textAlign: _textAlign,
                  style: _getLyricsStyle(height: 1.65),
                ),
              ),
            ),
          ),
          if (_showBranding)
            Center(
              child: _buildAppLogoWatermark(
                  textColor: Colors.white, logoSize: 20, showText: true),
            ),
        ],
      ),
    );
  }

  // --- Bottom Control Toolbar & Tabs ---
  Widget _buildControlToolbar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131320) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sub-Tab Segment Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolbarTabButton('Themes', IconsaxPlusBold.brush_1, 0),
              _buildToolbarTabButton('Font', IconsaxPlusBold.text, 1),
              _buildToolbarTabButton('Colors', IconsaxPlusBold.colorfilter, 2),
              _buildToolbarTabButton('Toggles', IconsaxPlusBold.setting_2, 3),
            ],
          ),
          const SizedBox(height: 12),

          // Active Sub-Panel
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildActiveTabContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarTabButton(String label, IconData icon, int tabIndex) {
    final isSelected = _activeToolbarTab == tabIndex;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _activeToolbarTab = tabIndex),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(ThemeData theme) {
    switch (_activeToolbarTab) {
      case 1:
        return _buildTypographyTab(theme);
      case 2:
        return _buildColorsTab(theme);
      case 3:
        return _buildTogglesTab(theme);
      case 0:
      default:
        return _buildTemplatesTab(theme);
    }
  }

  // Sub Tab 0: Templates
  Widget _buildTemplatesTab(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('templates-tab'),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ShareTemplate.values.map((tmpl) {
          final isSelected = _selectedTemplate == tmpl;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTemplate = tmpl),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : theme.colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(tmpl.icon,
                        size: 15,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      tmpl.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Sub Tab 1: Typography (Font family, size slider, alignment)
  Widget _buildTypographyTab(ThemeData theme) {
    return Column(
      key: const ValueKey('typography-tab'),
      children: [
        // Fonts Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              'Poppins',
              'Lora',
              'Montserrat',
              'Playfair Display',
              'Outfit',
              'Noto Serif Ethiopic',
            ].map((font) {
              final isSelected = _fontFamily == font;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(font, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  onSelected: (val) => setState(() => _fontFamily = font),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Size Slider + Alignment
        Row(
          children: [
            const Icon(Icons.format_size_rounded, size: 16),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 12.0,
                max: 36.0,
                divisions: 24,
                label: '${_fontSize.round()} pt',
                onChanged: (val) => setState(() => _fontSize = val),
              ),
            ),
            IconButton(
              icon: Icon(Icons.format_align_left_rounded,
                  size: 18,
                  color: _textAlign == TextAlign.left
                      ? theme.colorScheme.primary
                      : Colors.grey),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _textAlign = TextAlign.left),
            ),
            IconButton(
              icon: Icon(Icons.format_align_center_rounded,
                  size: 18,
                  color: _textAlign == TextAlign.center
                      ? theme.colorScheme.primary
                      : Colors.grey),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _textAlign = TextAlign.center),
            ),
            IconButton(
              icon: Icon(Icons.format_align_right_rounded,
                  size: 18,
                  color: _textAlign == TextAlign.right
                      ? theme.colorScheme.primary
                      : Colors.grey),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _textAlign = TextAlign.right),
            ),
          ],
        ),
      ],
    );
  }

  // Sub Tab 2: Color Palette
  Widget _buildColorsTab(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('colors-tab'),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _colorPalette.map((color) {
          final isSelected = _selectedTextColor.value == color.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedTextColor = color),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8)
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded,
                        size: 18,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Sub Tab 3: Toggles
  Widget _buildTogglesTab(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('toggles-tab'),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Title', style: TextStyle(fontSize: 11)),
            selected: _showSongInfo,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (val) => setState(() => _showSongInfo = val),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('App Logo', style: TextStyle(fontSize: 11)),
            selected: _showBranding,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (val) => setState(() => _showBranding = val),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Artist Name', style: TextStyle(fontSize: 11)),
            selected: _showArtistName,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (val) => setState(() => _showArtistName = val),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Waves / Ambient', style: TextStyle(fontSize: 11)),
            selected: _showVisualizer,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (val) => setState(() => _showVisualizer = val),
          ),
        ],
      ),
    );
  }
}