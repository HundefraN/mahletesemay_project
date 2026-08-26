import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'song_detail_screen.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../../models/album_model.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {


  @override
  void dispose() {
    super.dispose();
  }

  String _getCoverUrlForSong(Song song, SongProvider songProvider) {
    if (song.albumId == singlesAlbumId) {
      if (song.artistId != singlesArtistId) {
        final artist = songProvider.artists.firstWhere((a) => a.id == song.artistId, orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''));
        return artist.imageUrl;
      }
      return '';
    } else {
      final album = songProvider.allAlbums.firstWhere((a) => a.id == song.albumId, orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: ''));
      return album.coverImageUrl;
    }
  }

  Widget _getCoverForSong(BuildContext context, Song song, SongProvider songProvider) {
    final theme = Theme.of(context);
    final coverUrl = _getCoverUrlForSong(song, songProvider);

    if (coverUrl.isNotEmpty) {
      return CachedImage(imageUrl: coverUrl);
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.5),
              theme.colorScheme.secondary.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(Icons.music_note, color: Colors.white.withOpacity(0.8)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Consumer<SongProvider>(
        builder: (context, songProvider, child) {
          final favoriteSongs = songProvider.favoriteSongs;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                stretch: true,
                backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('My Favorites', style: TextStyle(fontWeight: FontWeight.bold)),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.6),
                          Colors.transparent,
                          theme.colorScheme.surface.withOpacity(0.2),
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (favoriteSongs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final song = favoriteSongs[index];
                        final coverUrl = _getCoverUrlForSong(song, songProvider);
                        final heroTag = 'favorite-${song.id}';

                        return OpenContainer(
                          transitionType: ContainerTransitionType.fadeThrough,
                          closedElevation: 0,
                          openElevation: 0,
                          closedColor: Colors.transparent,
                          openColor: Colors.transparent,
                          openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: coverUrl),
                          closedBuilder: (context, openContainer) {
                            return _buildSongCard(context, song, heroTag, coverUrl, openContainer);
                          },
                        ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.2);
                      },
                      childCount: favoriteSongs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildSongCard(BuildContext context, Song song, String heroTag, String coverUrl, VoidCallback openContainer) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surface.withOpacity(0.2),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openContainer,
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Hero(
                        tag: heroTag,
                        child: _getCoverForSong(context, song, songProvider),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Hero(
                              tag: 'song-title-${song.id}',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _SongMetadataRow(song: song, fontSize: 13),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
              ),
              child: Icon(
                Icons.favorite_border,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Favorites Yet',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on any song to add it to your favorites.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 600.ms),
      ),
    );
  }
}

class _SongMetadataRow extends StatelessWidget {
  const _SongMetadataRow({
    required this.song,
    required this.fontSize,
  });

  final Song song;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactFormat = NumberFormat.compact().format(song.viewCount);

    return Row(
      children: [
        Expanded(
          child: Text(
            song.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        if (song.viewCount > 0) ...[
          const SizedBox(width: 8),
          Icon(Icons.visibility_outlined, size: fontSize + 2, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            compactFormat,
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ]
      ],
    );
  }
}
