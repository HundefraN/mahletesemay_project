import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import ' song_detail_screen.dart';
import '../../models/album_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';

class RecommendedSongsScreen extends StatefulWidget {
  const RecommendedSongsScreen({super.key});

  @override
  State<RecommendedSongsScreen> createState() => _RecommendedSongsScreenState();
}

class _RecommendedSongsScreenState extends State<RecommendedSongsScreen> {
  final ScrollController _scrollController = ScrollController();
  late List<Song> _allRecommendedSongs;
  final List<Song> _displayedSongs = [];
  final int _batchSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _allRecommendedSongs = Provider.of<SongProvider>(context, listen: false).getRecommendedSongs(count: 1000);
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    });
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      final currentLength = _displayedSongs.length;
      final moreSongs = _allRecommendedSongs.skip(currentLength).take(_batchSize).toList();

      if (mounted) {
        if (moreSongs.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _displayedSongs.addAll(moreSongs);
            _isLoadingMore = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended For You'),
      ),
      body: _displayedSongs.isEmpty && _isLoadingMore
          ? ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) => const ListTileShimmer(),
      )
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12.0),
        itemCount: _displayedSongs.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedSongs.length) {
            return const ListTileShimmer();
          }

          final song = _displayedSongs[index];
          final album = songProvider.allAlbums.firstWhere(
                (a) => a.id == song.albumId,
            orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: '', year: 0),
          );
          final heroTag = 'recommended-list-${song.id}';

          return OpenContainer(
            transitionType: ContainerTransitionType.fade,
            closedElevation: 0,
            openElevation: 0,
            closedColor: Colors.transparent,
            openColor: Colors.transparent,
            openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: album.coverImageUrl),
            closedBuilder: (context, openContainer) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: openContainer,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Hero(
                          tag: heroTag,
                          child: album.coverImageUrl.isNotEmpty
                              ? Image.network(album.coverImageUrl, fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade300, child: const Icon(Icons.music_note, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
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
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(Icons.play_arrow, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}