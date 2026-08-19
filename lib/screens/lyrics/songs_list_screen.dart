import 'dart:ui';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/cached_image.dart';
import 'song_detail_screen.dart';

class SongsListScreen extends StatefulWidget {
  final Album album;
  final String albumHeroTag;

  const SongsListScreen({
    super.key,
    required this.album,
    required this.albumHeroTag,
  });

  @override
  State<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends State<SongsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isScrolled = false;
  String _searchQuery = '';
  List<Song> _allSongs = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  void _onScroll() {
    final scrolled = _scrollController.hasClients && _scrollController.offset > 140;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  void _loadSongs() {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final isSinglesAlbum = widget.album.id == singlesAlbumId;
    _allSongs = isSinglesAlbum
        ? songProvider.allSongs
            .where((s) =>
                (s.artistId == widget.album.artistId || s.artistId == singlesArtistId) &&
                s.albumId == singlesAlbumId)
            .toList()
        : songProvider.getSongsByAlbum(widget.album.id);
  }

  @override
  void didUpdateWidget(covariant SongsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.album.id != oldWidget.album.id) {
      _loadSongs();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getCoverUrlForSong(Song song, SongProvider songProvider) {
    if (song.albumId == singlesAlbumId) {
      if (song.artistId != singlesArtistId) {
        final artist = songProvider.artists.firstWhere(
          (a) => a.id == song.artistId,
          orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''),
        );
        return artist.imageUrl;
      }
      return '';
    }
    return widget.album.coverImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 720;
    final isDark = theme.brightness == Brightness.dark;

    final filteredSongs = _searchQuery.isEmpty
        ? _allSongs
        : _allSongs.where((s) => s.title.toLowerCase().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(theme, isDark),
          _buildSearchBar(theme, isDark),
          _buildSongList(filteredSongs, songProvider, theme, isDark, isTablet),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(ThemeData theme, bool isDark) {
    final isSinglesAlbum = widget.album.id == singlesAlbumId;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: _isScrolled ? theme.scaffoldBackgroundColor.withOpacity(0.92) : Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, right: 20, bottom: 16),
        title: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.album.title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Artwork
            if (!isSinglesAlbum && widget.album.coverImageUrl.isNotEmpty)
              CachedImage(
                imageUrl: widget.album.coverImageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                memCacheHeight: 400,
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

            // Ambient Blur & Gradient
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.6),
                      theme.scaffoldBackgroundColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Artwork & Info Center
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Hero(
                    tag: widget.albumHeroTag,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isSinglesAlbum
                            ? Container(
                                color: theme.colorScheme.primary,
                                child: const Center(
                                  child: Icon(IconsaxPlusBold.music, size: 48, color: Colors.white),
                                ),
                              )
                            : CachedImage(
                                imageUrl: widget.album.coverImageUrl,
                                memCacheWidth: 300,
                                memCacheHeight: 300,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(offset: Offset(0, 2), blurRadius: 6, color: Colors.black54),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.album.artistName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${_allSongs.length} ${_allSongs.length == 1 ? 'Track' : 'Tracks'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSearchBar(ThemeData theme, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? theme.cardColor.withOpacity(0.5) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.06),
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search tracks in this album...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.45),
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                IconsaxPlusLinear.search_normal_1,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(
    List<Song> songs,
    SongProvider songProvider,
    ThemeData theme,
    bool isDark,
    bool isTablet,
  ) {
    if (songs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                IconsaxPlusBold.music_filter,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No tracks match "$_searchQuery"'
                    : 'No songs available in this album',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songs[index];
            final songHeroTag = 'song-${song.id}';
            final coverUrl = _getCoverUrlForSong(song, songProvider);

            return _SongTile(
              song: song,
              index: index + 1,
              coverUrl: coverUrl,
              heroTag: songHeroTag,
              isDark: isDark,
            );
          },
          childCount: songs.length,
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final String coverUrl;
  final String heroTag;
  final bool isDark;

  const _SongTile({
    required this.song,
    required this.index,
    required this.coverUrl,
    required this.heroTag,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context);
    final isFavorite = songProvider.isFavorite(song.id);
    final compactViews = NumberFormat.compact().format(song.viewCount);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withOpacity(0.35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(isDark ? 0.05 : 0.04),
        ),
      ),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 400),
        closedElevation: 0,
        openElevation: 0,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        closedColor: Colors.transparent,
        openColor: Colors.transparent,
        openBuilder: (context, _) => SongDetailScreen(
          song: song,
          heroTag: heroTag,
          albumCoverUrl: coverUrl,
        ),
        closedBuilder: (context, openContainer) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: openContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Track Index Number
                  Container(
                    width: 28,
                    alignment: Alignment.center,
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Small Song Avatar
                  Hero(
                    tag: heroTag,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedImage(
                          imageUrl: coverUrl,
                          memCacheWidth: 150,
                          memCacheHeight: 150,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Song Title & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (song.scale != null && song.scale!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  song.scale!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (song.rhythm != null && song.rhythm!.isNotEmpty) ...[
                              Text(
                                song.rhythm!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (song.viewCount > 0) ...[
                              Icon(
                                IconsaxPlusLinear.eye,
                                size: 12,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                compactViews,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Favorite Button
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.redAccent : theme.colorScheme.onSurface.withOpacity(0.35),
                      size: 20,
                    ),
                    onPressed: () => songProvider.toggleFavorite(song.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
