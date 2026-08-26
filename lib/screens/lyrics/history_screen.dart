import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'song_detail_screen.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
      body: Consumer<SongProvider>(
        builder: (context, songProvider, child) {
          final history = songProvider.history;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Viewing History'),
                backgroundColor: theme.scaffoldBackgroundColor,
                pinned: true,
                elevation: 0,
              ),
              if (history.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('Your recently viewed songs will appear here.', style: theme.textTheme.bodyMedium),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final historyEntry = history[index];
                      final song = songProvider.allSongs.firstWhere(
                            (s) => s.id == historyEntry.songId,
                        orElse: () => Song(id: '', title: 'Not Found', artistName: '', artistId: '', albumId: '', albumTitle: '', lyrics: '', viewCount: 0, createdAt: DateTime.now()),
                      );

                      if (song.title == 'Not Found') return const SizedBox.shrink();

                      final coverUrl = _getCoverUrlForSong(song, songProvider);
                      final heroTag = 'history-list-${song.id}';

                      return OpenContainer(
                        transitionType: ContainerTransitionType.fade,
                        closedElevation: 0, openElevation: 0,
                        closedColor: Colors.transparent, openColor: Colors.transparent,
                        openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: coverUrl),
                        closedBuilder: (context, openContainer) {
                          return ListTile(
                            onTap: openContainer,
                            leading: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(width: 50, height: 50, child: _getCoverForSong(context, song, songProvider)),
                              ),
                            ),
                            title: Hero(
                              tag: 'song-title-${song.id}',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            subtitle: _SongMetadataRow(song: song, fontSize: 13),
                            trailing: Text(
                              timeago.format(historyEntry.viewedAt),
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      );
                    },
                    childCount: history.length,
                  ),
                ),
            ],
          );
        },
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          song.artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (song.viewCount > 0) ...[
          Text(
            ' • ',
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Icon(Icons.visibility_outlined, size: fontSize + 1, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 3),
          Text(
            compactFormat,
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ]
      ],
    );
  }
}