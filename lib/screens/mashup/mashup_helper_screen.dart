import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/search_result_model.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:mahlete_semay_project/widgets/text_highlighter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import '../lyrics/ song_detail_screen.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TutorialCoachMark tutorialCoachMark;
  GlobalKey searchKey = GlobalKey();
  GlobalKey scaleFilterKey = GlobalKey();
  GlobalKey rhythmFilterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
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

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);

    final artistIdToRegionMap = {
      for (var artist in songProvider.artists) artist.id: artist.region
    };

    final ethiopianSongs = songProvider.allSongs
        .where((song) => artistIdToRegionMap[song.artistId] == 'Ethiopian')
        .toList();
    final worldwideSongs = songProvider.allSongs
        .where((song) => artistIdToRegionMap[song.artistId] == 'Worldwide')
        .toList();

    final sortedEthiopian =
    songProvider.sortSongsByRecommendation(songsToSort: ethiopianSongs);
    final sortedWorldwide =
    songProvider.sortSongsByRecommendation(songsToSort: worldwideSongs);

    final groupedEthiopian = _groupSongs(sortedEthiopian);
    final groupedWorldwide = _groupSongs(sortedWorldwide);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worship Mashup Helper'),
        actions: [
          IconButton(
            key: searchKey,
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.secondary,
          tabs: const [Tab(text: 'ETHIOPIAN'), Tab(text: 'WORLDWIDE')],
        ),
      ),
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

class _MashupCategoryListState extends State<_MashupCategoryList> {
  String? _selectedScale;
  String? _selectedRhythm;
  late List<String> _sortedScales;

  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  String _searchQuery = '';
  bool _isSearching = false;

  void toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateAndSelectDefaults();
    _searchController.addListener(() => _onSearchChanged(_searchController.text));
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

  @override
  Widget build(BuildContext context) {
    if (_sortedScales.isEmpty && !_isSearching) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'No songs with both scale and rhythm information are available for this region yet.',
              textAlign: TextAlign.center,
            ),
          ));
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
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search songs, artists, lyrics...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSearching
                ? _buildSearchResultsView()
                : _buildBrowserView(sortedRhythms, songsToList),
          ),
        ),
      ],
    );
  }

  Widget _buildBrowserView(List<String>? sortedRhythms, List<Song> songsToList) {
    return Column(
      key: const ValueKey('browser'),
      children: [
        _buildHorizontalChipList(
          key: widget.scaleFilterKey,
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
        ),
        if (sortedRhythms != null)
          _buildHorizontalChipList(
            key: widget.rhythmFilterKey,
            items: sortedRhythms,
            selectedItem: _selectedRhythm,
            onSelected: (rhythm) => setState(() => _selectedRhythm = rhythm),
            isPrimary: false,
          ),
        const Divider(height: 1),
        Expanded(
          child: songsToList.isEmpty
              ? const Center(child: Text('Select a rhythm to see songs.'))
              : ListView.builder(
            key: ValueKey('$_selectedScale-$_selectedRhythm'),
            padding: const EdgeInsets.all(16.0),
            itemCount: songsToList.length,
            itemBuilder: (context, index) {
              final song = songsToList[index];
              return _buildSongCard(context, song);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsView() {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();
    if (_searchResults.isEmpty)
      return Center(
          key: const ValueKey('no_results'),
          child: Text('No results found for "$_searchQuery"'));
    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(16.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSongCard(context, result.item, result: result);
      },
    );
  }

  Widget _buildHorizontalChipList(
      {required List<String> items,
        required String? selectedItem,
        required Function(String) onSelected,
        bool isPrimary = true,
        Key? key}) {
    return SizedBox(
      key: key,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onSelected(item);
              },
              selectedColor: isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isPrimary
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSecondary)
                    : null,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: isSelected
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade300),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongCard(BuildContext context, Song song, {SearchResult? result}) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final album = songProvider.allAlbums.firstWhere(
          (a) => a.id == song.albumId,
      orElse: () => Album(
          id: '',
          title: '',
          artistId: '',
          artistName: '',
          coverImageUrl: '',
          year: 0,
          volume: 1),
    );
    final heroTag = 'mashup-song-${song.id}';

    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      closedElevation: 0,
      openElevation: 4,
      closedColor: Theme.of(context).scaffoldBackgroundColor,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      openShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      closedBuilder: (context, openContainer) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: openContainer,
            leading: Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CachedImage(imageUrl: album.coverImageUrl),
                ),
              ),
            ),
            title: result != null && result.matchType != MatchType.lyric
                ? TextHighlighter(
                text: song.title,
                query: _searchQuery,
                style: const TextStyle(fontWeight: FontWeight.bold))
                : Text(song.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: result != null
                ? TextHighlighter(
                text: result.matchSnippet!,
                query: _searchQuery,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
                maxLines: 2)
                : Text(song.artistName),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ),
        );
      },
      openBuilder: (context, _) => SongDetailScreen(
          song: song, heroTag: heroTag, albumCoverUrl: album.coverImageUrl),
    );
  }
}