import 'dart:ui';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../providers/song_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/cached_image.dart';
import 'songs_list_screen.dart';

class AlbumsListScreen extends StatefulWidget {
  final Artist artist;
  final String artistHeroTag;

  const AlbumsListScreen({
    super.key,
    required this.artist,
    required this.artistHeroTag,
  });

  @override
  State<AlbumsListScreen> createState() => _AlbumsListScreenState();
}

class _AlbumsListScreenState extends State<AlbumsListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled =
        _scrollController.hasClients && _scrollController.offset > 120;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<Album> _getAlbums(SongProvider songProvider) {
    final artistAlbums = songProvider.getAlbumsByArtist(widget.artist.id);
    final artistSingles = songProvider.allSongs
        .where(
          (song) =>
              song.artistId == widget.artist.id &&
              song.albumId == singlesAlbumId,
        )
        .toList();

    final List<Album> list = List.from(artistAlbums);
    if (artistSingles.isNotEmpty) {
      final singlesAlbum = Album(
        id: singlesAlbumId,
        title: AppLocalizations.of(context)?.singlesAndStandalone ??
            "Singles & Standalone",
        artistId: widget.artist.id,
        artistName: widget.artist.name,
        coverImageUrl: '',
      );
      list.insert(0, singlesAlbum);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 720;
    final isDark = theme.brightness == Brightness.dark;

    final albums = _getAlbums(songProvider);
    final allArtistSongs = songProvider.allSongs
        .where((s) => s.artistId == widget.artist.id)
        .toList();
    final totalViews =
        allArtistSongs.fold<int>(0, (sum, s) => sum + s.viewCount);

    if (isTablet) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildTabletHeader(
                theme, totalViews, allArtistSongs.length, albums),
            Expanded(
                child: _buildAlbumGrid(songProvider, theme, isDark, albums)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(theme, totalViews, allArtistSongs.length, albums),
          _buildAlbumGrid(songProvider, theme, isDark, albums),
        ],
      ),
    );
  }

  Widget _buildTabletHeader(
      ThemeData theme, int totalViews, int totalSongs, List<Album> albums) {
    final compactViews = NumberFormat.compact().format(totalViews);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.06))),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CachedImage(
                imageUrl: widget.artist.imageUrl,
                memCacheWidth: 600,
                memCacheHeight: 300,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Hero(
                  tag: widget.artistHeroTag,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedImage(
                        imageUrl: widget.artist.imageUrl,
                        memCacheWidth: 250,
                        memCacheHeight: 250,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'artist-name-${widget.artistHeroTag}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            widget.artist.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBadge(theme, '${albums.length} Releases'),
                          const SizedBox(width: 8),
                          _buildBadge(theme, '$totalSongs Tracks'),
                          if (totalViews > 0) ...[
                            const SizedBox(width: 8),
                            _buildBadge(theme, '$compactViews ${AppLocalizations.of(context)?.views ?? "Views"}',
                                icon: IconsaxPlusLinear.eye),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
      ThemeData theme, int totalViews, int totalSongs, List<Album> albums) {
    final compactViews = NumberFormat.compact().format(totalViews);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: _isScrolled
          ? theme.scaffoldBackgroundColor.withOpacity(0.9)
          : Colors.transparent,
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, right: 20, bottom: 16),
        title: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.artist.name,
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
            // Ambient Backdrop Image with Blur
            CachedImage(
              imageUrl: widget.artist.imageUrl,
              memCacheWidth: 600,
              memCacheHeight: 400,
              fit: BoxFit.cover,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                      theme.scaffoldBackgroundColor,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Artist Center Details
            Positioned(
              top: 70,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Hero(
                    tag: widget.artistHeroTag,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedImage(
                          imageUrl: widget.artist.imageUrl,
                          memCacheWidth: 250,
                          memCacheHeight: 250,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Hero(
                    tag: 'artist-name-${widget.artistHeroTag}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        widget.artist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 6,
                                color: Colors.black54),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildWhiteBadge(
                          '${albums.length} ${albums.length == 1 ? (AppLocalizations.of(context)?.albumSingular ?? 'Album') : (AppLocalizations.of(context)?.albumsPlural ?? 'Albums')}'),
                      const SizedBox(width: 8),
                      _buildWhiteBadge(
                          '$totalSongs ${AppLocalizations.of(context)?.tracksPlural ?? 'Tracks'}'),
                      if (totalViews > 0) ...[
                        const SizedBox(width: 8),
                        _buildWhiteBadge('$compactViews ${AppLocalizations.of(context)?.views ?? "Views"}',
                            icon: IconsaxPlusLinear.eye),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(SongProvider songProvider, ThemeData theme,
      bool isDark, List<Album> albums) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 16,
          mainAxisSpacing: 18,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = albums[index];
            return _buildVinylAlbumCard(
                context, album, songProvider, theme, isDark);
          },
          childCount: albums.length,
        ),
      ),
    );
  }

  Widget _buildVinylAlbumCard(
    BuildContext context,
    Album album,
    SongProvider songProvider,
    ThemeData theme,
    bool isDark,
  ) {
    final albumHeroTag = 'album-${album.id}';
    final isSinglesAlbum = album.id == singlesAlbumId;

    final songsInAlbum = isSinglesAlbum
        ? songProvider.allSongs
            .where((s) =>
                s.artistId == album.artistId && s.albumId == singlesAlbumId)
            .toList()
        : songProvider.getSongsByAlbum(album.id);

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 450),
      closedElevation: 0,
      openElevation: 0,
      closedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedBuilder: (context, openContainer) {
        return InkWell(
          onTap: openContainer,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Elevated Album Card Artwork
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Hero(
                        tag: albumHeroTag,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(isDark ? 0.1 : 0.06),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.35 : 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: isSinglesAlbum
                                ? Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.secondary,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        IconsaxPlusBold.music,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : CachedImage(
                                    imageUrl: album.coverImageUrl,
                                    memCacheWidth: 350,
                                    memCacheHeight: 350,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    // Standalone Release Badge if applicable
                    if (isSinglesAlbum)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Singles',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Album Title & Meta
              Hero(
                tag: 'album-title-${album.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    album.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '${songsInAlbum.length} ${songsInAlbum.length == 1 ? (AppLocalizations.of(context)?.trackSingular ?? 'track') : (AppLocalizations.of(context)?.tracksPlural ?? 'tracks')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  if (album.year != null) ...[
                    Text(
                      ' • ${album.year}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
      openBuilder: (context, _) =>
          SongsListScreen(album: album, albumHeroTag: albumHeroTag),
    );
  }

  Widget _buildBadge(ThemeData theme, String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteBadge(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
