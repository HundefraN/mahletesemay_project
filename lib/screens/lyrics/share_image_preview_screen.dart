import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song_model.dart';
import '../../widgets/custom_snackbar.dart';

enum LyricSelectionMode { all, snippet, words }

class ShareImagePreviewScreen extends StatefulWidget {
  final Song song;
  final String albumCoverUrl;

  const ShareImagePreviewScreen({
    super.key,
    required this.song,
    required this.albumCoverUrl,
  });

  @override
  State<ShareImagePreviewScreen> createState() => _ShareImagePreviewScreenState();
}

class _ShareImagePreviewScreenState extends State<ShareImagePreviewScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  LyricSelectionMode _selectionMode = LyricSelectionMode.all;
  int _startingLineIndex = 0;
  String _customWordsSelection = '';
  late List<String> _lyricsLines;

  dynamic _background;
  bool _useAlbumArt = true;
  Color _textColor = Colors.white;
  bool _showTitleAndArtist = true;
  bool _showAppNameFooter = true;

  Offset _textOffset = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;
  bool _isTransforming = false;

  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  TextStyle _fontStyle = GoogleFonts.montserrat();
  TextAlign _textAlign = TextAlign.center;

  @override
  void initState() {
    super.initState();
    _lyricsLines = widget.song.lyrics.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (widget.albumCoverUrl.isEmpty) {
      _useAlbumArt = false;
      _background = const Color(0xff0D47A1);
    }
  }

  String get _displayedLyrics {
    switch (_selectionMode) {
      case LyricSelectionMode.all: return widget.song.lyrics;
      case LyricSelectionMode.snippet:
        String snippet = _lyricsLines.skip(_startingLineIndex).take(8).join('\n');
        if (_lyricsLines.length > _startingLineIndex + 8) snippet += '\n...';
        return snippet;
      case LyricSelectionMode.words: return _customWordsSelection;
    }
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/lyrics_share.png').create();
      await file.writeAsBytes(pngBytes);
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Check out the lyrics for "${widget.song.title}" by ${widget.song.artistName}!');
    } catch (e) {
      if(mounted) CustomSnackbar.show(context, 'Could not share image. Please try again.', isError: true);
    } finally {
      if(mounted) setState(() => _isSharing = false);
    }
  }

  void _showWordSelector() async {
    final result = await showDialog<String>(context: context, builder: (context) => _WordSelectorDialog(lyrics: widget.song.lyrics));
    if (result != null && result.isNotEmpty) {
      setState(() { _selectionMode = LyricSelectionMode.words; _customWordsSelection = result; });
    }
  }

  void _showColorPicker({bool isText = false}) {
    Color pickerColor = isText ? _textColor : ((_background is Color) ? _background : Colors.blueGrey);
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(isText ? 'Pick a Text Color' : 'Pick a Background Color'), content: SingleChildScrollView(child: ColorPicker(pickerColor: pickerColor, onColorChanged: (color) => pickerColor = color)), actions: [TextButton(child: const Text('Select'), onPressed: () { setState(() { if (isText) { _textColor = pickerColor; } else { _useAlbumArt = false; _background = pickerColor; } }); Navigator.of(context).pop(); })]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize & Share'),
        actions: [
          _isSharing
              ? const Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)))
              : IconButton(icon: const Icon(Icons.share), onPressed: _shareImage, tooltip: 'Share Image'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: RepaintBoundary(
                    key: _globalKey,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildBackground())),
                          _buildGradientOverlay(),
                          _buildLyricsContent(),
                          _buildCenterGuides(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (_useAlbumArt) return CachedImage(imageUrl: widget.albumCoverUrl, fit: BoxFit.cover);
    if (_background is Color) return Container(color: _background);
    if (_background is Gradient) return Container(decoration: BoxDecoration(gradient: _background));
    return Container();
  }

  Widget _buildGradientOverlay() => Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.5, 1])));

  Widget _buildLyricsText() {
    TextStyle baseStyle = _fontStyle.copyWith(color: _textColor, fontWeight: FontWeight.w500, shadows: [Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.5))]);
    if (_selectionMode == LyricSelectionMode.all) {
      return FittedBox(fit: BoxFit.contain, child: Text(_displayedLyrics, textAlign: _textAlign, style: baseStyle.copyWith(height: 1.5)));
    }
    return Text(_displayedLyrics, textAlign: _textAlign, style: baseStyle.copyWith(fontSize: 22, height: 1.6));
  }

  Widget _buildLyricsContent() {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          if (_showTitleAndArtist)
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Text(widget.song.title, style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, shadows: [const Shadow(blurRadius: 4, color: Colors.black54)]), textAlign: TextAlign.center),
                  Text(widget.song.artistName, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70), textAlign: TextAlign.center),
                ],
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: (details) {
                setState(() => _isTransforming = true);
                _baseScale = _scale;
                _baseRotation = _rotation;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = _baseScale * details.scale;
                  _rotation = _baseRotation + details.rotation;
                  _textOffset += details.focalPointDelta;
                });
              },
              onScaleEnd: (details) {
                setState(() => _isTransforming = false);
              },
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(_textOffset.dx + constraints.maxWidth / 2, _textOffset.dy + constraints.maxHeight / 2)
                  ..rotateZ(_rotation)
                  ..scale(_scale)
                  ..translate(-constraints.maxWidth / 2, -constraints.maxHeight / 2),
                alignment: Alignment.center,
                child: Container(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth - 48),
                  child: _buildLyricsText(),
                ),
              ),
            ),
          ),
          if (_showAppNameFooter)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.music_note, color: theme.colorScheme.secondary, size: 24),
                const SizedBox(width: 8),
                Text("Mahlete Semay", style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
              ]),
            ),
        ],
      );
    });
  }

  Widget _buildCenterGuides() {
    final bool isCentered = _textOffset.dx.abs() < 5 && _textOffset.dy.abs() < 5;
    return Visibility(
      visible: _isTransforming,
      child: IgnorePointer(
        child: Stack(
          children: [
            Align(alignment: Alignment.center, child: Container(width: 1, height: double.infinity, color: isCentered ? Colors.greenAccent : Colors.white.withOpacity(0.5))),
            Align(alignment: Alignment.center, child: Container(height: 1, width: double.infinity, color: isCentered ? Colors.greenAccent : Colors.white.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return DefaultTabController(
      length: 3,
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1.0))),
        child: Column(
          children: [
            const TabBar(
              tabs: [Tab(icon: Icon(Icons.text_fields), text: 'Lyrics'), Tab(icon: Icon(Icons.style_outlined), text: 'Style'), Tab(icon: Icon(Icons.palette_outlined), text: 'Background')],
            ),
            SizedBox(
              height: 120,
              child: TabBarView(
                children: [
                  _buildLyricsControlTab(),
                  _buildStyleControlTab(),
                  _buildBackgroundControlTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsControlTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildControlButton(icon: Icons.fullscreen, label: 'All Lyrics', isActive: _selectionMode == LyricSelectionMode.all, onTap: () => setState(() => _selectionMode = LyricSelectionMode.all)),
          _buildControlButton(icon: Icons.view_headline, label: 'Snippet', isActive: _selectionMode == LyricSelectionMode.snippet, onTap: () => setState(() => _selectionMode = LyricSelectionMode.snippet)),
          _buildControlButton(icon: Icons.format_quote, label: 'Words', isActive: _selectionMode == LyricSelectionMode.words, onTap: _showWordSelector),
        ]),
        if (_selectionMode == LyricSelectionMode.snippet)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: () => setState(() => _startingLineIndex = (_startingLineIndex - 1).clamp(0, _lyricsLines.length -1)), tooltip: 'Previous Line'),
            IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => setState(() => _startingLineIndex = (_startingLineIndex + 1).clamp(0, _lyricsLines.length -1)), tooltip: 'Next Line'),
          ]),
      ],
    );
  }

  Widget _buildStyleControlTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(icon: Icons.format_align_left, label: 'Left', isActive: _textAlign == TextAlign.left, onTap: () => setState(() => _textAlign = TextAlign.left)),
            _buildControlButton(icon: Icons.format_align_center, label: 'Center', isActive: _textAlign == TextAlign.center, onTap: () => setState(() => _textAlign = TextAlign.center)),
            _buildControlButton(icon: Icons.format_align_right, label: 'Right', isActive: _textAlign == TextAlign.right, onTap: () => setState(() => _textAlign = TextAlign.right)),
            _buildControlButton(icon: _showTitleAndArtist ? Icons.title : Icons.text_fields, label: 'Title', isActive: _showTitleAndArtist, onTap: () => setState(() => _showTitleAndArtist = !_showTitleAndArtist)),
            _buildControlButton(icon: _showAppNameFooter ? Icons.info : Icons.info_outline, label: 'Footer', isActive: _showAppNameFooter, onTap: () => setState(() => _showAppNameFooter = !_showAppNameFooter)),
          ],
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: fontPresets.entries.map((entry) => Center(child: TextButton(onPressed: () => setState(() => _fontStyle = entry.value), child: Text(entry.key, style: entry.value.copyWith(color: _fontStyle.fontFamily == entry.value.fontFamily ? Theme.of(context).colorScheme.primary : null))))).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundControlTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        if (widget.albumCoverUrl.isNotEmpty) _buildBgOption(onTap: () => setState(() => _useAlbumArt = true), isActive: _useAlbumArt, child: ClipOval(child: CachedImage(imageUrl: widget.albumCoverUrl, width: 40, height: 40))),
        ...gradientPresets.map((gradient) => _buildBgOption(onTap: () => setState(() { _useAlbumArt = false; _background = gradient; }), isActive: !_useAlbumArt && _background == gradient, child: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle)))),
        ...solidColorPresets.map((color) => _buildBgOption(onTap: () => setState(() { _useAlbumArt = false; _background = color; }), isActive: !_useAlbumArt && _background == color, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle)))),
        _buildBgOption(onTap: () => _showColorPicker(), isActive: !_useAlbumArt && _background is Color && !solidColorPresets.contains(_background), child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.red, Colors.yellow, Colors.blue])), child: const Icon(Icons.color_lens_outlined, color: Colors.white))),
        _buildBgOption(onTap: () => _showColorPicker(isText: true), isActive: false, child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: Icon(Icons.format_color_text, color: _textColor == Colors.white ? Colors.black : _textColor))),
      ]),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required VoidCallback onTap, bool isActive = false}) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).textTheme.bodySmall?.color;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: isActive ? activeColor : inactiveColor), const SizedBox(height: 4), Text(label, style: TextStyle(color: isActive ? activeColor : inactiveColor, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal))])));
  }

  Widget _buildBgOption({required VoidCallback onTap, required Widget child, bool isActive = false}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade600, width: isActive ? 2.5 : 1.0)), child: child));
  }
}

class _WordSelectorDialog extends StatefulWidget {
  final String lyrics;
  const _WordSelectorDialog({required this.lyrics});

  @override
  State<_WordSelectorDialog> createState() => _WordSelectorDialogState();
}

class _WordSelectorDialogState extends State<_WordSelectorDialog> {
  late List<String> _words;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _words = widget.lyrics.split(RegExp(r'(?<=\s)'));
  }

  void _onWordTap(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _onDone() {
    List<int> sortedIndices = _selectedIndices.toList()..sort();
    String result = sortedIndices.map((index) => _words[index]).join();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Tap to Select Words'),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Wrap(spacing: 0.0, runSpacing: 6.0, children: List.generate(_words.length, (index) { if (_words[index].trim().isEmpty) { return Text(_words[index]); } final isSelected = _selectedIndices.contains(index); return InkWell(onTap: () => _onWordTap(index), borderRadius: BorderRadius.circular(4), child: Container(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), decoration: BoxDecoration(color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent, borderRadius: BorderRadius.circular(4)), child: Text(_words[index], style: TextStyle(color: isSelected ? theme.colorScheme.onPrimaryContainer : null)))); })))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _onDone, child: const Text('Done')),
      ],
    );
  }
}