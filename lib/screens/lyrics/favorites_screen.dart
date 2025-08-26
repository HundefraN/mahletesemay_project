import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import ' song_detail_screen.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Consumer<SongProvider>(
        builder: (context, songProvider, child) {
          final favoriteSongs = songProvider.favoriteSongs;

          if (favoriteSongs.isEmpty) {
            return _buildEmptyState(context);
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                pinned: true,
                stretch: true,
                backgroundColor: theme.colorScheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('My Favorites'),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.8),
                          theme.colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final song = favoriteSongs[index];
                    final album = songProvider.allAlbums.firstWhere(
                          (a) => a.id == song.albumId,
                      orElse: () => Album(id: '', title: 'Unknown Album', artistId: '', artistName: '', coverImageUrl: '', year: 0, volume: 1),
                    );
                    final heroTag = 'favorite-${song.id}';

                    return OpenContainer(
                      transitionType: ContainerTransitionType.fadeThrough,
                      closedElevation: 0,
                      openElevation: 0,
                      closedColor: Colors.transparent,
                      openColor: Colors.transparent,
                      openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: album.coverImageUrl),
                      closedBuilder: (context, openContainer) {
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: openContainer,
                            child: SizedBox(
                              height: 100,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Hero(
                                      tag: heroTag,
                                      child: CachedImage(imageUrl: album.coverImageUrl),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(song.artistName, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Icon(Icons.play_arrow_rounded, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: favoriteSongs.length,
                ),
              ),
            ],
          );
        },
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
            Icon(
              Icons.favorite_border,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
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
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}