import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song_model.dart';
import '../../providers/setlist_provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/responsive_sizer.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/custom_snackbar.dart';
import 'share_image_preview_screen.dart';

enum LyricsReadingTheme { glassDark, amoledBlack, warmSepia, softLight }

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
  bool _showAppBarTitle = false;

  // Auto-scroll state
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0; // 1x, 1.5x, 2x
  Timer? _autoScrollTimer;

  // Reading Mode State
  LyricsReadingTheme _readingTheme = LyricsReadingTheme.glassDark;
  String _selectedFontFamily = 'Poppins';
  double _lineHeight = 1.8;
  TextAlign _textAlign = TextAlign.left;

  // Selected lines for image share
  final Set<int> _selectedLineIndices = {};

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    songProvider.addToHistory(widget.song);
    songProvider.incrementViewCount(widget.song.id);

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShowTitle = _scrollController.hasClients && _scrollController.offset > 220;
    if (shouldShowTitle != _showAppBarTitle) {
      setState(() => _showAppBarTitle = shouldShowTitle);
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
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!_scrollController.hasClients || !_isAutoScrolling) {
        timer.cancel();
        return;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= maxScroll) {
        setState(() => _isAutoScrolling = false);
        timer.cancel();
        return;
      }
      _scrollController.jumpTo(currentScroll + (_scrollSpeed * 0.8));
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

  TextStyle _getLyricsTextStyle(double fontSize, Color textColor) {
    switch (_selectedFontFamily) {
      case 'Lora':
        return GoogleFonts.lora(fontSize: fontSize, height: _lineHeight, color: textColor);
      case 'Montserrat':
        return GoogleFonts.montserrat(fontSize: fontSize, height: _lineHeight, color: textColor);
      case 'Outfit':
        return GoogleFonts.outfit(fontSize: fontSize, height: _lineHeight, color: textColor);
      case 'Noto Serif Ethiopic':
        return GoogleFonts.notoSerifEthiopic(fontSize: fontSize, height: _lineHeight, color: textColor);
      default:
        return GoogleFonts.poppins(fontSize: fontSize, height: _lineHeight, color: textColor);
    }
  }

  void _showShareOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface.withOpacity(0.95) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Share Lyrics',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareActionTile(
                      context,
                      icon: IconsaxPlusBold.text,
                      label: 'Share as Text',
                      color: theme.colorScheme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        final shareText = '${widget.song.title} by ${widget.song.artistName}\n\n${widget.song.lyrics}\n\nShared via Mahlete Semay';
                        Share.share(shareText);
                      },
                    ),
                    _buildShareActionTile(
                      context,
                      icon: IconsaxPlusBold.gallery_export,
                      label: 'Share as Image',
                      color: theme.colorScheme.secondary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShareImagePreviewScreen(
                              song: widget.song,
                              albumCoverUrl: widget.albumCoverUrl ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLyricsAppearanceModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final themeProvider = Provider.of<ThemeProvider>(context);
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface.withOpacity(0.95) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Lyrics Customization',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),

                    // Reading Theme Selector
                    Text(
                      'Reading Theme',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildThemeOption(
                          label: 'Dark Glass',
                          color: const Color(0xFF1E1E2E),
                          isSelected: _readingTheme == LyricsReadingTheme.glassDark,
                          onTap: () {
                            setState(() => _readingTheme = LyricsReadingTheme.glassDark);
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          label: 'AMOLED',
                          color: Colors.black,
                          isSelected: _readingTheme == LyricsReadingTheme.amoledBlack,
                          onTap: () {
                            setState(() => _readingTheme = LyricsReadingTheme.amoledBlack);
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          label: 'Sepia',
                          color: const Color(0xFFF4ECD8),
                          textColor: const Color(0xFF4A3B2C),
                          isSelected: _readingTheme == LyricsReadingTheme.warmSepia,
                          onTap: () {
                            setState(() => _readingTheme = LyricsReadingTheme.warmSepia);
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          label: 'Light',
                          color: Colors.white,
                          textColor: Colors.black87,
                          isSelected: _readingTheme == LyricsReadingTheme.softLight,
                          onTap: () {
                            setState(() => _readingTheme = LyricsReadingTheme.softLight);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Font Family Selector
                    Text(
                      'Font Family',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Poppins', 'Lora', 'Montserrat', 'Outfit', 'Noto Serif Ethiopic'].map((font) {
                        final isSelected = _selectedFontFamily == font;
                        return ChoiceChip(
                          label: Text(font, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() => _selectedFontFamily = font);
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Font Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Font Size',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        Text(
                          '${themeProvider.lyricsFontSize.round()} pt',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    Slider(
                      value: themeProvider.lyricsFontSize,
                      min: 14.0,
                      max: 28.0,
                      divisions: 14,
                      onChanged: (val) {
                        themeProvider.setLyricsFontSize(val);
                        setModalState(() {});
                      },
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

  Widget _buildThemeOption({
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
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
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface.withOpacity(0.95) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Text('Add to Setlist', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (setlistProvider.setlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text("No setlists created yet."),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: setlistProvider.setlists.length,
                        itemBuilder: (context, index) {
                          final setlist = setlistProvider.setlists[index];
                          return ListTile(
                            leading: const Icon(IconsaxPlusBold.music_playlist),
                            title: Text(setlist.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () {
                              setlistProvider.addSongToSetlist(setlist.id!, widget.song.id);
                              Navigator.pop(modalCtx);
                              CustomSnackbar.show(context, 'Added "${widget.song.title}" to "${setlist.name}"');
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(height: 24),
                  ListTile(
                    leading: Icon(IconsaxPlusBold.add_circle, color: theme.colorScheme.primary),
                    title: Text('Create New Setlist', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Setlist', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Setlist Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final setlistProvider = Provider.of<SetlistProvider>(context, listen: false);
                  final setlistId = await setlistProvider.createSetlist(controller.text.trim());
                  setlistProvider.addSongToSetlist(setlistId, widget.song.id);
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  if (mounted) {
                    CustomSnackbar.show(context, 'Setlist created and song added!');
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    switch (_readingTheme) {
      case LyricsReadingTheme.amoledBlack:
        return Colors.black;
      case LyricsReadingTheme.warmSepia:
        return const Color(0xFFF4ECD8);
      case LyricsReadingTheme.softLight:
        return Colors.white;
      case LyricsReadingTheme.glassDark:
        return theme.scaffoldBackgroundColor;
    }
  }

  Color _getTextColor(ThemeData theme) {
    switch (_readingTheme) {
      case LyricsReadingTheme.amoledBlack:
        return Colors.white.withOpacity(0.92);
      case LyricsReadingTheme.warmSepia:
        return const Color(0xFF2C2219);
      case LyricsReadingTheme.softLight:
        return Colors.black87;
      case LyricsReadingTheme.glassDark:
        return theme.colorScheme.onSurface.withOpacity(0.95);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final bgColor = _getBackgroundColor(theme);
    final textColor = _getTextColor(theme);

    final lines = widget.song.lyrics.split('\n');

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero Parallax Album Bar
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                stretch: true,
                backgroundColor: _showAppBarTitle ? bgColor.withOpacity(0.92) : Colors.transparent,
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
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 56, right: 20, bottom: 16),
                  title: AnimatedOpacity(
                    opacity: _showAppBarTitle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      widget.song.title,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Backdrop artwork
                      if (widget.albumCoverUrl != null && widget.albumCoverUrl!.isNotEmpty)
                        CachedImage(
                          imageUrl: widget.albumCoverUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          memCacheHeight: 400,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                            ),
                          ),
                        ),

                      // Blur ambient
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.6),
                                bgColor,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Header Song Meta
                      Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                shadows: const [
                                  Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black54),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.song.artistName,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (widget.song.scale != null && widget.song.scale!.isNotEmpty)
                                  _buildTagChip('Scale: ${widget.song.scale!}'),
                                if (widget.song.rhythm != null && widget.song.rhythm!.isNotEmpty)
                                  _buildTagChip('Rhythm: ${widget.song.rhythm!}'),
                                _buildTagChip('${NumberFormat.compact().format(widget.song.viewCount)} views', icon: IconsaxPlusLinear.eye),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Lyrics Text Body with interactive tap
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < lines.length; i++)
                        _buildLyricLine(
                          lines[i],
                          i,
                          themeProvider.lyricsFontSize,
                          textColor,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating Frosted Glass Action Pill Bar
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildFloatingGlassBar(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricLine(String line, int index, double fontSize, Color textColor) {
    final isSelected = _selectedLineIndices.contains(index);

    if (line.trim().isEmpty) {
      return const SizedBox(height: 16);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLineIndices.remove(index);
          } else {
            _selectedLineIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          line,
          style: _getLyricsTextStyle(fontSize, textColor).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingGlassBar(BuildContext context, ThemeData theme) {
    final songProvider = Provider.of<SongProvider>(context);
    final isFavorite = songProvider.isFavorite(widget.song.id);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Favorite Button
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.redAccent : theme.colorScheme.onSurface,
                  size: 24,
                ),
                tooltip: 'Favorite',
                onPressed: () => songProvider.toggleFavorite(widget.song.id),
              ),

              // Auto-Scroll Karaoke Sing-along Toggle
              IconButton(
                icon: Icon(
                  _isAutoScrolling ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  color: _isAutoScrolling ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  size: 26,
                ),
                tooltip: _isAutoScrolling ? 'Pause auto-scroll' : 'Auto-scroll sing along',
                onPressed: _toggleAutoScroll,
              ),

              // Speed Pill (if auto-scrolling)
              if (_isAutoScrolling)
                GestureDetector(
                  onTap: _changeScrollSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_scrollSpeed}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),

              // Add to Setlist Button
              IconButton(
                icon: const Icon(IconsaxPlusBold.music_playlist, size: 22),
                tooltip: 'Add to Setlist',
                onPressed: () => _showAddToSetlistDialog(context),
              ),

              // Appearance & Font Settings
              IconButton(
                icon: const Icon(IconsaxPlusBold.text, size: 22),
                tooltip: 'Typography & Themes',
                onPressed: () => _showLyricsAppearanceModal(context),
              ),

              // Share Button
              IconButton(
                icon: const Icon(IconsaxPlusBold.send_2, size: 22),
                tooltip: 'Share',
                onPressed: () => _showShareOptions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}