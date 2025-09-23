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
  late Animation<double> _searchAnimation;
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
    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchAnimationController, curve: Curves.easeInOut),
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
        radius: 12,
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
        radius: 12,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
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
      final recencyScore = 1 / (daysAgo + 1);
      final popularityScore = song.viewCount / maxViews;
      final totalScore = (popularityScore * 0.7) + (recencyScore * 0.3);
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
        .where((song) => artistIdToRegionMap[song.artistId] == 'Ethiopian' || song.artistId == singlesArtistId)
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
            expandedHeight: 120,
            floating: false,
            pinned: false,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Worship Mashup Helper',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  key: searchKey,
                  icon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _toggleSearch,
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: 'ETHIOPIAN'),
                    Tab(text: 'WORLDWIDE'),
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
    _searchController.addListener(() => _onSearchChanged(_searchController.text));

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _searchSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchAnimationController, curve: Curves.elasticOut),
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
      _selectedScale = _sortedScales.first;
      var rhythms = widget.groupedSongs[_selectedScale]?.keys.toList();
      rhythms?.sort();
      _selectedRhythm =
      (rhythms != null && rhythms.isNotEmpty) ? rhythms.first : null;
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
            colors: [theme.colorScheme.primary.withOpacity(0.5), theme.colorScheme.secondary.withOpacity(0.5)],
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
    if (_sortedScales.isEmpty && !_isSearching) {
      return _buildEmptyState();
    }

    final rhythmsInScale =
    _selectedScale != null ? widget.groupedSongs[_selectedScale] : null;
    final sortedRhythms = rhythmsInScale?.keys.toList();
    sortedRhythms?.sort();
    final songsToList = _selectedRhythm != null && rhythmsInScale != null
        ? rhythmsInScale[_selectedRhythm!] ?? []
        : <Song>[];

    return Column(
      children: [
        AnimatedBuilder(
          animation: _searchSlideAnimation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _searchSlideAnimation.value,
                child: _isSearching ? _buildSearchBar() : const SizedBox.shrink(),
              ),
            );
          },
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _isSearching
                ? _buildSearchResultsView()
                : _buildBrowserView(sortedRhythms, songsToList),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No songs available yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Songs with both scale and rhythm information will appear here when available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search songs, artists, lyrics...',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: toggleSearch,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildBrowserView(List<String>? sortedRhythms, List<Song> songsToList) {
    return Column(
      key: const ValueKey('browser'),
      children: [
        _buildModernChipList(
          key: widget.scaleFilterKey,
          title: 'Musical Scale',
          items: _sortedScales,
          selectedItem: _selectedScale,
          onSelected: (scale) {
            setState(() {
              _selectedScale = scale;
              var newRhythms =
              widget.groupedSongs[_selectedScale]?.keys.toList();
              newRhythms?.sort();
              _selectedRhythm =
              (newRhythms != null && newRhythms.isNotEmpty)
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
            items: sortedRhythms,
            selectedItem: _selectedRhythm,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.queue_music_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a rhythm pattern',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from the rhythm options above to discover matching songs',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    return ListView.builder(
      key: ValueKey('$_selectedScale-$_selectedRhythm'),
      padding: const EdgeInsets.all(16.0),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 100 + (index * 50)),
          curve: Curves.easeOutBack,
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
      padding: const EdgeInsets.all(16.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildModernSongCard(context, result.item, result: result);
      },
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      key: const ValueKey('no_results'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChipList({
    required String title,
    required List<String> items,
    required String? selectedItem,
    required Function(String) onSelected,
    required bool isPrimary,
    Key? key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPrimary
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selectedItem;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FilterChip(
                      label: Text(item),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) onSelected(item);
                      },
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      selectedColor: isPrimary
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isPrimary
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSecondary)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      side: isSelected
                          ? BorderSide.none
                          : BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                      elevation: isSelected ? 4 : 0,
                      shadowColor: isPrimary
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                          : Theme.of(context).colorScheme.secondary.withOpacity(0.3),
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

  Widget _buildModernSongCard(BuildContext context, Song song, {SearchResult? result}) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final coverUrl = _getCoverUrlForSong(song, songProvider);
    final heroTag = 'mashup-song-${song.id}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 400),
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: theme.scaffoldBackgroundColor,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        closedBuilder: (context, openContainer) {
          return InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Hero(
                    tag: heroTag,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _getCoverForSong(song, songProvider)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        result != null && result.matchType != MatchType.lyric
                            ? TextHighlighter(text: song.title, query: _searchQuery, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
                            : Text(song.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        result != null
                            ? TextHighlighter(text: result.matchSnippet!, query: _searchQuery, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withOpacity(0.7)), maxLines: 2)
                            : Text(song.artistName, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (result == null && song.scale != null && song.rhythm != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoChip(song.scale!, theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              _buildInfoChip(song.rhythm!, theme.colorScheme.secondary),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 20, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          );
        },
        openBuilder: (context, _) => SongDetailScreen(song: song, heroTag: heroTag, albumCoverUrl: coverUrl),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}