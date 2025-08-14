import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/screens/lyrics/recomended_songs_screen.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/screens/lyrics/all_artists_screen.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import ' song_detail_screen.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import 'albums_list_screen.dart';
import 'songs_list_screen.dart';

class ArtistsListScreen extends StatefulWidget {
  const ArtistsListScreen({super.key});

  @override
  State<ArtistsListScreen> createState() => _ArtistsListScreenState();
}

class _ArtistsListScreenState extends State<ArtistsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = query;
        _searchResults = [];
      });
      return;
    }

    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final queryLower = query.toLowerCase();
    List<dynamic> results = [];

    if (_filterType == 'All' || _filterType == 'Songs') {
      results.addAll(songProvider.allSongs.where((song) =>
      song.title.toLowerCase().contains(queryLower) ||
          song.lyrics.toLowerCase().contains(queryLower)));
    }
    if (_filterType == 'All' || _filterType == 'Artists') {
      results.addAll(songProvider.artists.where((artist) =>
          artist.name.toLowerCase().contains(queryLower)));
    }
    if (_filterType == 'All' || _filterType == 'Albums') {
      results.addAll(songProvider.allAlbums.where((album) =>
          album.title.toLowerCase().contains(queryLower)));
    }

    setState(() {
      _searchQuery = query;
      _searchResults = results.toSet().toList();
    });
  }

  void _showFilterSheet() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter Search', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildFilterOption(context, 'All', Icons.search),
              _buildFilterOption(context, 'Songs', Icons.music_note),
              _buildFilterOption(context, 'Artists', Icons.person),
              _buildFilterOption(context, 'Albums', Icons.album),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, String type, IconData icon) {
    return ListTile(
      title: Text(type),
      leading: Icon(icon),
      onTap: () {
        setState(() => _filterType = type);
        _onSearchChanged(_searchController.text);
        Navigator.pop(context);
      },
    );
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);

    if (songProvider.isLoading) {
      return const Scaffold(
        body: HomePageShimmer(),
      );
    }

    final recommendedEthiopian = songProvider.getRecommendedArtists(region: 'Ethiopian');
    final recommendedWorldwide = songProvider.getRecommendedArtists(region: 'Worldwide');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              title: Text(
                getGreeting(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              centerTitle: false,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search songs, artists, albums...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: _filterType != 'All' ? theme.colorScheme.secondary : theme.iconTheme.color,
                    ),
                    onPressed: _showFilterSheet,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            _buildSearchResultsView(context)
          else ...[
            _buildSectionHeader(
              context,
              'Recommended For You',
              action: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendedSongsScreen())),
                child: const Text('See All'),
              ),
            ),
            _buildRecommendedGrid(context, songProvider.getRecommendedSongs(count: 4)),
            _buildSectionHeader(
              context,
              'Ethiopian Artists',
              action: recommendedEthiopian.length > 7 ? TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllArtistsScreen(title: 'Ethiopian Artists', region: 'Ethiopian'))),
                child: const Text('See All'),
              ) : null,
            ),
            _buildArtistCarousel(context, recommendedEthiopian.take(7).toList()),
            _buildSectionHeader(
              context,
              'Worldwide Artists',
              action: recommendedWorldwide.length > 7 ? TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllArtistsScreen(title: 'Worldwide Artists', region: 'Worldwide'))),
                child: const Text('See All'),
              ) : null,
            ),
            _buildArtistCarousel(context, recommendedWorldwide.take(7).toList()),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchResultsView(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text('No results found for "$_searchQuery"'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = _searchResults[index];
          if (item is Song) {
            return _buildSongResultTile(context, item);
          }
          if (item is Artist) {
            return _buildArtistResultTile(context, item);
          }
          if (item is Album) {
            return _buildAlbumResultTile(context, item, songProvider);
          }
          return const SizedBox.shrink();
        },
        childCount: _searchResults.length,
      ),
    );
  }

  Widget _buildSongResultTile(BuildContext context, Song song) {
    final album = Provider.of<SongProvider>(context, listen: false).allAlbums.firstWhere(
            (a) => a.id == song.albumId,
        orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: '', year: 0));
    final heroTag = 'search-song-${song.id}';

    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: album.coverImageUrl),
      closedBuilder: (context, openContainer) {
        return ListTile(
          onTap: openContainer,
          leading: Hero(
            tag: heroTag,
            child: CircleAvatar(
              backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
              child: album.coverImageUrl.isEmpty ? const Icon(Icons.music_note) : null,
            ),
          ),
          title: Text(song.title),
          subtitle: Text('Song • ${song.artistName}'),
        );
      },
    );
  }

  Widget _buildArtistResultTile(BuildContext context, Artist artist) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlbumsListScreen(artist: artist, albums: songProvider.getAlbumsByArtist(artist.id), artistHeroTag: artist.id,))),
      leading: Hero(
        tag: artist.id,
        child: CircleAvatar(
          backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
          child: artist.imageUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
      ),
      title: Text(artist.name),
      subtitle: Text('Artist • ${artist.region}'),
    );
  }

  Widget _buildAlbumResultTile(BuildContext context, Album album, SongProvider songProvider) {
    final artist = songProvider.artists.firstWhere((a) => a.id == album.artistId,
        orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''));
    final heroTag = 'search-album-${album.id}';
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SongsListScreen(album: album, albumHeroTag: heroTag,))),
      leading: Hero(
        tag: heroTag,
        child: CircleAvatar(
          backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
          child: album.coverImageUrl.isEmpty ? const Icon(Icons.album) : null,
        ),
      ),
      title: Text(album.title),
      subtitle: Text('Album • ${album.artistName}'),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {Widget? action}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 24.0, bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedGrid(BuildContext context, List<Song> songs) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final song = songs[index];
            final album = Provider.of<SongProvider>(context, listen: false).allAlbums.firstWhere(
                    (a) => a.id == song.albumId,
                orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: '', year: 0));
            return _buildGridItemCard(context, song, album.coverImageUrl);
          },
          childCount: songs.length,
        ),
      ),
    );
  }

  Widget _buildGridItemCard(BuildContext context, Song song, String imageUrl) {
    final theme = Theme.of(context);
    final heroTag = 'recommended-${song.id}';
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      closedColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: imageUrl),
      closedBuilder: (context, openContainer) {
        return Row(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Hero(
                tag: heroTag,
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.music_note))
                    : Container(color: Colors.grey.shade300, child: const Icon(Icons.music_note)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                song.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtistCarousel(BuildContext context, List<Artist> artists) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 180,
        child: artists.isEmpty
            ? const Center(child: Text('No artists in this category.'))
            : ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumsListScreen(
                      artist: artist,
                      albums: songProvider.getAlbumsByArtist(artist.id),
                      artistHeroTag: artist.id,
                    ),
                  ),
                );
              },
              child: Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: Hero(
                        tag: artist.id,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                          onBackgroundImageError: (e, s) {},
                          child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 60) : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      artist.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}