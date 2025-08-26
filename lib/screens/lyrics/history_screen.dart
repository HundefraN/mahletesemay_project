import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import ' song_detail_screen.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
                        orElse: () => Song(id: '', title: 'Not Found', artistName: '', artistId: '', albumId: '', albumTitle: '', lyrics: '', viewCount: 0, createdAt: Timestamp.now()),
                      );

                      if (song.title == 'Not Found') return const SizedBox.shrink();

                      final album = songProvider.allAlbums.firstWhere(
                            (a) => a.id == song.albumId,
                        orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: '', year: 0, volume: 1),
                      );
                      final heroTag = 'history-list-${song.id}';

                      return OpenContainer(
                        transitionType: ContainerTransitionType.fade,
                        closedElevation: 0, openElevation: 0,
                        closedColor: Colors.transparent, openColor: Colors.transparent,
                        openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: album.coverImageUrl),
                        closedBuilder: (context, openContainer) {
                          return ListTile(
                            onTap: openContainer,
                            leading: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(width: 50, height: 50, child: CachedImage(imageUrl: album.coverImageUrl)),
                              ),
                            ),
                            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(song.artistName),
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