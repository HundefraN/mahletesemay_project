import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/album_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../../providers/theme_provider.dart';
import 'share_image_preview_screen.dart';

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
  late Album album;
  late String coverUrl;

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    songProvider.addToHistory(widget.song); // ADD THIS LINE
    songProvider.incrementViewCount(widget.song.id);
    album = songProvider.allAlbums.firstWhere(
          (a) => a.id == widget.song.albumId,
      orElse: () => Album(id: '', title: 'Unknown Album', artistId: '', artistName: '', coverImageUrl: '', year: 0, volume: 1),
    );
    coverUrl = widget.albumCoverUrl ?? album.coverImageUrl;
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share Lyrics', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Share as Text'),
                onTap: () {
                  Navigator.pop(context);
                  final shareText = '${widget.song.title} by ${widget.song.artistName}\n\n${widget.song.lyrics}';
                  Share.share(shareText);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Share as Image'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareImagePreviewScreen(
                        song: widget.song,
                        albumCoverUrl: coverUrl,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Adjust Lyrics Font Size', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Slider(
                    value: themeProvider.lyricsFontSize,
                    min: 12.0,
                    max: 28.0,
                    divisions: 16,
                    label: themeProvider.lyricsFontSize.round().toString(),
                    onChanged: (double value) {
                      themeProvider.setLyricsFontSize(value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final song = widget.song;

    Widget coverImage = CachedImage(
      imageUrl: coverUrl,
      errorWidget: Container(color: theme.colorScheme.primary, child: const Icon(Icons.music_note, size: 80, color: Colors.white24)),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            stretch: true,
            backgroundColor: theme.colorScheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                song.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(left: 48, right: 48, bottom: 16),
              background: widget.heroTag != null
                  ? Hero(
                tag: widget.heroTag!,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverImage,
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : Stack(
                fit: StackFit.expand,
                children: [
                  coverImage,
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Consumer<SongProvider>(
                builder: (context, songProvider, child) {
                  return IconButton(
                    icon: Icon(
                      songProvider.isFavorite(song.id) ? Icons.favorite : Icons.favorite_border,
                      color: songProvider.isFavorite(song.id) ? Colors.red.shade400 : Colors.white,
                    ),
                    onPressed: () {
                      songProvider.toggleFavorite(song.id);
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                onPressed: () => _showFontSizeSettings(context),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _showShareOptions(context),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.artistName,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      Chip(
                        avatar: Icon(Icons.album, size: 18, color: theme.colorScheme.onSecondary),
                        label: Text(album.title),
                        backgroundColor: theme.colorScheme.secondary,
                        labelStyle: TextStyle(color: theme.colorScheme.onSecondary),
                      ),
                      if (song.scale != null && song.scale!.isNotEmpty)
                        Chip(
                          avatar: Icon(Icons.music_note, size: 18, color: theme.colorScheme.onPrimary),
                          label: Text('Scale: ${song.scale}'),
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
                          labelStyle: TextStyle(color: theme.colorScheme.onPrimary),
                        ),
                    ],
                  ),
                  const Divider(height: 40),
                  Text(
                    song.lyrics,
                    style: TextStyle(
                      fontSize: themeProvider.lyricsFontSize,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}