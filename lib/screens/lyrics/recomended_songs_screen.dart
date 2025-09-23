import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'song_detail_screen.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';

enum SongSortType { popularity, title, artist, date }
enum SortOrder { ascending, descending }

class RecommendedSongsScreen extends StatefulWidget {
  const RecommendedSongsScreen({super.key});

  @override
  State<RecommendedSongsScreen> createState() => _RecommendedSongsScreenState();
}

class _RecommendedSongsScreenState extends State<RecommendedSongsScreen>
    with TickerProviderStateMixin {
  late List<Song> _allRecommendedSongs;
  late List<Song> _displayedSongs;
  SongSortType _sortType = SongSortType.popularity;
  SortOrder _sortOrder = SortOrder.descending;
  bool _isInitialized = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeAndSortSongs();
      _isInitialized = true;
    }
  }

  void _initializeAndSortSongs() {
    _allRecommendedSongs = Provider.of<SongProvider>(context, listen: false).getPersonalizedRecommendations();
    _sortSongs();
    _fadeController.forward();
    _slideController.forward();
  }

  void _sortSongs() {
    List<Song> sorted = List.from(_allRecommendedSongs);

    sorted.sort((a, b) {
      int comparison;
      switch (_sortType) {
        case SongSortType.title:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case SongSortType.artist:
          comparison = a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase());
          break;
        case SongSortType.date:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SongSortType.popularity:
        default:
          comparison = a.viewCount.compareTo(b.viewCount);
          break;
      }
      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    setState(() {
      _displayedSongs = sorted;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _getCoverUrlForSong(Song song, SongProvider songProvider) {
    if (song.albumId == singlesAlbumId) {
      if (song.artistId != singlesArtistId) {
        final artist = songProvider.artists.firstWhere((a) => a.id == song.artistId, orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''));
        return artist.imageUrl;
      }
      return '';
    } else {
      final album = songProvider.allAlbums.firstWhere((a) => a.id == song.albumId, orElse: () => Album(id: '', title: '', artistId: '', artistName: '', coverImageUrl: ''));
      return album.coverImageUrl;
    }
  }

  Widget _getCoverForSong(Song song, SongProvider songProvider) {
    final theme = Theme.of(context);
    final coverUrl = _getCoverUrlForSong(song, songProvider);

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
        child: Icon(Icons.music_note, color: Colors.white.withOpacity(0.8)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final theme = Theme.of(context);
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart));
    final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            actions: [
              _buildSortMenu(),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: FadeTransition(
                opacity: fadeAnimation,
                child: Text(
                  'Recommended For You',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
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
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final song = _displayedSongs[index];
                  final heroTag = 'recommended-list-${song.id}';
                  final coverUrl = _getCoverUrlForSong(song, songProvider);

                  return SlideTransition(
                    position: slideAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: 16,
                          top: index == 0 ? 24 : 0,
                        ),
                        child: _buildSongCard(context, song, coverUrl, heroTag, index),
                      ),
                    ),
                  );
                },
                childCount: _displayedSongs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<dynamic>(
      icon: const Icon(Icons.sort_rounded),
      onSelected: (value) {
        if (value is SongSortType) {
          setState(() => _sortType = value);
        } else if (value is SortOrder) {
          setState(() => _sortOrder = value);
        }
        _sortSongs();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(enabled: false, child: Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold))),
        CheckedPopupMenuItem(
          value: SongSortType.popularity,
          checked: _sortType == SongSortType.popularity,
          child: const Text('Popularity'),
        ),
        CheckedPopupMenuItem(
          value: SongSortType.title,
          checked: _sortType == SongSortType.title,
          child: const Text('Title'),
        ),
        CheckedPopupMenuItem(
          value: SongSortType.artist,
          checked: _sortType == SongSortType.artist,
          child: const Text('Artist'),
        ),
        CheckedPopupMenuItem(
          value: SongSortType.date,
          checked: _sortType == SongSortType.date,
          child: const Text('Date Added'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(enabled: false, child: Text('Order', style: TextStyle(fontWeight: FontWeight.bold))),
        CheckedPopupMenuItem(
          value: SortOrder.descending,
          checked: _sortOrder == SortOrder.descending,
          child: const Text('Descending'),
        ),
        CheckedPopupMenuItem(
          value: SortOrder.ascending,
          checked: _sortOrder == SortOrder.ascending,
          child: const Text('Ascending'),
        ),
      ],
    );
  }

  Widget _buildSongCard(BuildContext context, Song song, String coverUrl, String heroTag, int index) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 500),
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      openBuilder: (context, _) => SongDetailScreen(
        song: song,
        heroTag: heroTag,
        albumCoverUrl: coverUrl,
      ),
      closedBuilder: (context, openContainer) {
        return Container(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceVariant.withOpacity(0.5),
                theme.colorScheme.surfaceVariant.withOpacity(0.2),
              ],
            ),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1), width: 1),
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
              onTap: openContainer,
              borderRadius: BorderRadius.circular(20),
              splashColor: theme.colorScheme.primary.withOpacity(0.1),
              highlightColor: theme.colorScheme.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _getCoverForSong(song, songProvider)
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            song.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          _SongMetadataRow(song: song, fontSize: 13),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        Expanded(
          child: Text(
            song.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        if (song.viewCount > 0) ...[
          const SizedBox(width: 8),
          Icon(Icons.visibility_outlined, size: fontSize + 1, color: theme.colorScheme.onSurface.withOpacity(0.5)),
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