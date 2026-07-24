import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/setlist_model.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'share_image_preview_screen.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cached_image.dart';
import 'package:share_plus/share_plus.dart';

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
  double _imageScale = 1.0;

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    songProvider.addToHistory(widget.song);
    songProvider.incrementViewCount(widget.song.id);

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final offset = _scrollController.offset;
    final shouldShowTitle = offset > 250;
    final newScale = offset < 0 ? (1.0 - (offset / 300)) : 1.0;

    if (shouldShowTitle != _showAppBarTitle || (newScale - _imageScale).abs() > 0.01) {
      setState(() {
        _showAppBarTitle = shouldShowTitle;
        _imageScale = newScale;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _showShareOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                ),
                Text('Share Lyrics', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildShareOption(context, icon: Icons.text_fields_rounded, label: 'Share as Text', color: theme.colorScheme.primary, onTap: () {
                        Navigator.pop(context);
                        final shareText = '${widget.song.title} by ${widget.song.artistName}\n\n${widget.song.lyrics}';
                        Share.share(shareText);
                      }),
                      _buildShareOption(context, icon: Icons.image_outlined, label: 'Share as Image', color: theme.colorScheme.secondary, onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ShareImagePreviewScreen(song: widget.song, albumCoverUrl: widget.albumCoverUrl ?? '')));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            margin: EdgeInsets.all(context.w(16)),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(context.w(24)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  Padding(padding: const EdgeInsets.all(16.0), child: Text('Add to Setlist', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                  if (setlistProvider.setlists.isEmpty)
                    const Padding(padding: EdgeInsets.all(24.0), child: Text("No setlists found."))
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: setlistProvider.setlists.length,
                        itemBuilder: (context, index) {
                          final setlist = setlistProvider.setlists[index];
                          return ListTile(
                            leading: const Icon(Icons.playlist_play_rounded),
                            title: Text(setlist.name),
                            onTap: () {
                              setlistProvider.addSongToSetlist(setlist.id!, widget.song.id);
                              Navigator.pop(modalCtx);
                              CustomSnackbar.show(context, 'Added "${widget.song.title}" to "${setlist.name}"');
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: const Text('Create New Setlist'),
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create Setlist',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return _CreateSetlistDialog(
          onCreate: (name) async {
            final setlistProvider = Provider.of<SetlistProvider>(context, listen: false);
            final setlistId = await setlistProvider.createSetlist(name);
            setlistProvider.addSongToSetlist(setlistId, widget.song.id);

            if (mounted) {
              CustomSnackbar.show(context, 'Setlist created and song added!');
            }
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1.drive(Tween(begin: 0.9, end: 1.0)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildShareOption(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  void _showFontSizeSettings(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                    ),
                    Text('Adjust Lyrics Font Size', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('A', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: theme.colorScheme.primary,
                              inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.2),
                              thumbColor: theme.colorScheme.primary,
                              overlayColor: theme.colorScheme.primary.withOpacity(0.1),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: themeProvider.lyricsFontSize,
                              min: 12.0,
                              max: 28.0,
                              divisions: 16,
                              label: themeProvider.lyricsFontSize.round().toString(),
                              onChanged: (double value) {
                                themeProvider.setLyricsFontSize(value);
                              },
                            ),
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final song = widget.song;
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    Widget coverImage = CachedImage(
      imageUrl: widget.albumCoverUrl ?? '',
      errorWidget: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [theme.colorScheme.primary.withOpacity(0.5), theme.colorScheme.secondary.withOpacity(0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Icon(Icons.music_note, size: 80, color: Colors.white.withOpacity(0.8)),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: mediaQuery.size.height * 0.45,
                pinned: true,
                stretch: true,
                backgroundColor: _showAppBarTitle ? theme.scaffoldBackgroundColor.withOpacity(0.85) : Colors.transparent,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: AnimatedOpacity(
                    opacity: _showAppBarTitle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(song.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  centerTitle: true,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: _imageScale,
                        alignment: Alignment.center,
                        child: widget.heroTag != null ? Hero(tag: widget.heroTag!, child: coverImage) : coverImage,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.9)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                shadows: [const Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black54)],
                              ),
                            ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2),
                            const SizedBox(height: 12),
                            Text(
                              song.artistName,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                shadows: [const Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54)],
                              ),
                            ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.2),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (song.scale != null && song.scale!.isNotEmpty)
                                  _buildChip(context, icon: Icons.music_note, label: 'Scale: ${song.scale}', color: Colors.white)
                                      .animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.2),
                                _ViewCountChip(viewCount: song.viewCount)
                                    .animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(begin: 0.2),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 150),
                  child: Text(
                    song.lyrics,
                    style: GoogleFonts.lora(
                      fontSize: themeProvider.lyricsFontSize,
                      height: 1.8,
                      letterSpacing: 0.2,
                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                    ),
                  ).animate().fadeIn(duration: 800.ms, delay: 600.ms),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildFloatingActionBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionBar(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Consumer<SongProvider>(
                builder: (context, songProvider, child) {
                  final isFavorite = songProvider.isFavorite(widget.song.id);
                  return _buildActionButton(
                    icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red.shade400 : theme.colorScheme.onSurface,
                    onTap: () => songProvider.toggleFavorite(widget.song.id),
                  );
                },
              ),
              _buildActionButton(icon: Icons.playlist_add_rounded, onTap: () => _showAddToSetlistDialog(context)),
              _buildActionButton(icon: Icons.text_fields_rounded, onTap: () => _showFontSizeSettings(context)),
              _buildActionButton(icon: Icons.share_outlined, onTap: () => _showShareOptions(context)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 800.ms).slideY(begin: 0.5);
  }

  Widget _buildActionButton({required IconData icon, VoidCallback? onTap, Color? color}) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color ?? theme.colorScheme.onSurface, size: 26),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: const CircleBorder(),
        foregroundColor: color ?? theme.colorScheme.onSurface,
        highlightColor: theme.colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  Widget _buildChip(BuildContext context, {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ViewCountChip extends StatelessWidget {
  final int viewCount;
  const _ViewCountChip({required this.viewCount});

  @override
  Widget build(BuildContext context) {
    final compactFormat = NumberFormat.compact().format(viewCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            compactFormat,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CreateSetlistDialog extends StatefulWidget {
  final Function(String) onCreate;
  const _CreateSetlistDialog({required this.onCreate});

  @override
  State<_CreateSetlistDialog> createState() => _CreateSetlistDialogState();
}

class _CreateSetlistDialogState extends State<_CreateSetlistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onCreate(_controller.text.trim());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create New Setlist', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _controller,
                  decoration: InputDecoration(labelText: 'Setlist Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value!.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _submit, child: const Text('Create')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}