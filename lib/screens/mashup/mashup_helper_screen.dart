import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/search_result_model.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:mahlete_semay_project/widgets/text_highlighter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../lyrics/song_detail_screen.dart';

final GlobalKey<_MashupCategoryListState> mashupTab1Key =
    GlobalKey<_MashupCategoryListState>();
final GlobalKey<_MashupCategoryListState> mashupTab2Key =
    GlobalKey<_MashupCategoryListState>();

class MashupHelperScreen extends StatefulWidget {
  const MashupHelperScreen({super.key});

  @override
  State<MashupHelperScreen> createState() => _MashupHelperScreenState();
}

class _MashupHelperScreenState extends State<MashupHelperScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _searchAnimationController;
  late TutorialCoachMark tutorialCoachMark;

  GlobalKey searchKey = GlobalKey();
  GlobalKey scaleFilterKey = GlobalKey();
  GlobalKey rhythmFilterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkAndShowTutorial();
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTour =
        prefs.getBool('mashup_helper_tour_completed_v2') ?? false;
    if (!hasSeenTour && mounted) {
      _createTutorial();
      Future.delayed(const Duration(milliseconds: 500), _showTutorial);
    }
  }

  void _showTutorial() {
    tutorialCoachMark.show(context: context);
  }

  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Theme.of(context).colorScheme.primary.withOpacity(0.9),
      textSkip: "SKIP",
      onFinish: () {
        _completeTutorial();
        return true;
      },
      onSkip: () {
        _completeTutorial();
        return true;
      },
    );
  }

  void _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mashup_helper_tour_completed_v2', true);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "Scale Filter",
        keyTarget: scaleFilterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTutorialContent(
              "Filter by Scale",
              "First, press a scale like 'Tizita Minor' to see all songs in that musical key.",
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Rhythm Filter",
        keyTarget: rhythmFilterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTutorialContent(
              "Filter by Rhythm",
              "Then, press a rhythm like 'Waltz' to find songs that match both the key and the beat.",
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Search",
        keyTarget: searchKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTutorialContent(
              "Or, Search Directly",
              "Alternatively, press the search icon to find any song by its title, artist, or lyrics.",
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTutorialContent(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_tabController.index == 0) {
      mashupTab1Key.currentState?.toggleSearch();
    } else {
      mashupTab2Key.currentState?.toggleSearch();
    }
  }

  Map<String, Map<String, List<Song>>> _groupSongs(List<Song> songs) {
    final Map<String, Map<String, List<Song>>> grouped = {};
    for (var song in songs) {
      if (song.scale != null &&
          song.scale!.isNotEmpty &&
          song.rhythm != null &&
          song.rhythm!.isNotEmpty) {
        grouped.putIfAbsent(song.scale!, () => {});
        grouped[song.scale!]!.putIfAbsent(song.rhythm!, () => []);
        grouped[song.scale!]![song.rhythm!]!.add(song);
      }
    }
    return grouped;
  }

  List<Song> _sortSongsByRecommendation(List<Song> songsToSort) {
    if (songsToSort.isEmpty) return [];

    double maxViews = songsToSort
        .map((s) => s.viewCount)
        .fold(0, (max, current) => current > max ? current : max)
        .toDouble();
    if (maxViews == 0) maxViews = 1.0;

    List<({Song song, double score})> scoredSongs = [];
    for (var song in songsToSort) {
      final daysAgo = DateTime.now().difference(song.createdAt.toDate()).inDays;
      final recencyScore = 1.0 / (daysAgo + 1.0);
      final popularityScore = song.viewCount / maxViews;
      
      // Bonus score for songs with specified Scale & Rhythm which enable seamless mashups
      double mashupMetaDataBonus = 0.0;
      if (song.scale != null && song.scale!.isNotEmpty) mashupMetaDataBonus += 0.25;
      if (song.rhythm != null && song.rhythm!.isNotEmpty) mashupMetaDataBonus += 0.25;

      final totalScore = (popularityScore * 0.5) + (recencyScore * 0.25) + (mashupMetaDataBonus * 0.25);
      scoredSongs.add((song: song, score: totalScore));
    }

    scoredSongs.sort((a, b) => b.score.compareTo(a.score));
    return scoredSongs.map((e) => e.song).toList();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);

    final artistIdToRegionMap = {
      for (var artist in songProvider.artists) artist.id: artist.region
    };

    final ethiopianSongs = songProvider.allSongs
        .where((song) =>
            artistIdToRegionMap[song.artistId] == 'Ethiopian' ||
            song.artistId == singlesArtistId)
        .toList();
    final worldwideSongs = songProvider.allSongs
        .where((song) => artistIdToRegionMap[song.artistId] == 'Worldwide')
        .toList();

    final sortedEthiopian = _sortSongsByRecommendation(ethiopianSongs);
    final sortedWorldwide = _sortSongsByRecommendation(worldwideSongs);

    final groupedEthiopian = _groupSongs(sortedEthiopian);
    final groupedWorldwide = _groupSongs(sortedWorldwide);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 95,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 44, right: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.12),
                      theme.colorScheme.secondary.withOpacity(0.06),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (songProvider.isSyncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: "Sync from Server",
                  iconSize: 20,
                  icon: Icon(
                    Icons.sync_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => songProvider.refreshData(),
                ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: IconButton(
                  key: searchKey,
                  tooltip: "Search Songs",
                  iconSize: 20,
                  icon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _toggleSearch,
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      theme.colorScheme.onSurface.withOpacity(0.7),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flag_rounded, size: 14),
                          const SizedBox(width: 6),
                          Text('ETHIOPIAN (${ethiopianSongs.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.public_rounded, size: 14),
                          const SizedBox(width: 6),
                          Text('WORLDWIDE (${worldwideSongs.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _MashupCategoryList(
              key: mashupTab1Key,
              regionalSongs: sortedEthiopian,
              groupedSongs: groupedEthiopian,
              scaleFilterKey: scaleFilterKey,
              rhythmFilterKey: rhythmFilterKey,
            ),
            _MashupCategoryList(
              key: mashupTab2Key,
              regionalSongs: sortedWorldwide,
              groupedSongs: groupedWorldwide,
              scaleFilterKey: GlobalKey(),
              rhythmFilterKey: GlobalKey(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MashupCategoryList extends StatefulWidget {
  final List<Song> regionalSongs;
  final Map<String, Map<String, List<Song>>> groupedSongs;
  final GlobalKey scaleFilterKey;
  final GlobalKey rhythmFilterKey;

  const _MashupCategoryList({
    super.key,
    required this.regionalSongs,
    required this.groupedSongs,
    required this.scaleFilterKey,
    required this.rhythmFilterKey,
  });

  @override
  State<_MashupCategoryList> createState() => _MashupCategoryListState();
}

class _MashupCategoryListState extends State<_MashupCategoryList>
    with TickerProviderStateMixin {
  String? _selectedScale;
  String? _selectedRhythm;
  late List<String> _sortedScales;

  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  String _searchQuery = '';
  bool _isSearching = false;

  late AnimationController _searchAnimationController;
  late Animation<double> _searchSlideAnimation;

  void toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchAnimationController.forward();
      } else {
        _searchAnimationController.reverse();
        _searchController.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateAndSelectDefaults();
    _searchController
        .addListener(() => _onSearchChanged(_searchController.text));

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _searchSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _searchAnimationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant _MashupCategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupedSongs != oldWidget.groupedSongs) {
      _updateAndSelectDefaults();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _updateAndSelectDefaults() {
    _sortedScales = widget.groupedSongs.keys.toList()..sort();
    if (_sortedScales.isNotEmpty) {
      if (_selectedScale == null || !_sortedScales.contains(_selectedScale)) {
        _selectedScale = _sortedScales.first;
      }
      var rhythms = widget.groupedSongs[_selectedScale]?.keys.toList();
      rhythms?.sort();
      if (rhythms != null && rhythms.isNotEmpty) {
        if (_selectedRhythm == null || !rhythms.contains(_selectedRhythm)) {
          _selectedRhythm = rhythms.first;
        }
      } else {
        _selectedRhythm = null;
      }
    } else {
      _selectedScale = null;
      _selectedRhythm = null;
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = query;
        _searchResults = [];
      });
      return;
    }
    final queryLower = query.toLowerCase();
    final Map<String, SearchResult> resultsMap = {};
    for (var song in widget.regionalSongs) {
      if (song.lyrics.toLowerCase().contains(queryLower)) {
        final matchIndex = song.lyrics.toLowerCase().indexOf(queryLower);
        final start = (matchIndex - 20).clamp(0, song.lyrics.length);
        final end =
            (matchIndex + queryLower.length + 30).clamp(0, song.lyrics.length);
        String snippet = song.lyrics.substring(start, end);
        if (start > 0) snippet = '...$snippet';
        if (end < song.lyrics.length) snippet = '$snippet...';
        resultsMap[song.id] = SearchResult(
            item: song,
            matchType: MatchType.lyric,
            matchSnippet: snippet.replaceAll('\n', ' '));
      }
      if (song.artistName.toLowerCase().contains(queryLower)) {
        resultsMap.putIfAbsent(
            song.id,
            () => SearchResult(
                item: song,
                matchType: MatchType.artist,
                matchSnippet: song.artistName));
      }
      if (song.title.toLowerCase().contains(queryLower)) {
        resultsMap[song.id] = SearchResult(
            item: song,
            matchType: MatchType.title,
            matchSnippet: song.artistName);
      }
    }
    setState(() {
      _searchQuery = query;
      _searchResults = resultsMap.values.toList();
    });
  }

  String _getCoverUrlForSong(Song song, SongProvider songProvider) {
    if (song.albumId == singlesAlbumId) {
      if (song.artistId != singlesArtistId) {
        final artist = songProvider.artists.firstWhere(
            (a) => a.id == song.artistId,
            orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''));
        return artist.imageUrl;
      }
      return '';
    } else {
      final album = songProvider.allAlbums.firstWhere(
          (a) => a.id == song.albumId,
          orElse: () => Album(
              id: '',
              title: '',
              artistId: '',
              artistName: '',
              coverImageUrl: ''));
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
              theme.colorScheme.primary.withOpacity(0.6),
              theme.colorScheme.secondary.withOpacity(0.6)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.music_note, size: 20, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);

    return RefreshIndicator(
      onRefresh: () => songProvider.refreshData(),
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _searchSlideAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _searchSlideAnimation.value,
                  child: _isSearching
                      ? _buildSearchBar()
                      : const SizedBox.shrink(),
                ),
              );
            },
          ),
          Expanded(
            child: _sortedScales.isEmpty && !_isSearching
                ? _buildEmptyState(songProvider)
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.05),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isSearching
                        ? _buildSearchResultsView()
                        : _buildBrowserView(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(SongProvider songProvider) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No Mashup Songs Found',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Songs with assigned scale and rhythm information will appear here automatically when fetched from the server.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => songProvider.refreshData(),
            icon: songProvider.isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(
                songProvider.isSyncing ? 'Syncing...' : 'Fetch from Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search songs, artists, lyrics...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          suffixIcon: IconButton(
            iconSize: 18,
            icon: Icon(
              Icons.close_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: toggleSearch,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildBrowserView() {
    final rhythmsInScale =
        _selectedScale != null ? widget.groupedSongs[_selectedScale] : null;
    final sortedRhythms = rhythmsInScale?.keys.toList();
    sortedRhythms?.sort();
    final songsToList = _selectedRhythm != null && rhythmsInScale != null
        ? rhythmsInScale[_selectedRhythm!] ?? []
        : <Song>[];

    return Column(
      key: const ValueKey('browser'),
      children: [
        _buildModernChipList(
          key: widget.scaleFilterKey,
          title: 'Musical Scale (Key)',
          icon: Icons.tune_rounded,
          items: _sortedScales,
          selectedItem: _selectedScale,
          getItemCount: (scale) {
            final map = widget.groupedSongs[scale];
            if (map == null) return 0;
            return map.values.fold(0, (sum, list) => sum + list.length);
          },
          onSelected: (scale) {
            setState(() {
              _selectedScale = scale;
              var newRhythms =
                  widget.groupedSongs[_selectedScale]?.keys.toList();
              newRhythms?.sort();
              _selectedRhythm = (newRhythms != null && newRhythms.isNotEmpty)
                  ? newRhythms.first
                  : null;
            });
          },
          isPrimary: true,
        ),
        if (sortedRhythms != null)
          _buildModernChipList(
            key: widget.rhythmFilterKey,
            title: 'Rhythm Pattern',
            icon: Icons.speed_rounded,
            items: sortedRhythms,
            selectedItem: _selectedRhythm,
            getItemCount: (rhythm) {
              return rhythmsInScale?[rhythm]?.length ?? 0;
            },
            onSelected: (rhythm) => setState(() => _selectedRhythm = rhythm),
            isPrimary: false,
          ),
        Expanded(
          child: songsToList.isEmpty
              ? _buildSelectRhythmPrompt()
              : _buildSongsList(songsToList),
        ),
      ],
    );
  }

  Widget _buildSelectRhythmPrompt() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.alt_route_rounded,
                size: 32,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a Rhythm Pattern',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a rhythm beat pattern above to display matching mashup songs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    return ListView.builder(
      key: ValueKey('$_selectedScale-$_selectedRhythm'),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 40).clamp(0, 400)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 15),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _buildModernSongCard(context, songs[index]),
        );
      },
    );
  }

  Widget _buildSearchResultsView() {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();
    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }
    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildModernSongCard(context, result.item, result: result);
      },
    );
  }

  Widget _buildNoResultsState() {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('no_results'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 32,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No matching songs found',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching with different song titles or lyric keywords',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChipList({
    required String title,
    required IconData icon,
    required List<String> items,
    required String? selectedItem,
    required int Function(String) getItemCount,
    required Function(String) onSelected,
    required bool isPrimary,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final activeColor =
        isPrimary ? theme.colorScheme.primary : theme.colorScheme.secondary;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 14, color: activeColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selectedItem;
                final count = getItemCount(item);

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: ChoiceChip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.25)
                                    : activeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSelected ? Colors.white : activeColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) onSelected(item);
                      },
                      selectedColor: activeColor,
                      backgroundColor: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? activeColor
                              : theme.colorScheme.outline.withOpacity(0.2),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      elevation: isSelected ? 3 : 0,
                      shadowColor: activeColor.withOpacity(0.4),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSongCard(BuildContext context, Song song,
      {SearchResult? result}) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final coverUrl = _getCoverUrlForSong(song, songProvider);
    final heroTag = 'mashup-song-${song.id}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 380),
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: theme.scaffoldBackgroundColor,
        closedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        closedBuilder: (context, openContainer) {
          return InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Hero(
                    tag: heroTag,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _getCoverForSong(song, songProvider),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        result != null && result.matchType != MatchType.lyric
                            ? TextHighlighter(
                                text: song.title,
                                query: _searchQuery,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Text(
                                song.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        const SizedBox(height: 2),
                        result != null
                            ? TextHighlighter(
                                text: result.matchSnippet!,
                                query: _searchQuery,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                maxLines: 2,
                              )
                            : Text(
                                song.artistName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        if (result == null &&
                            song.scale != null &&
                            song.rhythm != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildInfoBadge(
                                icon: Icons.tune_rounded,
                                text: song.scale!,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              _buildInfoBadge(
                                icon: Icons.speed_rounded,
                                text: song.rhythm!,
                                color: theme.colorScheme.secondary,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
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
          );
        },
        openBuilder: (context, _) => SongDetailScreen(
          song: song,
          heroTag: heroTag,
          albumCoverUrl: coverUrl,
        ),
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
