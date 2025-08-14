import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
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
                backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
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
                      child: album.coverImageUrl.isNotEmpty
                          ? Image.network(album.coverImageUrl, fit: BoxFit.cover)
                          : Container(color: Colors.grey, child: const Icon(Icons.album, size: 60, color: Colors.white)),
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
                        Text(album.year.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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