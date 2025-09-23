import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'song_detail_screen.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_sizer.dart';
import '../../widgets/cached_image.dart';

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

class _SongsListScreenState extends State<SongsListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  double _imageScale = 1.0;
  List<Song> _songsInAlbum = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();

    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if (offset > 100 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (offset <= 100 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
      if (offset < 0) {
        setState(() {
          _imageScale = 1.0 - (offset / 250);
        });
      } else {
        setState(() {
          _imageScale = 1.0;
        });
      }
    });
  }

  void _loadSongs() {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final isSinglesAlbum = widget.album.id == singlesAlbumId;
    _songsInAlbum = isSinglesAlbum
        ? songProvider.allSongs
        .where((s) =>
    (s.artistId == widget.album.artistId ||
        s.artistId == singlesArtistId) &&
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
    _scrollController.dispose();
    super.dispose();
  }

  Widget _getCoverForSong(Song song, SongProvider songProvider) {
    final theme = Theme.of(context);
    String coverUrl = '';

    if (song.albumId == singlesAlbumId) {
      if (song.artistId != singlesArtistId) {
        final artist = songProvider.artists.firstWhere(
              (a) => a.id == song.artistId,
          orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''),
        );
        coverUrl = artist.imageUrl;
      }
    } else {
      final album = songProvider.allAlbums.firstWhere(
            (a) => a.id == song.albumId,
        orElse: () =>
            Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: ''),
      );
      coverUrl = album.coverImageUrl;
    }

    if (coverUrl.isNotEmpty) {
      return CachedImage(imageUrl: coverUrl);
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.5),
              theme.colorScheme.secondary.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(Icons.music_note,
            color: Colors.white.withOpacity(0.8), size: 28),
      );
    }
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
    } else {
      final album = songProvider.allAlbums.firstWhere(
            (a) => a.id == song.albumId,
        orElse: () =>
            Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: ''),
      );
      return album.coverImageUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 720;

    if (isTablet) {
      return _buildTabletContent(theme);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(theme),
          _buildSongList(),
        ],
      ),
    );
  }

  Widget _buildTabletContent(ThemeData theme) {
    return Column(
      children: [
        _buildTabletHeader(theme),
        Expanded(child: _buildSongList()),
      ],
    );
  }

  Widget _buildTabletHeader(ThemeData theme) {
    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: widget.albumHeroTag,
            child: CachedImage(
              imageUrl: widget.album.coverImageUrl,
              errorWidget: Container(color: theme.colorScheme.primary),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.album.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.sp(28),
                    fontWeight: FontWeight.w900,
                    shadows: const [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black54)],
                  ),
                ),
                SizedBox(height: context.w(8)),
                Text(
                  '${_songsInAlbum.length} Song${_songsInAlbum.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.white70, fontSize: context.sp(16), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(ThemeData theme) {
    final isSinglesAlbum = widget.album.id == singlesAlbumId;

    return SliverAppBar(
      expandedHeight: context.w(380),
      pinned: true,
      stretch: true,
      backgroundColor: _isScrolled
          ? theme.colorScheme.surface.withOpacity(0.95)
          : Colors.transparent,
      elevation: _isScrolled ? 4 : 0,
      leading: Padding(
        padding: EdgeInsets.all(context.w(8)),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.background.withOpacity(0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: context.w(20)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
            left: context.w(60),
            right: context.w(60),
            bottom: context.w(16)),
        title: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Text(
            widget.album.title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: context.sp(16)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: widget.albumHeroTag,
              child: Transform.scale(
                scale: _imageScale,
                alignment: Alignment.center,
                child: isSinglesAlbum
                    ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
                    : CachedImage(
                  imageUrl: widget.album.coverImageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.9)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: context.w(80),
              left: context.w(24),
              right: context.w(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: context.sp(34),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                            offset: Offset(0, 3),
                            blurRadius: 12,
                            color: Colors.black87)
                      ],
                    ),
                  ),
                  SizedBox(height: context.w(10)),
                  Row(
                    children: [
                      Text(
                        widget.album.artistName,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.w500,
                          shadows: [
                            const Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 6,
                                color: Colors.black54)
                          ],
                        ),
                      ),
                      SizedBox(width: context.w(10)),
                      Container(
                        width: context.w(4),
                        height: context.w(4),
                        decoration: const BoxDecoration(
                            color: Colors.white70, shape: BoxShape.circle),
                      ),
                      SizedBox(width: context.w(10)),
                      Text(
                        '${_songsInAlbum.length} ${_songsInAlbum.length == 1 ? 'song' : 'songs'}',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms)
                  .slideY(begin: 0.25, curve: Curves.easeOutCubic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList() {
    final isTablet = MediaQuery.of(context).size.width > 720;

    if (_songsInAlbum.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off_rounded, size: context.w(64), color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
              SizedBox(height: context.w(16)),
              Text(
                "No songs found in this album.",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: context.sp(16)),
              ),
            ],
          ),
        ),
      );
    }

    if (isTablet) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(context.w(20), context.w(24), context.w(20), context.w(100)),
        itemCount: _songsInAlbum.length,
        itemBuilder: (context, index) {
          final song = _songsInAlbum[index];
          final songHeroTag = 'song-list-${song.id}';
          return _buildSongTile(context, song, index, songHeroTag)
              .animate()
              .fadeIn(duration: 500.ms, delay: (100 * index).ms)
              .slideY(begin: 0.15, curve: Curves.easeOutCubic);
        },
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(context.w(20), context.w(24), context.w(20), context.w(100)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final song = _songsInAlbum[index];
            final songHeroTag = 'song-list-${song.id}';
            return _buildSongTile(context, song, index, songHeroTag)
                .animate()
                .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                .slideY(begin: 0.15, curve: Curves.easeOutCubic);
          },
          childCount: _songsInAlbum.length,
        ),
      ),
    );
  }

  Widget _buildSongTile(BuildContext context, Song song, int index, String songHeroTag) {
    final theme = Theme.of(context);
    final isSinglesAlbum = widget.album.id == singlesAlbumId;
    final songProvider = Provider.of<SongProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: context.w(12)),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 500),
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Colors.transparent,
        openBuilder: (context, _) => SongDetailScreen(
          song: song,
          heroTag: songHeroTag,
          albumCoverUrl: isSinglesAlbum
              ? _getCoverUrlForSong(song, songProvider)
              : widget.album.coverImageUrl,
        ),
        closedBuilder: (context, openContainer) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(context.w(16)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: context.w(72),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.w(16)),
                  color: theme.colorScheme.surface.withOpacity(0.25),
                  border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: openContainer,
                    borderRadius: BorderRadius.circular(context.w(16)),
                    splashColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                      child: Row(
                        children: [
                          Hero(
                            tag: songHeroTag,
                            child: Container(
                              width: context.w(52),
                              height: context.w(52),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [
                                  theme.colorScheme.primary.withOpacity(0.25),
                                  theme.colorScheme.secondary.withOpacity(0.25)
                                ]),
                                border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.4),
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                  )
                                ],
                              ),
                              child: ClipOval(
                                child: isSinglesAlbum
                                    ? _getCoverForSong(song, songProvider)
                                    : CachedImage(
                                    imageUrl: widget.album.coverImageUrl),
                              ),
                            ),
                          ),
                          SizedBox(width: context.w(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(song.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        fontSize: context.sp(15)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                _SongMetadataRow(
                                    song: song, fontSize: context.sp(12)),
                              ],
                            ),
                          ),
                          Consumer<SongProvider>(
                            builder: (context, provider, child) {
                              return Container(
                                width: context.w(40),
                                height: context.w(40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: provider.isFavorite(song.id)
                                      ? Colors.red.withOpacity(0.15)
                                      : theme.colorScheme.surfaceVariant
                                      .withOpacity(0.5),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    provider.isFavorite(song.id)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: provider.isFavorite(song.id)
                                        ? Colors.red.shade400
                                        : theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    size: context.w(20),
                                  ),
                                  onPressed: () =>
                                      provider.toggleFavorite(song.id),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SongMetadataRow extends StatelessWidget {
  const _SongMetadataRow({
    required this.song,
    required this.fontSize,
  });

  final Song song;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactFormat = NumberFormat.compact().format(song.viewCount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Track',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (song.viewCount > 0) ...[
          Text(
            ' • ',
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Icon(Icons.visibility_outlined,
              size: fontSize + 1,
              color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 3),
          Text(
            compactFormat,
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ]
      ],
    );
  }
}
