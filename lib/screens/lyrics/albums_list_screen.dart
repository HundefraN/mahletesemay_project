import 'dart:ui';
import 'package:mahlete_semay_project/screens/lyrics/songs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../providers/song_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_sizer.dart';
import '../../widgets/cached_image.dart';

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

class _AlbumsListScreenState extends State<AlbumsListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  List<Album> _albumsToDisplay = [];

  @override
  void initState() {
    super.initState();
    _setupAlbums();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _scrollController.addListener(() {
      if (_scrollController.offset > 100 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 100 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupAlbums() {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    _albumsToDisplay = songProvider.getAlbumsByArtist(widget.artist.id);

    final artistSingles = songProvider.allSongs.where((song) =>
    song.artistId == widget.artist.id && song.albumId == singlesAlbumId).toList();

    if (artistSingles.isNotEmpty) {
      final singlesAlbum = Album(
        id: singlesAlbumId,
        title: "Singles",
        artistId: widget.artist.id,
        artistName: widget.artist.name,
        coverImageUrl: '',
      );
      _albumsToDisplay.insert(0, singlesAlbum);
    }
  }

  @override
  void didUpdateWidget(covariant AlbumsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artist.id != oldWidget.artist.id) {
      _setupAlbums();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 720;

    if (isTablet) {
      return _buildTabletContent(songProvider, theme);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(theme),
          _buildAlbumGrid(songProvider),
        ],
      ),
    );
  }

  Widget _buildTabletContent(SongProvider songProvider, ThemeData theme) {
    return Column(
      children: [
        _buildTabletHeader(theme),
        Expanded(child: _buildAlbumGrid(songProvider)),
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
            tag: widget.artistHeroTag,
            child: CachedImage(
              imageUrl: widget.artist.imageUrl,
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
                  widget.artist.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.sp(28),
                    fontWeight: FontWeight.w900,
                    shadows: const [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black54)],
                  ),
                ),
                SizedBox(height: context.w(8)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.w(6)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(context.w(20)),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_albumsToDisplay.length} Release${_albumsToDisplay.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.white, fontSize: context.sp(14), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: context.w(300),
      pinned: true,
      stretch: true,
      backgroundColor: _isScrolled ? theme.colorScheme.surface.withOpacity(0.9) : Colors.transparent,
      elevation: _isScrolled ? 2 : 0,
      leading: Container(
        margin: EdgeInsets.all(context.w(8)),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: context.w(20)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: context.w(60), right: context.w(60), bottom: context.w(20)),
        title: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.artist.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: context.sp(18),
              shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black26)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                    theme.colorScheme.primary.withOpacity(0.8),
                    theme.colorScheme.secondary.withOpacity(0.6),
                    theme.colorScheme.tertiary.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            Positioned(
              top: context.w(100),
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      Hero(
                        tag: widget.artistHeroTag,
                        child: Container(
                          width: context.w(120),
                          height: context.w(120),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                          ),
                          child: ClipOval(
                            child: CachedImage(
                              imageUrl: widget.artist.imageUrl,
                              errorWidget: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                                ),
                                child: Icon(Icons.person_rounded, size: context.w(60), color: Colors.white.withOpacity(0.8)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: context.w(16)),
                      Text(
                        widget.artist.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.sp(24),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: const [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black54)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.w(8)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.w(6)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(context.w(20)),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${_albumsToDisplay.length} Release${_albumsToDisplay.length == 1 ? '' : 's'}',
                          style: TextStyle(color: Colors.white, fontSize: context.sp(14), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(SongProvider songProvider) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(context.w(20), context.w(32), context.w(20), context.w(100)),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: context.w(16),
          mainAxisSpacing: context.w(20),
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final album = _albumsToDisplay[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildAlbumCard(context, album, songProvider),
              ),
            );
          },
          childCount: _albumsToDisplay.length,
        ),
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album, SongProvider songProvider) {
    final theme = Theme.of(context);
    final albumHeroTag = 'album-${album.id}';
    final isSinglesAlbum = album.id == singlesAlbumId;

    final songsInAlbum = isSinglesAlbum
        ? songProvider.allSongs.where((s) => s.artistId == album.artistId && s.albumId == singlesAlbumId).toList()
        : songProvider.getSongsByAlbum(album.id);

    final totalViews = songsInAlbum.fold<int>(0, (sum, song) => sum + song.viewCount);

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 600),
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.w(20))),
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedBuilder: (context, openContainer) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.w(20)),
            boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openContainer,
              borderRadius: BorderRadius.circular(context.w(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: albumHeroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.w(20)),
                      child: CachedImage(
                        imageUrl: album.coverImageUrl,
                        errorWidget: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [theme.colorScheme.primary.withOpacity(0.6), theme.colorScheme.secondary.withOpacity(0.4)],
                            ),
                          ),
                          child: Icon(
                            isSinglesAlbum ? Icons.music_note : Icons.album_rounded,
                            size: context.w(64),
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.w(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.8)],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: context.w(16),
                    left: context.w(16),
                    right: context.w(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: context.sp(16),
                            letterSpacing: -0.3,
                            shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.w(6)),
                        _AlbumMetadataRow(album: album, songCount: songsInAlbum.length, totalViews: totalViews, fontSize: context.sp(12))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      openBuilder: (context, _) => SongsListScreen(album: album, albumHeroTag: albumHeroTag),
    );
  }
}

class _AlbumMetadataRow extends StatelessWidget {
  const _AlbumMetadataRow({
    required this.album,
    required this.songCount,
    required this.totalViews,
    required this.fontSize,
  });

  final Album album;
  final int songCount;
  final int totalViews;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final compactFormat = NumberFormat.compact().format(totalViews);

    String yearAndVol = '';
    if (album.volume != null) yearAndVol += 'Vol ${album.volume}';
    if (album.year != null) {
      if (yearAndVol.isNotEmpty) yearAndVol += ' • ';
      yearAndVol += '${album.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$songCount ${songCount == 1 ? 'song' : 'songs'}',
          style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        if(yearAndVol.isNotEmpty || totalViews > 0)
          SizedBox(height: fontSize * 0.3),
        Row(
          children: [
            if(yearAndVol.isNotEmpty)
              Text(
                yearAndVol,
                style: TextStyle(color: Colors.white70, fontSize: fontSize, fontWeight: FontWeight.w500),
              ),
            if (yearAndVol.isNotEmpty && totalViews > 0)
              Text(
                ' • ',
                style: TextStyle(color: Colors.white70, fontSize: fontSize, fontWeight: FontWeight.w500),
              ),
            if (totalViews > 0) ...[
              Icon(Icons.visibility_outlined, size: fontSize + 2, color: Colors.white.withOpacity(0.8)),
              SizedBox(width: fontSize * 0.3),
              Text(
                compactFormat,
                style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600),
              )
            ]
          ],
        ),
      ],
    );
  }
}