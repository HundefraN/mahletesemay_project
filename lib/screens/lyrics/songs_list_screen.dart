import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import ' song_detail_screen.dart';
import '../../models/album_model.dart';
import '../../providers/song_provider.dart';

class SongsListScreen extends StatelessWidget {
  final Album album;
  final String albumHeroTag;
  const SongsListScreen({super.key, required this.album, required this.albumHeroTag});

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);
    final songsInAlbum = songProvider.getSongsByAlbum(album.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(album.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Hero(
                tag: albumHeroTag,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    album.coverImageUrl.isNotEmpty
                        ? Image.network(album.coverImageUrl, fit: BoxFit.cover)
                        : Container(color: theme.colorScheme.primary),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          songsInAlbum.isEmpty
              ? SliverFillRemaining(child: Center(child: Text("No songs found in this album.", style: theme.textTheme.bodyMedium)))
              : SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final song = songsInAlbum[index];
                final songHeroTag = 'song-list-${song.id}';
                return OpenContainer(
                  transitionType: ContainerTransitionType.fade,
                  closedElevation: 0,
                  openElevation: 0,
                  closedColor: Colors.transparent,
                  openColor: Colors.transparent,
                  openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: songHeroTag, albumCoverUrl: album.coverImageUrl),
                  closedBuilder: (context, openContainer) {
                    return ListTile(
                      onTap: openContainer,
                      leading: Hero(
                        tag: songHeroTag,
                        child: CircleAvatar(
                          backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
                          child: album.coverImageUrl.isEmpty ? Text('${index + 1}') : null,
                        ),
                      ),
                      title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Track ${index + 1}'),
                      trailing: Consumer<SongProvider>(
                        builder: (context, provider, child) {
                          return IconButton(
                            icon: Icon(
                              provider.isFavorite(song.id) ? Icons.favorite : Icons.favorite_border,
                              color: provider.isFavorite(song.id) ? Colors.red.shade400 : theme.colorScheme.primary,
                            ),
                            onPressed: () => provider.toggleFavorite(song.id),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              childCount: songsInAlbum.length,
            ),
          ),
        ],
      ),
    );
  }
}