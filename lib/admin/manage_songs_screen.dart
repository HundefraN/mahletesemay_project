import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/search_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'add_song_screen.dart';
import 'edit_songs_screen.dart';
import 'widgets/admin_ui_kit.dart';

class ManageSongsScreen extends StatefulWidget {
  const ManageSongsScreen({super.key});

  @override
  State<ManageSongsScreen> createState() => _ManageSongsScreenState();
}

class _ManageSongsScreenState extends State<ManageSongsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<Map<String, List<Song>>> _songsFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _songsFuture = _loadAndCategorizeSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Song>>> _loadAndCategorizeSongs() async {
    final List<Song> allSongs = await _firebaseService.getSongs();
    final List<Artist> allArtists = await _firebaseService.getArtists();

    final Map<String, String> artistIdToRegionMap = {
      for (var artist in allArtists) artist.id: artist.region
    };

    final List<Song> ethiopianSongs = [];
    final List<Song> worldwideSongs = [];

    for (var song in allSongs) {
      if (artistIdToRegionMap[song.artistId] == 'Ethiopian') {
        ethiopianSongs.add(song);
      } else {
        worldwideSongs.add(song);
      }
    }

    return {
      'Ethiopian': ethiopianSongs,
      'Worldwide': worldwideSongs,
    };
  }

  void _refreshData() {
    setState(() {
      _songsFuture = _loadAndCategorizeSongs();
    });
  }

  void _navigateToAddSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSongScreen()),
    );
    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Manage Songs',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              AdminUiKit.hapticLight();
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13233D) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
              tabs: const [
                Tab(text: '🇪🇹 Ethiopian Songs'),
                Tab(text: '🌍 Worldwide Songs'),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, List<Song>>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AdminUiKit.goldAccent),
            );
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load songs',
              description: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _refreshData,
            );
          }

          final categorizedSongs = snapshot.data ?? {};

          return TabBarView(
            controller: _tabController,
            children: [
              _SongListTab(
                category: 'Ethiopian',
                songs: categorizedSongs['Ethiopian'] ?? [],
                onDataChanged: _refreshData,
                onAddSong: _navigateToAddSong,
              ),
              _SongListTab(
                category: 'Worldwide',
                songs: categorizedSongs['Worldwide'] ?? [],
                onDataChanged: _refreshData,
                onAddSong: _navigateToAddSong,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AdminUiKit.hapticMedium();
          _navigateToAddSong();
        },
        backgroundColor: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
        foregroundColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Add Song',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }
}

class _SongListTab extends StatefulWidget {
  final String category;
  final List<Song> songs;
  final VoidCallback onDataChanged;
  final VoidCallback onAddSong;

  const _SongListTab({
    required this.category,
    required this.songs,
    required this.onDataChanged,
    required this.onAddSong,
  });

  @override
  State<_SongListTab> createState() => _SongListTabState();
}

class _SongListTabState extends State<_SongListTab> {
  final FirebaseService _firebaseService = FirebaseService();
  late List<Song> _filteredSongs;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedSongIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _filteredSongs = widget.songs;
    _searchController.addListener(_filterSongs);
  }

  @override
  void didUpdateWidget(covariant _SongListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs != oldWidget.songs) {
      _filteredSongs = widget.songs;
      _filterSongs();
    }
  }

  void _filterSongs() {
    final query = _searchController.text.trim();
    setState(() {
      _filteredSongs = SearchService().filterSongs(
        query: query,
        songs: widget.songs,
      );
    });
  }

  void _toggleSelection(String songId) {
    AdminUiKit.hapticLight();
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
      if (_selectedSongIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _enterSelectionMode(String songId) {
    AdminUiKit.hapticMedium();
    setState(() {
      _isSelectionMode = true;
      _selectedSongIds.add(songId);
    });
  }

  void _exitSelectionMode() {
    AdminUiKit.hapticLight();
    setState(() {
      _isSelectionMode = false;
      _selectedSongIds.clear();
    });
  }

  Future<void> _deleteSelectedSongs() async {
    final count = _selectedSongIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $count Song(s)?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to permanently delete these $count song(s)? This action cannot be reversed.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final songsToDelete = widget.songs
            .where((s) => _selectedSongIds.contains(s.id))
            .map((s) => s.title)
            .join(', ');

        await _firebaseService.deleteSongs(_selectedSongIds.toList());

        if (authProvider.currentUser != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator?.fullName ?? 'Admin',
            action: 'DELETE_SONGS',
            details: 'Deleted $count song(s): $songsToDelete',
          );
        }

        if (mounted) {
          CustomSnackbar.show(context, 'Successfully deleted $count song(s).');
          _exitSelectionMode();
          widget.onDataChanged();
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Error deleting songs: $e', isError: true);
        }
      }
    }
  }

  void _editSong(Song song) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditSongScreen(song: song)),
    );
    if (result == true) {
      widget.onDataChanged();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Selection Bar or Search Field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _isSelectionMode
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AdminUiKit.roseRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminUiKit.roseRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _exitSelectionMode,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedSongIds.length} Selected',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : AdminUiKit.roseRed,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _selectedSongIds.isNotEmpty ? _deleteSelectedSongs : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminUiKit.roseRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                )
              : AdminSearchBar(
                  controller: _searchController,
                  hintText: 'Search by title, artist, or lyrics...',
                  onChanged: (_) => _filterSongs(),
                ),
        ),

        // Songs List
        Expanded(
          child: _filteredSongs.isEmpty
              ? AdminEmptyState(
                  icon: Icons.music_off_rounded,
                  title: 'No Songs Found',
                  description: _searchController.text.isNotEmpty
                      ? 'No matching songs for "${_searchController.text}".'
                      : 'There are no ${widget.category.toLowerCase()} songs added yet.',
                  actionLabel: _searchController.text.isEmpty ? 'Add Song' : null,
                  onAction: _searchController.text.isEmpty ? widget.onAddSong : null,
                )
              : RefreshIndicator(
                  color: AdminUiKit.goldAccent,
                  onRefresh: () async => widget.onDataChanged(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      final isSelected = _selectedSongIds.contains(song.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: AdminGlassCard(
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(song.id);
                            } else {
                              _editSong(song);
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              _enterSelectionMode(song.id);
                            }
                          },
                          borderColor: isSelected ? AdminUiKit.goldAccent : null,
                          customColor: isSelected
                              ? (isDark
                                  ? AdminUiKit.goldAccent.withOpacity(0.15)
                                  : AdminUiKit.primaryNavy.withOpacity(0.08))
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          borderRadius: 16,
                          child: Row(
                            children: [
                              // Avatar / Icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isSelected
                                        ? [AdminUiKit.goldAccent, AdminUiKit.goldHighlight]
                                        : [
                                            AdminUiKit.primaryNavy.withOpacity(0.15),
                                            AdminUiKit.goldAccent.withOpacity(0.15),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_rounded : Icons.music_note_rounded,
                                  color: isSelected
                                      ? AdminUiKit.primaryNavy
                                      : (isDark ? AdminUiKit.goldHighlight : AdminUiKit.primaryNavy),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Song Metadata
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${song.artistName} • ${song.albumTitle}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (song.scale != null || song.rhythm != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (song.scale != null && song.scale!.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AdminUiKit.royalBlue.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '🎵 ${song.scale}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AdminUiKit.royalBlue,
                                                ),
                                              ),
                                            ),
                                          if (song.rhythm != null && song.rhythm!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AdminUiKit.amberOrange.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '⏱️ ${song.rhythm}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AdminUiKit.amberOrange,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Trailing Checkbox or Edit Button
                              if (_isSelectionMode)
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AdminUiKit.goldAccent,
                                  checkColor: AdminUiKit.primaryNavy,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (_) => _toggleSelection(song.id),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.edit_note_rounded,
                                    size: 20,
                                    color: isDark ? AdminUiKit.goldHighlight : AdminUiKit.primaryNavy,
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
      ],
    );
  }
}