import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/providers/song_provider.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:provider/provider.dart';
import '../../models/artist_model.dart';
import '../../models/album_model.dart';
import 'songs_list_screen.dart';

class AlbumsListScreen extends StatelessWidget {
  final Artist artist;
  final List<Album> albums;
  final String artistHeroTag;
  const AlbumsListScreen({super.key, required this.artist, required this.albums, required this.artistHeroTag});

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Hero(
              tag: artistHeroTag,
              child: CircleAvatar(
                radius: 18,
                child: ClipOval(child: CachedImage(imageUrl: artist.imageUrl)),
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          final albumHeroTag = 'album-${album.id}';
          final songCount = songProvider.getSongsByAlbum(album.id).length;
          final songCountText = '$songCount ${songCount == 1 ? 'song' : 'songs'}';

          String subtitle = '';
          if (album.volume != null) subtitle += 'Vol ${album.volume}';
          if (album.year != null) {
            if (subtitle.isNotEmpty) subtitle += ' • ';
            subtitle += '${album.year}';
          }

          return OpenContainer(
            transitionType: ContainerTransitionType.fadeThrough,
            transitionDuration: const Duration(milliseconds: 500),
            closedElevation: 5,
            closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            closedBuilder: (context, openContainer) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: albumHeroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CachedImage(imageUrl: album.coverImageUrl),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          songCountText,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if(subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ]
                      ],
                    ),
                  )
                ],
              );
            },
            openBuilder: (context, _) => SongsListScreen(album: album, albumHeroTag: albumHeroTag),
          );
        },
      ),
    );
  }
}