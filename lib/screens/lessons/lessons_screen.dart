import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:mahlete_semay_project/models/lesson_model.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/loading_placeholders.dart';

enum SortOption { newest, oldest, popular }

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  List<Lesson> _lessons = [];
  List<Category> _categories = [];
  bool _apiFailed = false;
  String _apiErrorMsg = '';

  final String _apiKey = 'AIzaSyBjlpooW60NX-wwnY1iZJr2THpJiwLcPPE';

  final Map<String, String> _categoryPlaylists = {
    'vocal_techniques': 'PL1Vqp_YsCsv_jfdrQvEfiGlKON8XTcofU',
    'songwriting': 'PLtLHnfGBJQRCOZJ31BvxAEB7mUHYQdQTN',
    'instrument_basics': 'PLsjNURiuRfXuWb_QOILU5uktXjjwbBh-q',
    'music_theory': 'PLwyorCBH5gKfanvo-G0EVmKsbNrMVGfKN',
    'recording': 'PLx5i827-FDqPiLPjGxlUv3gjq7uCEVVfl',
  };

  YoutubePlayerController? _youtubePlayerController;
  bool _isPlayerFullscreen = false;

  String _searchQuery = '';
  String _levelFilter = 'All Levels';
  SortOption _sortOption = SortOption.newest;
  final TextEditingController _searchFieldController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCategories();
    _tabController = TabController(length: _categories.length, vsync: this);
    _fetchLessons();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _searchFieldController.dispose();
    _youtubePlayerController?.removeListener(_youtubePlayerListener);
    _youtubePlayerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _youtubePlayerController == null) return;
    if (state == AppLifecycleState.paused) _youtubePlayerController!.pause();
  }

  void _initializeCategories() {
    _categories = [
      Category(id: 'vocal_techniques', name: 'Vocal', icon: IconsaxPlusBroken.microphone),
      Category(id: 'songwriting', name: 'Songwriting', icon: IconsaxPlusBroken.note_21),
      Category(id: 'instrument_basics', name: 'Instrument', icon: IconsaxPlusBroken.keyboard),
      Category(id: 'music_theory', name: 'Theory', icon: IconsaxPlusBroken.musicnote),
      Category(id: 'recording', name: 'Recording', icon: IconsaxPlusBroken.sound),
    ];
  }

  Future<void> _fetchLessons() async {
    if (_apiKey.isEmpty || _apiKey.startsWith('YOUR_')) {
      if (mounted) setState(() { _apiErrorMsg = 'YouTube API Key not configured.'; _apiFailed = true; _isLoading = false; });
      return;
    }
    if (mounted) setState(() { _isLoading = true; _apiFailed = false; _apiErrorMsg = ''; _lessons.clear(); });
    try {
      List<Future<List<Lesson>>> futures = _categoryPlaylists.entries.map((entry) => _fetchPlaylistItems(entry.value, entry.key)).toList();
      final List<List<Lesson>> results = await Future.wait(futures);
      final List<Lesson> allFetchedLessons = results.expand((i) => i).toList();
      var uniqueLessons = {for (var lesson in allFetchedLessons) lesson.videoId: lesson};
      if (mounted) setState(() { _lessons = uniqueLessons.values.toList(); _isLoading = false; if (_lessons.isEmpty) _apiErrorMsg = 'No lessons found.'; });
    } catch (e) {
      if (mounted) setState(() { _apiFailed = true; _apiErrorMsg = 'Failed to load lessons. Please check your internet connection.'; _isLoading = false; });
    }
  }

  Future<List<Lesson>> _fetchPlaylistItems(String playlistId, String category) async {
    final url = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=15&playlistId=$playlistId&key=$_apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Failed to load playlist $playlistId');

    final data = json.decode(response.body);
    if (data['items'] == null) return [];

    final videoIds = (data['items'] as List).map((item) => item['snippet']['resourceId']['videoId'] as String).toList();
    if (videoIds.isEmpty) return [];

    final detailsUrl = 'https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics&id=${videoIds.join(',')}&key=$_apiKey';
    final detailsResponse = await http.get(Uri.parse(detailsUrl));
    if (detailsResponse.statusCode != 200) return [];

    final detailsData = json.decode(detailsResponse.body);
    final videoDetailsMap = {for (var item in detailsData['items']) item['id']: item};

    List<Lesson> playlistLessons = [];
    for (var item in data['items']) {
      final snippet = item['snippet'];
      final videoId = snippet['resourceId']['videoId'];
      final details = videoDetailsMap[videoId];
      if (details == null || snippet['title'].toLowerCase().contains('private video')) continue;

      playlistLessons.add(Lesson(
        id: videoId, videoId: videoId, title: snippet['title'], description: snippet['description'], category: category,
        instructor: snippet['videoOwnerChannelTitle'] ?? 'Unknown',
        duration: _formatDuration(details['contentDetails']['duration']),
        level: _determineLevel(snippet['title']),
        imageUrl: snippet['thumbnails']?['high']?['url'] ?? snippet['thumbnails']?['medium']?['url'],
        rating: 4.5, reviewCount: int.tryParse(details['statistics']?['likeCount'] ?? '0') ?? 0,
        viewCount: int.tryParse(details['statistics']?['viewCount'] ?? '0') ?? 0,
        tags: [], publishedDate: DateTime.tryParse(snippet['publishedAt']),
      ));
    }
    return playlistLessons;
  }

  String _formatDuration(String isoDuration) {
    try {
      final d = ISO8601Duration.parse(isoDuration);
      final minutes = d.minutes + (d.hours * 60);
      final seconds = d.seconds.toString().padLeft(2, '0');
      return '$minutes:$seconds';
    } catch(e) { return 'N/A'; }
  }

  String _determineLevel(String title) {
    title = title.toLowerCase();
    if (title.contains('advanced') || title.contains('expert')) return 'Advanced';
    if (title.contains('intermediate')) return 'Intermediate';
    if (title.contains('beginner') || title.contains('basics')) return 'Beginner';
    return 'All Levels';
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _searchQuery = query.toLowerCase());
    });
  }

  List<Lesson> get _filteredAndSortedLessons {
    final categoryId = _categories[_tabController.index].id;
    List<Lesson> lessonsToShow = _lessons.where((lesson) => lesson.category == categoryId).toList();
    if (_searchQuery.isNotEmpty) {
      lessonsToShow = lessonsToShow.where((lesson) =>
      lesson.title.toLowerCase().contains(_searchQuery) ||
          lesson.instructor.toLowerCase().contains(_searchQuery)
      ).toList();
    }
    if (_levelFilter != 'All Levels') {
      lessonsToShow = lessonsToShow.where((lesson) => lesson.level == _levelFilter).toList();
    }
    switch (_sortOption) {
      case SortOption.oldest: lessonsToShow.sort((a,b) => (a.publishedDate ?? DateTime(0)).compareTo(b.publishedDate ?? DateTime(0))); break;
      case SortOption.popular: lessonsToShow.sort((a,b) => b.viewCount.compareTo(a.viewCount)); break;
      case SortOption.newest:
      default: lessonsToShow.sort((a,b) => (b.publishedDate ?? DateTime(0)).compareTo(a.publishedDate ?? DateTime(0))); break;
    }
    return lessonsToShow;
  }

  void _playVideo(String videoId) {
    _youtubePlayerController?.dispose();
    _youtubePlayerController = YoutubePlayerController(initialVideoId: videoId, flags: const YoutubePlayerFlags(autoPlay: true, useHybridComposition: true))..addListener(_youtubePlayerListener);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: WillPopScope(
          onWillPop: () async {
            if (_isPlayerFullscreen) {
              _youtubePlayerController?.toggleFullScreenMode();
              return false;
            }
            return true;
          },
          child: YoutubePlayer(controller: _youtubePlayerController!),
        ),
      ),
    ).then((_) {
      _youtubePlayerController?.dispose();
      _youtubePlayerController = null;
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    });
  }

  void _youtubePlayerListener() {
    if (!mounted || _youtubePlayerController == null) return;
    if (_isPlayerFullscreen != _youtubePlayerController!.value.isFullScreen) {
      setState(() => _isPlayerFullscreen = _youtubePlayerController!.value.isFullScreen);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter & Sort', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                Text('Level', style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: ['All Levels', 'Beginner', 'Intermediate', 'Advanced'].map((level) => ChoiceChip(label: Text(level), selected: _levelFilter == level, onSelected: (selected) => setModalState(() { if (selected) _levelFilter = level; }))).toList()),
                const SizedBox(height: 20),
                Text('Sort By', style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('Newest'), selected: _sortOption == SortOption.newest, onSelected: (s) => setModalState(() { if (s) _sortOption = SortOption.newest; })),
                  ChoiceChip(label: const Text('Oldest'), selected: _sortOption == SortOption.oldest, onSelected: (s) => setModalState(() { if (s) _sortOption = SortOption.oldest; })),
                  ChoiceChip(label: const Text('Popular'), selected: _sortOption == SortOption.popular, onSelected: (s) => setModalState(() { if (s) _sortOption = SortOption.popular; })),
                ]),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(child: const Text('Apply Filters'), onPressed: () { setState((){}); Navigator.pop(context); })),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lessons & Tutorials'),
        actions: [IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: _showFilterSheet)],
      ),
      body: _isLoading
          ? _buildLoadingShimmer()
          : _apiFailed
          ? _buildErrorState()
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(controller: _searchFieldController, onChanged: _onSearchChanged, decoration: InputDecoration(hintText: 'Search in lessons...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)), contentPadding: EdgeInsets.zero)),
          ),
          _buildCategoryTabs(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((cat) => _buildLessonsList(cat.id)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(borderRadius: BorderRadius.circular(20), color: theme.colorScheme.primary.withOpacity(0.1)),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        onTap: (index) => setState(() {}),
        tabs: _categories.map((cat) => Tab(child: Row(children: [Icon(cat.icon, size: 20), const SizedBox(width: 8), Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold))]))).toList(),
      ),
    );
  }

  Widget _buildLessonsList(String categoryId) {
    final lessonsToShow = _filteredAndSortedLessons;
    if (lessonsToShow.isEmpty && !_isLoading) {
      String message = 'No lessons found in this category.';
      if (_apiFailed) {
        return _buildErrorState();
      }
      if (_searchQuery.isNotEmpty) {
        message = 'No results found for "$_searchQuery"';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(IconsaxPlusBroken.video_slash, size: 70, color: Colors.grey.shade400,),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lessonsToShow.length,
        itemBuilder: (context, index) {
          final lesson = lessonsToShow[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildLessonCard(lesson),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _playVideo(lesson.videoId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CachedImage(imageUrl: lesson.imageUrl),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5)),
                  child: const Icon(IconsaxPlusBroken.play, color: Colors.white, size: 28),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: Text(lesson.duration, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LevelBadge(level: lesson.level),
                  const SizedBox(height: 8),
                  Text(lesson.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(lesson.instructor, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => const LessonCardShimmer(),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconsaxPlusBroken.cloud_connection,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Could Not Load Lessons',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _apiErrorMsg,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(IconsaxPlusBroken.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _apiFailed = false;
                });
                _fetchLessons();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color badgeColor;
    switch (level) {
      case 'Beginner': badgeColor = theme.colorScheme.primary; break;
      case 'Intermediate': badgeColor = theme.colorScheme.secondary; break;
      case 'Advanced': badgeColor = theme.colorScheme.error; break;
      default: badgeColor = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(level, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}