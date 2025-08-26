import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/lyrics/recomended_songs_screen.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/history_entry_model.dart';
import 'package:mahlete_semay_project/models/search_result_model.dart';
import 'package:mahlete_semay_project/screens/lyrics/all_artists_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/favorites_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/history_screen.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:mahlete_semay_project/widgets/text_highlighter.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import ' song_detail_screen.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import 'albums_list_screen.dart';

class ArtistsListScreen extends StatefulWidget {
  const ArtistsListScreen({super.key});

  @override
  State<ArtistsListScreen> createState() => _ArtistsListScreenState();
}

class _ArtistsListScreenState extends State<ArtistsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
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
    final Map<String, SearchResult> resultsMap = {};

    if (_filterType == 'All' || _filterType == 'Songs') {
      for (var song in songProvider.allSongs) {
        final lyricsLower = song.lyrics.toLowerCase();
        if (lyricsLower.contains(queryLower)) {
          final matchIndex = lyricsLower.indexOf(queryLower);
          final start = (matchIndex - 20).clamp(0, lyricsLower.length);
          final end = (matchIndex + queryLower.length + 30).clamp(0, lyricsLower.length);
          String snippet = song.lyrics.substring(start, end);
          if (start > 0) snippet = '...$snippet';
          if (end < lyricsLower.length) snippet = '$snippet...';

          resultsMap[song.id] = SearchResult(item: song, matchType: MatchType.lyric, matchSnippet: snippet.replaceAll('\n', ' '));
        }
      }
    }
    if (_filterType == 'All' || _filterType == 'Artists') {
      for (var artist in songProvider.artists) {
        if (artist.name.toLowerCase().contains(queryLower)) {
          resultsMap[artist.id] = SearchResult(item: artist, matchType: MatchType.artist);
        }
      }
    }
    if (_filterType == 'All' || _filterType == 'Albums') {
      for (var album in songProvider.allAlbums) {
        if (album.title.toLowerCase().contains(queryLower)) {
          resultsMap[album.id] = SearchResult(item: album, matchType: MatchType.album);
        }
      }
    }
    if (_filterType == 'All' || _filterType == 'Songs') {
      for (var song in songProvider.allSongs) {
        if (song.title.toLowerCase().contains(queryLower)) {
          resultsMap[song.id] = SearchResult(item: song, matchType: MatchType.title, matchSnippet: song.artistName);
        }
      }
    }
    setState(() {
      _searchQuery = query;
      _searchResults = resultsMap.values.toList();
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

  String getGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  Widget _buildUpdateBanner(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: songProvider.hasNewDataOnMobile ? 50 : 0,
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.system_update_alt_rounded,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'New content is available',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      CustomSnackbar.show(context, 'Syncing new content...');
                      await songProvider.forceSyncOnMobileData();
                      if (mounted) {
                        CustomSnackbar.show(context, 'Content updated!');
                      }
                    },
                    child: const Text('Download Now'),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
      body: Column(
        children: [
          _buildUpdateBanner(context),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120.0,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    title: Text(
                      getGreeting(context),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    centerTitle: false,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.favorite_outline),
                      tooltip: l10n.favorites,
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
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
                              hintText: l10n.searchHint,
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
                    l10n.recommendedForYou,
                    action: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendedSongsScreen())),
                      child: Text(l10n.seeAll),
                    ),
                  ),
                  _buildRecommendedGrid(context, songProvider.getRecommendedSongs(count: 4)),
                  _buildSectionHeader(
                    context,
                    l10n.ethiopianArtists,
                    action: recommendedEthiopian.length > 7 ? TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllArtistsScreen(title: l10n.ethiopianArtists, region: 'Ethiopian'))),
                      child: Text(l10n.seeAll),
                    ) : null,
                  ),
                  _buildArtistCarousel(context, recommendedEthiopian.take(7).toList()),
                  _buildSectionHeader(
                    context,
                    l10n.worldwideArtists,
                    action: recommendedWorldwide.length > 7 ? TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllArtistsScreen(title: l10n.worldwideArtists, region: 'Worldwide'))),
                      child: Text(l10n.seeAll),
                    ) : null,
                  ),
                  _buildArtistCarousel(context, recommendedWorldwide.take(7).toList()),
                  if (songProvider.history.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      l10n.history,
                      action: songProvider.history.length > 7 ? TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                        child: Text(l10n.viewAll),
                      ) : null,
                    ),
                    _buildHistoryCarousel(context, songProvider.history.take(8).toList()),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView(BuildContext context) {
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
          final result = _searchResults[index];
          if (result.item is Song) {
            return _buildSongResultTile(context, result);
          }
          if (result.item is Artist) {
            return _buildArtistResultTile(context, result.item);
          }
          if (result.item is Album) {
            return _buildAlbumResultTile(context, result.item);
          }
          return const SizedBox.shrink();
        },
        childCount: _searchResults.length,
      ),
    );
  }

  Widget _buildSongResultTile(BuildContext context, SearchResult result) {
    final theme = Theme.of(context);
    final song = result.item as Song;
    final album = Provider.of<SongProvider>(context, listen: false).allAlbums.firstWhere(
            (a) => a.id == song.albumId,
        orElse: () => Album(id: '', title: 'Unknown Album', artistId: '', artistName: '', coverImageUrl: '', volume: 1));
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
              child: ClipOval(child: CachedImage(imageUrl: album.coverImageUrl)),
            ),
          ),
          title: TextHighlighter(
            text: song.title,
            query: _searchQuery,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: result.matchType == MatchType.lyric
              ? TextHighlighter(text: result.matchSnippet!, query: _searchQuery, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))
              : Text('Song • ${song.artistName}', style: theme.textTheme.bodySmall),
        );
      },
    );
  }

  Widget _buildArtistResultTile(BuildContext context, Artist artist) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlbumsListScreen(artist: artist, albums: songProvider.getAlbumsByArtist(artist.id), artistHeroTag: artist.id,))),
      leading: Hero(
        tag: artist.id,
        child: CircleAvatar(
          child: ClipOval(child: CachedImage(imageUrl: artist.imageUrl)),
        ),
      ),
      title: TextHighlighter(
        text: artist.name,
        query: _searchQuery,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Artist • ${artist.region}', style: theme.textTheme.bodySmall),
    );
  }

  Widget _buildAlbumResultTile(BuildContext context, Album album) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final artist = songProvider.artists.firstWhere((a) => a.id == album.artistId,
        orElse: () => Artist(id: '', name: 'Unknown Artist', imageUrl: '', region: ''));
    final heroTag = 'search-album-${album.id}';
    final songCount = songProvider.getSongsByAlbum(album.id).length;
    final songCountText = '$songCount ${songCount == 1 ? 'song' : 'songs'}';

    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlbumsListScreen(artist: artist, albums: [album], artistHeroTag: artist.id))),
      leading: Hero(
        tag: heroTag,
        child: CircleAvatar(
          child: ClipOval(child: CachedImage(imageUrl: album.coverImageUrl)),
        ),
      ),
      title: TextHighlighter(
        text: album.title,
        query: _searchQuery,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: TextHighlighter(
        text: 'Album • $songCountText',
        query: _searchQuery,
        style: theme.textTheme.bodySmall,
      ),
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
                orElse: () => Album(id: '', title: 'Unknown Album', artistId: '', artistName: '', coverImageUrl: '', year: 0, volume: 1));
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
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  child: CachedImage(imageUrl: imageUrl),
                ),
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
                          child: ClipOval(child: CachedImage(imageUrl: artist.imageUrl)),
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

  Widget _buildHistoryCarousel(BuildContext context, List<HistoryEntry> history) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final historyEntry = history[index];
            final song = songProvider.allSongs.firstWhere(
                  (s) => s.id == historyEntry.songId,
              orElse: () => Song(id: '', title: 'Not Found', artistName: '', artistId: '', albumId: '', albumTitle: '', lyrics: '', viewCount: 0, createdAt: Timestamp.now()),
            );
            if (song.title == 'Not Found') return const SizedBox.shrink();

            final album = songProvider.allAlbums.firstWhere(
                    (a) => a.id == song.albumId,
                orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: '', year: 0, volume: 1));
            final heroTag = 'history-carousel-${song.id}';

            return SizedBox(
              width: 120,
              child: OpenContainer(
                transitionType: ContainerTransitionType.fade,
                closedElevation: 0, openElevation: 0,
                closedColor: Colors.transparent, openColor: Colors.transparent,
                openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: album.coverImageUrl),
                closedBuilder: (context, openContainer) {
                  return Card(
                    color: Colors.transparent,
                    elevation: 0,
                    child: InkWell(
                      onTap: openContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 100,
                            width: 120,
                            child: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedImage(imageUrl: album.coverImageUrl),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}