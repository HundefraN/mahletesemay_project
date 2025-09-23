import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/providers/song_provider.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
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

class _AllArtistsScreenState extends State<AllArtistsScreen>
    with TickerProviderStateMixin {
  late List<Artist> _allArtistsInRegion;
  List<Artist> _filteredArtists = [];
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    _allArtistsInRegion = songProvider.getRecommendedArtists(region: widget.region);
    _filteredArtists = _allArtistsInRegion;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _searchController.addListener(_filterArtists);

    _fadeController.forward();
    _slideController.forward();
  }

  void _filterArtists() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredArtists = _allArtistsInRegion.where((artist) {
        return artist.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            expandedHeight: context.w(200),
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: context.sp(24),
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ).createShader(Rect.fromLTWH(0.0, 0.0, context.w(200), context.w(70))),
                  ),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                      theme.colorScheme.secondaryContainer.withOpacity(0.2),
                      theme.colorScheme.surface,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: context.w(200),
                        height: context.w(200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(context.w(20), 0, context.w(20), context.w(24)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.w(20)),
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for an artist...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        suffixIcon: _isSearching
                            ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.w(20),
                          vertical: context.w(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(context.w(20), 0, context.w(20), context.w(100)),
            sliver: _filteredArtists.isEmpty
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSearching ? Icons.search_off_rounded : Icons.person_off_rounded,
                      size: context.w(64),
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    SizedBox(height: context.w(16)),
                    Text(
                      _isSearching
                          ? 'No artists found matching "${_searchController.text}"'
                          : 'No artists available in this region',
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: context.sp(16)
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final artist = _filteredArtists[index];

                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: context.w(12)),
                        child: _buildArtistCard(context, artist, songProvider),
                      ),
                    ),
                  );
                },
                childCount: _filteredArtists.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistCard(
      BuildContext context,
      Artist artist,
      SongProvider songProvider,
      ) {
    final theme = Theme.of(context);
    final albums = songProvider.getAlbumsByArtist(artist.id);
    final songs = songProvider.allSongs.where((s) => s.artistId == artist.id).toList();
    final totalViews = songs.fold<int>(0, (sum, song) => sum + song.viewCount);

    return Container(
      height: context.w(80),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.w(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceVariant.withOpacity(0.5),
            theme.colorScheme.surfaceVariant.withOpacity(0.2),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    AlbumsListScreen(
                      artist: artist,
                      artistHeroTag: artist.id,
                    ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.3, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
          borderRadius: BorderRadius.circular(context.w(20)),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(context.w(16)),
            child: Row(
              children: [
                Hero(
                  tag: artist.id,
                  child: Container(
                    width: context.w(48),
                    height: context.w(48),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedImage(
                        imageUrl: artist.imageUrl,
                        errorWidget: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.3),
                                theme.colorScheme.secondary.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            size: context.w(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.w(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        artist.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            fontSize: context.sp(15)
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _ArtistMetadataRow(
                        albumCount: albums.length,
                        totalViews: totalViews,
                        fontSize: context.sp(12),
                      )
                    ],
                  ),
                ),
                Container(
                  width: context.w(32),
                  height: context.w(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: context.w(14),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }}

class _ArtistMetadataRow extends StatelessWidget {
  const _ArtistMetadataRow({
    required this.albumCount,
    required this.totalViews,
    required this.fontSize,
  });

  final int albumCount;
  final int totalViews;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactFormat = NumberFormat.compact().format(totalViews);

    return Row(
      children: [
        Text(
          '$albumCount ${albumCount == 1 ? 'album' : 'albums'}',
          style: TextStyle(
            fontSize: fontSize,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (totalViews > 0) ...[
          Text(
            ' • ',
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Icon(Icons.visibility_outlined, size: fontSize + 2, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
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