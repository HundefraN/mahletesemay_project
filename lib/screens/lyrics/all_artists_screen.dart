import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/search_result_model.dart';
import 'package:mahlete_semay_project/providers/song_provider.dart';
import 'package:mahlete_semay_project/services/search_service.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:mahlete_semay_project/widgets/text_highlighter.dart';
import 'albums_list_screen.dart';

class AllArtistsScreen extends StatefulWidget {
  final String title;
  final String region;

  const AllArtistsScreen({
    super.key,
    required this.title,
    required this.region,
  });

  @override
  State<AllArtistsScreen> createState() => _AllArtistsScreenState();
}

class _AllArtistsScreenState extends State<AllArtistsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text != _searchQuery) {
        setState(() {
          _searchQuery = text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allArtists = songProvider.getRecommendedArtists(region: widget.region);
    
    // Multi-script professional search
    final filteredArtists = SearchService().filterArtists(
      query: _searchQuery,
      artists: allArtists,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern Frosted Sliver App Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                          theme.colorScheme.secondary.withOpacity(isDark ? 0.1 : 0.04),
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -30,
                    right: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isGridView ? IconsaxPlusBold.row_vertical : IconsaxPlusBold.grid_1,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                tooltip: _isGridView
                    ? (AppLocalizations.of(context)?.switchToList ?? 'Switch to list view')
                    : (AppLocalizations.of(context)?.switchToGrid ?? 'Switch to grid view'),
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Search & Filter Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface.withOpacity(0.6)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.searchArtistsHint ?? 'Search artists in English, Amharic or Afaan Oromoo...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 13.5,
                        ),
                        prefixIcon: Icon(
                          IconsaxPlusLinear.search_normal_1,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${filteredArtists.length} ${AppLocalizations.of(context)?.artists ?? 'Artists'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Artist Items: Grid or List
          if (filteredArtists.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                        child: Icon(
                          IconsaxPlusBold.user_search,
                          size: 44,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? (AppLocalizations.of(context)?.noArtistsFound ?? 'No artists match your search')
                            : (AppLocalizations.of(context)?.noArtistsFound ?? 'No artists found in this category'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isGridView)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final artist = filteredArtists[index];
                    return _ArtistGridCard(
                      artist: artist,
                      searchQuery: _searchQuery,
                    );
                  },
                  childCount: filteredArtists.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final artist = filteredArtists[index];
                    return _ArtistListTile(
                      artist: artist,
                      searchQuery: _searchQuery,
                    );
                  },
                  childCount: filteredArtists.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistListTile extends StatelessWidget {
  final Artist artist;
  final String searchQuery;
  const _ArtistListTile({
    required this.artist,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final isDark = theme.brightness == Brightness.dark;

    final albums = songProvider.getAlbumsByArtist(artist.id);
    final songs = songProvider.allSongs.where((s) => s.artistId == artist.id).toList();
    final totalViews = songs.fold<int>(0, (sum, song) => sum + song.viewCount);
    final compactViews = NumberFormat.compact().format(totalViews);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(isDark ? 0.06 : 0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumsListScreen(
                  artist: artist,
                  artistHeroTag: 'all_${artist.id}',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'all_${artist.id}',
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedImage(
                        imageUrl: artist.imageUrl,
                        memCacheWidth: 150,
                        memCacheHeight: 150,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (searchQuery.isNotEmpty)
                        Hero(
                          tag: 'artist-name-all_${artist.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: TextHighlighter(
                              text: artist.name,
                              query: searchQuery,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      else
                        Hero(
                          tag: 'artist-name-all_${artist.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              artist.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${albums.length} ${albums.length == 1 ? (AppLocalizations.of(context)?.albumSingular ?? 'Album') : (AppLocalizations.of(context)?.albumsPlural ?? 'Albums')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          if (songs.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${songs.length} ${songs.length == 1 ? (AppLocalizations.of(context)?.trackSingular ?? 'Track') : (AppLocalizations.of(context)?.tracksPlural ?? 'Tracks')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (totalViews > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              IconsaxPlusLinear.eye,
                              size: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$compactViews ${AppLocalizations.of(context)?.views ?? "Views"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.08),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistGridCard extends StatelessWidget {
  final Artist artist;
  final String searchQuery;
  const _ArtistGridCard({
    required this.artist,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final isDark = theme.brightness == Brightness.dark;

    final albums = songProvider.getAlbumsByArtist(artist.id);
    final songs = songProvider.allSongs.where((s) => s.artistId == artist.id).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(isDark ? 0.06 : 0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumsListScreen(
                  artist: artist,
                  artistHeroTag: 'grid_${artist.id}',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'grid_${artist.id}',
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedImage(
                        imageUrl: artist.imageUrl,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (searchQuery.isNotEmpty)
                  Hero(
                    tag: 'artist-name-grid_${artist.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: TextHighlighter(
                        text: artist.name,
                        query: searchQuery,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Hero(
                    tag: 'artist-name-grid_${artist.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        artist.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${albums.length} ${albums.length == 1 ? (AppLocalizations.of(context)?.albumSingular ?? 'Album') : (AppLocalizations.of(context)?.albumsPlural ?? 'Albums')} • ${songs.length} ${AppLocalizations.of(context)?.tracksPlural ?? 'Tracks'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}