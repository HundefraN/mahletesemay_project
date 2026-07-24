import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/lyrics/recomended_songs_screen.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:mahlete_semay_project/widgets/master_detail_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/search_result_model.dart';
import 'package:mahlete_semay_project/screens/lyrics/all_artists_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/favorites_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/history_screen.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/cached_image.dart';
import 'package:mahlete_semay_project/widgets/text_highlighter.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'song_detail_screen.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';
import 'albums_list_screen.dart';
import 'songs_list_screen.dart';

class ArtistsListScreen extends StatefulWidget {
  const ArtistsListScreen({super.key});

  @override
  State<ArtistsListScreen> createState() => _ArtistsListScreenState();
}

class _ArtistsListScreenState extends State<ArtistsListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  String _searchQuery = '';
  String _filterType = 'All';
  late AnimationController _fabController;
  late AnimationController _searchController2;
  late Animation<double> _fabAnimation;
  late Animation<double> _searchAnimation;
  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  Artist? _selectedArtistForTablet;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchController2 = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchController2, curve: Curves.easeInOut),
    );

    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
      if (_isSearchFocused) {
        _searchController2.forward();
      } else {
        _searchController2.reverse();
      }
    });

    _fabController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabController.dispose();
    _searchController2.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final queryLower = query.trim().toLowerCase();

    if (queryLower.isEmpty) {
      setState(() {
        _searchQuery = "";
        _searchResults = [];
      });
      return;
    }

    final searchTokens =
        queryLower.split(' ').where((s) => s.isNotEmpty).toSet();
    final Map<String, ({double score, SearchResult result})> resultsMap = {};

    const double titleExactMatch = 50.0;
    const double titleTokenMatch = 20.0;
    const double titleContainsMatch = 5.0;
    const double artistExactMatch = 40.0;
    const double artistTokenMatch = 15.0;
    const double artistContainsMatch = 4.0;
    const double albumExactMatch = 30.0;
    const double albumContainsMatch = 3.0;
    const double lyricTokenMatch = 1.0;

    if (_filterType == 'All' || _filterType == 'Songs') {
      for (final song in songProvider.allSongs) {
        double currentScore = 0;
        MatchType matchType = MatchType.lyric;
        String matchSnippet = song.artistName;

        final titleLower = song.title.toLowerCase();
        final artistLower = song.artistName.toLowerCase();
        final lyricsLower = song.lyrics.toLowerCase();

        if (titleLower == queryLower) {
          currentScore += titleExactMatch;
          matchType = MatchType.title;
        } else if (titleLower.contains(queryLower)) {
          currentScore += titleContainsMatch;
          matchType = MatchType.title;
        } else {
          final titleTokens = titleLower.split(' ').toSet();
          final titleIntersection = searchTokens.intersection(titleTokens);
          currentScore += titleIntersection.length * titleTokenMatch;
          if (titleIntersection.isNotEmpty) matchType = MatchType.title;
        }

        if (artistLower == queryLower) {
          currentScore += artistExactMatch;
          if (currentScore > (resultsMap[song.id]?.score ?? 0)) {
            matchType = MatchType.artist;
          }
        } else if (artistLower.contains(queryLower)) {
          currentScore += artistContainsMatch;
          if (currentScore > (resultsMap[song.id]?.score ?? 0)) {
            matchType = MatchType.artist;
          }
        } else {
          final artistTokens = artistLower.split(' ').toSet();
          final artistIntersection = searchTokens.intersection(artistTokens);
          currentScore += artistIntersection.length * artistTokenMatch;
          if (artistIntersection.isNotEmpty &&
              currentScore > (resultsMap[song.id]?.score ?? 0)) {
            matchType = MatchType.artist;
          }
        }

        final lyricTokens = lyricsLower.split(RegExp(r'\s+')).toSet();
        final lyricIntersection = searchTokens.intersection(lyricTokens);
        currentScore += lyricIntersection.length * lyricTokenMatch;
        if (lyricIntersection.isNotEmpty && matchType == MatchType.lyric) {
          final firstMatchWord = lyricIntersection.first;
          final matchIndex = lyricsLower.indexOf(firstMatchWord);
          final start = (matchIndex - 20).clamp(0, song.lyrics.length);
          final end = (matchIndex + firstMatchWord.length + 30)
              .clamp(0, song.lyrics.length);
          matchSnippet =
              "...${song.lyrics.substring(start, end).replaceAll('\n', ' ')}...";
        }

        if (currentScore > 0) {
          if (currentScore > (resultsMap[song.id]?.score ?? 0)) {
            resultsMap[song.id] = (
              score: currentScore,
              result: SearchResult(
                  item: song, matchType: matchType, matchSnippet: matchSnippet)
            );
          }
        }
      }
    }

    if (_filterType == 'All' || _filterType == 'Artists') {
      for (final artist in songProvider.artists) {
        double currentScore = 0;
        final artistLower = artist.name.toLowerCase();

        if (artistLower == queryLower) {
          currentScore += artistExactMatch;
        } else if (artistLower.contains(queryLower)) {
          currentScore += artistContainsMatch * 2;
        } else {
          final artistTokens = artistLower.split(' ').toSet();
          final artistIntersection = searchTokens.intersection(artistTokens);
          currentScore += artistIntersection.length * artistTokenMatch;
        }

        if (currentScore > 0) {
          if (currentScore > (resultsMap[artist.id]?.score ?? 0)) {
            resultsMap[artist.id] = (
              score: currentScore,
              result: SearchResult(item: artist, matchType: MatchType.artist)
            );
          }
        }
      }
    }

    if (_filterType == 'All' || _filterType == 'Albums') {
      for (final album in songProvider.allAlbums) {
        double currentScore = 0;
        final albumLower = album.title.toLowerCase();

        if (albumLower == queryLower) {
          currentScore += albumExactMatch;
        } else if (albumLower.contains(queryLower)) {
          currentScore += albumContainsMatch;
        }

        if (currentScore > 0) {
          if (currentScore > (resultsMap[album.id]?.score ?? 0)) {
            resultsMap[album.id] = (
              score: currentScore,
              result: SearchResult(item: album, matchType: MatchType.album)
            );
          }
        }
      }
    }

    final sortedResults = resultsMap.values.toList();
    sortedResults.sort((a, b) => b.score.compareTo(a.score));

    setState(() {
      _searchQuery = query;
      _searchResults = sortedResults.map((e) => e.result).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            margin: EdgeInsets.all(context.w(16)),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(context.w(24)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Padding(
              padding: EdgeInsets.all(context.w(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: context.w(32),
                      height: context.w(4),
                      margin: EdgeInsets.only(bottom: context.w(16)),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Filter Search',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, fontSize: context.sp(24)),
                  ),
                  SizedBox(height: context.w(20)),
                  _buildFilterOption(
                      context, 'All', IconsaxPlusBold.search_normal_1),
                  _buildFilterOption(context, 'Songs', IconsaxPlusBold.music),
                  _buildFilterOption(context, 'Artists', IconsaxPlusBold.user),
                  _buildFilterOption(
                      context, 'Albums', IconsaxPlusBold.music_playlist),
                  SizedBox(height: context.w(16)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, String type, IconData icon) {
    final isSelected = _filterType == type;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        setState(() => _filterType = type);
        _onSearchChanged(_searchController.text);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(context.w(16)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
            vertical: context.w(12), horizontal: context.w(16)),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(context.w(16)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(8)),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(context.w(10)),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                size: context.w(18),
              ),
            ),
            SizedBox(width: context.w(16)),
            Text(
              type,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontSize: context.sp(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  Widget _buildUpdateBanner(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          height: songProvider.hasNewDataOnMobile ? context.w(60) : 0,
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.symmetric(
                  horizontal: context.w(16), vertical: context.w(8)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(context.w(16)),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(context.w(12)),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.w(6)),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(context.w(10)),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: context.w(18),
                      ),
                    ),
                    SizedBox(width: context.w(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Content Available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: context.sp(13),
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          Text(
                            'Fresh songs waiting for you',
                            style: TextStyle(
                              fontSize: context.sp(11),
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        CustomSnackbar.show(context, 'Syncing new content...');
                        await songProvider.forceSyncOnMobileData();
                        if (mounted) {
                          CustomSnackbar.show(context, 'Content updated!');
                        }
                      },
                      icon: Icon(Icons.download_rounded, size: context.w(14)),
                      label: Text('Download',
                          style: TextStyle(fontSize: context.sp(12))),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.w(12), vertical: context.w(6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.w(10)),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);

    if (songProvider.isLoading ||
        (songProvider.isSyncing && songProvider.allSongs.isEmpty)) {
      return const Scaffold(body: ArtistsListShimmer());
    }

    Widget masterPane = _buildMasterPane();
    Widget detailPane = _selectedArtistForTablet != null
        ? AlbumsListScreen(
            artist: _selectedArtistForTablet!,
            artistHeroTag: _selectedArtistForTablet!.id,
          )
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(IconsaxPlusBold.user_search,
                    size: 80,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('Select an artist to see their albums',
                    style: TextStyle(fontSize: 18)),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: MasterDetailScaffold(
        masterPane: masterPane,
        detailPane: detailPane,
        isDetailPaneVisible: _selectedArtistForTablet != null,
      ),
    );
  }

  Widget _buildMasterPane() {
    final l10n = AppLocalizations.of(context)!;
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);

    final hasSinglesArtist =
        songProvider.artists.any((a) => a.id == singlesArtistId);
    final hasSinglesSongs =
        songProvider.allSongs.any((s) => s.albumId == singlesAlbumId);

    final List<Artist> recommendedEthiopian =
        songProvider.getRecommendedArtists(region: 'Ethiopian');
    final List<Artist> recommendedWorldwide =
        songProvider.getRecommendedArtists(region: 'Worldwide');
    final List<Song> singleSongs = songProvider.allSongs
        .where((s) => s.albumId == singlesAlbumId)
        .toList();

    if (hasSinglesArtist) {
      final singlesVirtualArtist = Artist(
          id: singlesArtistId,
          name: 'Singles',
          imageUrl: '',
          region: 'Ethiopian');
      if (!recommendedEthiopian.any((a) => a.id == singlesArtistId)) {
        recommendedEthiopian.insert(0, singlesVirtualArtist);
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.1),
            theme.colorScheme.background,
            theme.colorScheme.background,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildUpdateBanner(context),
          if (songProvider.isSyncing) const LinearProgressIndicator(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: context.w(140),
                  pinned: false,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.1),
                            theme.colorScheme.secondary.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: context.w(20),
                              vertical: context.w(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          getGreeting(context),
                                          style: theme.textTheme.headlineMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                theme.colorScheme.onBackground,
                                            fontSize: context.sp(28),
                                          ),
                                        ),
                                        SizedBox(height: context.w(4)),
                                        Text(
                                          'Discover amazing music',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onBackground
                                                .withOpacity(0.7),
                                            fontSize: context.sp(14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ScaleTransition(
                                    scale: _fabAnimation,
                                    child: Row(
                                      children: [
                                        _buildHeaderButton(theme, context,
                                            icon: IconsaxPlusBold.refresh,
                                            tooltip: l10n.history,
                                            onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const HistoryScreen()))),
                                        SizedBox(width: context.w(8)),
                                        _buildHeaderButton(theme, context,
                                            icon: IconsaxPlusBold.heart,
                                            tooltip: l10n.favorites,
                                            onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const FavoritesScreen()))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        context.w(16), 0, context.w(16), context.w(16)),
                    child: AnimatedBuilder(
                      animation: _searchAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_searchAnimation.value * 0.02),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(context.w(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: _isSearchFocused
                                      ? theme.colorScheme.primary
                                          .withOpacity(0.2)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: _isSearchFocused ? 20 : 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(fontSize: context.sp(14)),
                                    decoration: InputDecoration(
                                      hintText: l10n.searchHint,
                                      hintStyle: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                        fontSize: context.sp(14),
                                      ),
                                      prefixIcon: Container(
                                        margin: EdgeInsets.all(context.w(8)),
                                        padding: EdgeInsets.all(context.w(8)),
                                        decoration: BoxDecoration(
                                          color: _isSearchFocused
                                              ? theme.colorScheme.primary
                                              : theme
                                                  .colorScheme.surfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                              context.w(12)),
                                        ),
                                        child: Icon(
                                          IconsaxPlusBold.search_normal,
                                          color: _isSearchFocused
                                              ? theme.colorScheme.onPrimary
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                          size: context.w(20),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: theme.colorScheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            context.w(20)),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            context.w(20)),
                                        borderSide: BorderSide(
                                          color: theme.colorScheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.w(8)),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _filterType != 'All'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.surface,
                                    borderRadius:
                                        BorderRadius.circular(context.w(16)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      IconsaxPlusBold.setting_4,
                                      size: context.w(22),
                                      color: _filterType != 'All'
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                    ),
                                    onPressed: _showFilterSheet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  _searchResults.isEmpty
                      ? _buildNoResultsSliver()
                      : _buildSearchResultsList()
                else ...[
                  _buildSectionHeader(
                    context,
                    l10n.recommendedForYou,
                    IconsaxPlusBold.like_1,
                    action: TextButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RecommendedSongsScreen())),
                      icon: Icon(IconsaxPlusBold.arrow_right_2,
                          size: context.w(16)),
                      label: Text(l10n.seeAll,
                          style: TextStyle(fontSize: context.sp(13))),
                      style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary),
                    ),
                  ),
                  _buildRecommendedGrid(
                      context,
                      songProvider
                          .getPersonalizedRecommendations()
                          .take(4)
                          .toList()),
                  _buildSectionHeader(
                    context,
                    l10n.ethiopianArtists,
                    IconsaxPlusBold.location,
                    action: recommendedEthiopian.length > 7
                        ? TextButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AllArtistsScreen(
                                        title: l10n.ethiopianArtists,
                                        region: 'Ethiopian'))),
                            icon: Icon(IconsaxPlusBold.arrow_right_2,
                                size: context.w(16)),
                            label: Text(l10n.seeAll,
                                style: TextStyle(fontSize: context.sp(13))),
                            style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary),
                          )
                        : null,
                  ),
                  _buildArtistCarousel(
                      context, recommendedEthiopian.take(7).toList()),
                  _buildSectionHeader(
                    context,
                    l10n.worldwideArtists,
                    IconsaxPlusBold.global,
                    action: recommendedWorldwide.length > 7
                        ? TextButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AllArtistsScreen(
                                        title: l10n.worldwideArtists,
                                        region: 'Worldwide'))),
                            icon: Icon(IconsaxPlusBold.arrow_right_2,
                                size: context.w(16)),
                            label: Text(l10n.seeAll,
                                style: TextStyle(fontSize: context.sp(13))),
                            style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary),
                          )
                        : null,
                  ),
                  _buildArtistCarousel(
                      context, recommendedWorldwide.take(7).toList()),
                  if (hasSinglesSongs) ...[
                    _buildSectionHeader(
                      context,
                      "Singles",
                      IconsaxPlusBold.music,
                      action: singleSongs.length > 8
                          ? TextButton.icon(
                              onPressed: () {
                                final virtualAlbum = Album(
                                    id: singlesAlbumId,
                                    title: "Singles",
                                    artistId: singlesArtistId,
                                    artistName: "Various Artists",
                                    coverImageUrl: '');
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => SongsListScreen(
                                            album: virtualAlbum,
                                            albumHeroTag:
                                                'album-$singlesAlbumId')));
                              },
                              icon: Icon(IconsaxPlusBold.arrow_right_2,
                                  size: context.w(16)),
                              label: Text(l10n.viewAll,
                                  style: TextStyle(fontSize: context.sp(13))),
                              style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary),
                            )
                          : null,
                    ),
                    _buildSinglesCarousel(singleSongs.take(8).toList()),
                  ],
                  SliverToBoxAdapter(child: SizedBox(height: context.w(80))),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsSliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(context.w(20)),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(context.w(20))),
              child: Icon(Icons.search_off_rounded,
                  size: context.w(40),
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: context.w(20)),
            Text('No results found for "$_searchQuery"',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, fontSize: context.sp(22))),
            SizedBox(height: context.w(8)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(40)),
              child: Text(
                  'Try searching with different keywords or check your spelling.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      fontSize: context.sp(14)),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final result = _searchResults[index];
            if (result.item is Song) {
              return _buildSongResultTile(context, result);
            }
            if (result.item is Artist) {
              return _buildArtistResultTile(context, result.item);
            }
            if (result.item is Album) {
              return _buildAlbumResultTile(context, result.item);
            }
            return const SizedBox.shrink();
          },
          childCount: _searchResults.length,
        ),
      ),
    );
  }

  Widget _buildHeaderButton(ThemeData theme, BuildContext context,
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(context.w(14)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.colorScheme.primary, size: context.w(24)),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _getCoverForSong(Song song, SongProvider songProvider) {
    final theme = Theme.of(context);
    String coverUrl = '';

    if (song.albumId == singlesAlbumId) {
      if (song.artistId != singlesArtistId) {
        final artist = songProvider.artists.firstWhere(
            (a) => a.id == song.artistId,
            orElse: () => Artist(id: '', name: '', imageUrl: '', region: ''));
        coverUrl = artist.imageUrl;
      }
    } else {
      final album = songProvider.allAlbums.firstWhere(
          (a) => a.id == song.albumId,
          orElse: () => Album(
              id: '',
              title: '',
              artistId: '',
              artistName: '',
              coverImageUrl: ''));
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
        child: Icon(IconsaxPlusBold.musicnote,
            color: Colors.white.withOpacity(0.8), size: context.w(30)),
      );
    }
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

  Widget _buildSongResultTile(BuildContext context, SearchResult result) {
    final theme = Theme.of(context);
    final song = result.item as Song;
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final coverUrl = _getCoverUrlForSong(song, songProvider);
    final heroTag = 'search-song-${song.id}';

    return Container(
      margin: EdgeInsets.only(bottom: context.w(10)),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(context.w(16)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Colors.transparent,
        closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.w(16))),
        openBuilder: (context, _) => SongDetailScreen(
            song: song, heroTag: heroTag, albumCoverUrl: coverUrl),
        closedBuilder: (context, openContainer) {
          return ListTile(
            onTap: openContainer,
            contentPadding: EdgeInsets.symmetric(
                horizontal: context.w(16), vertical: context.w(8)),
            leading: Hero(
              tag: heroTag,
              child: Container(
                width: context.w(48),
                height: context.w(48),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.w(12)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.w(12)),
                    child: _getCoverForSong(song, songProvider)),
              ),
            ),
            title: TextHighlighter(
                text: song.title,
                query: _searchQuery,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: context.sp(15))),
            subtitle: result.matchType == MatchType.lyric
                ? TextHighlighter(
                    text: result.matchSnippet!,
                    query: _searchQuery,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: context.sp(12)))
                : _SongMetadataColumn(song: song, fontSize: context.sp(12)),
          );
        },
      ),
    );
  }

  Widget _buildArtistResultTile(BuildContext context, Artist artist) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: context.w(10)),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(context.w(16)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: ListTile(
        onTap: () {
          final isTablet = MediaQuery.of(context).size.width > 720;
          if (isTablet) {
            setState(() => _selectedArtistForTablet = artist);
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AlbumsListScreen(
                        artist: artist, artistHeroTag: artist.id)));
          }
        },
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(16), vertical: context.w(8)),
        leading: Hero(
          tag: artist.id,
          child: Container(
            width: context.w(48),
            height: context.w(48),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.w(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(context.w(24)),
                child: CachedImage(imageUrl: artist.imageUrl)),
          ),
        ),
        title: TextHighlighter(
            text: artist.name,
            query: _searchQuery,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: context.sp(15))),
        subtitle: Text('Artist • ${artist.region}',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: context.sp(12))),
        trailing: Icon(IconsaxPlusBold.user,
            color: theme.colorScheme.primary, size: context.w(24)),
      ),
    );
  }

  Widget _buildAlbumResultTile(BuildContext context, Album album) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final heroTag = 'search-album-${album.id}';
    final songCount = songProvider.getSongsByAlbum(album.id).length;
    final songCountText = '$songCount ${songCount == 1 ? 'song' : 'songs'}';

    return Container(
      margin: EdgeInsets.only(bottom: context.w(10)),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(context.w(16)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: ListTile(
        onTap: () {
          final isTablet = MediaQuery.of(context).size.width > 720;
          if (isTablet) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SongsListScreen(album: album, albumHeroTag: heroTag)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SongsListScreen(album: album, albumHeroTag: heroTag)));
          }
        },
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(16), vertical: context.w(8)),
        leading: Hero(
          tag: heroTag,
          child: Container(
            width: context.w(48),
            height: context.w(48),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.w(12)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(context.w(12)),
                child: CachedImage(imageUrl: album.coverImageUrl)),
          ),
        ),
        title: TextHighlighter(
            text: album.title,
            query: _searchQuery,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: context.sp(15))),
        subtitle: TextHighlighter(
            text: 'Album • $songCountText',
            query: _searchQuery,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: context.sp(12))),
        trailing: Icon(IconsaxPlusBold.music_playlist,
            color: theme.colorScheme.primary, size: context.w(24)),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon,
      {Widget? action}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
            left: context.w(16),
            right: context.w(16),
            top: context.w(24),
            bottom: context.w(16)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(8)),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(context.w(12))),
              child: Icon(icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: context.w(20)),
            ),
            SizedBox(width: context.w(12)),
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: context.sp(16)))),
            if (action != null) action,
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedGrid(BuildContext context, List<Song> songs) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: context.w(12),
          crossAxisSpacing: context.w(12),
          childAspectRatio: 2.3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songs[index];
            return _buildGridItemCard(context, song);
          },
          childCount: songs.length,
        ),
      ),
    );
  }

  Widget _buildGridItemCard(BuildContext context, Song song) {
    final theme = Theme.of(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final coverUrl = _getCoverUrlForSong(song, songProvider);
    final heroTag = 'recommended-${song.id}';
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.w(16))),
      closedColor: theme.colorScheme.surface,
      openBuilder: (context, _) => SongDetailScreen(
          song: song, heroTag: heroTag, albumCoverUrl: coverUrl),
      closedBuilder: (context, openContainer) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.w(16)),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceVariant.withOpacity(0.3)
                ]),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.w(16)),
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Hero(
                      tag: heroTag,
                      child: _getCoverForSong(song, songProvider)),
                ),
                SizedBox(width: context.w(8)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: context.w(6), horizontal: context.w(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(song.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: context.sp(12)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: _SongMetadataColumn(
                                song: song, fontSize: context.sp(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistCarousel(BuildContext context, List<Artist> artists) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final isTablet = MediaQuery.of(context).size.width > 720;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: context.w(165),
        child: artists.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_rounded,
                        size: context.w(32),
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3)),
                    SizedBox(height: context.w(8)),
                    Text('No artists in this category.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                            fontSize: context.sp(13))),
                  ],
                ),
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                itemCount: artists.length,
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  final isSinglesCategory = artist.id == singlesArtistId;
                  final albumCount =
                      songProvider.getAlbumsByArtist(artist.id).length;

                  return GestureDetector(
                    onTap: () {
                      if (isTablet) {
                        setState(() => _selectedArtistForTablet = artist);
                      } else {
                        if (isSinglesCategory) {
                          final virtualAlbum = Album(
                              id: singlesAlbumId,
                              title: "Singles",
                              artistId: singlesArtistId,
                              artistName: "Various Artists",
                              coverImageUrl: '');
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SongsListScreen(
                                      album: virtualAlbum,
                                      albumHeroTag: 'album-$singlesAlbumId')));
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AlbumsListScreen(
                                      artist: artist,
                                      artistHeroTag: artist.id)));
                        }
                      }
                    },
                    child: Container(
                      width: context.w(95),
                      margin: EdgeInsets.only(right: context.w(12)),
                      child: Column(
                        children: [
                          Container(
                            width: context.w(85),
                            height: context.w(85),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(context.w(42.5)),
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.1),
                                    Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.1)
                                  ]),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(context.w(2.5)),
                              child: Hero(
                                tag: artist.id,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(context.w(40)),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(context.w(40)),
                                    child: isSinglesCategory
                                        ? Container(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            child: Icon(
                                                IconsaxPlusBold.musicnote,
                                                size: context.w(32),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer))
                                        : CachedImage(
                                            imageUrl: artist.imageUrl),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: context.w(8)),
                          Text(artist.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.sp(12))),
                          SizedBox(height: context.w(3)),
                          if (!isSinglesCategory)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: context.w(8),
                                  vertical: context.w(2)),
                              decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(context.w(8))),
                              child: Text(
                                  '$albumCount Album${albumCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                      fontSize: context.sp(10),
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSinglesCarousel(List<Song> songs) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: context.w(150),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final coverUrl = _getCoverUrlForSong(song, songProvider);
            final heroTag = 'singles-carousel-${song.id}';

            return Container(
              width: context.w(95),
              margin: EdgeInsets.only(right: context.w(10)),
              child: OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                closedElevation: 0,
                openElevation: 0,
                closedColor: Colors.transparent,
                openColor: Colors.transparent,
                closedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.w(12))),
                openBuilder: (context, _) => SongDetailScreen(
                    song: song, heroTag: heroTag, albumCoverUrl: coverUrl),
                closedBuilder: (context, openContainer) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: context.w(85),
                        width: context.w(95),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(context.w(12)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]),
                        child: Hero(
                            tag: heroTag,
                            child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(context.w(12)),
                                child: _getCoverForSong(song, songProvider))),
                      ),
                      SizedBox(height: context.w(6)),
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: context.sp(11))),
                      SizedBox(height: context.w(2)),
                      _SongMetadataColumn(
                          song: song, fontSize: context.sp(9.5)),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SongMetadataColumn extends StatelessWidget {
  const _SongMetadataColumn({
    required this.song,
    required this.fontSize,
  });

  final Song song;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactFormat = NumberFormat.compact().format(song.viewCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (song.viewCount > 0) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: fontSize + 1,
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  compactFormat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ]
      ],
    );
  }
}
