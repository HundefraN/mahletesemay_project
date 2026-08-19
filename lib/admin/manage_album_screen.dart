import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'add_album_screen.dart';
import 'edit_album_screen.dart';
import 'widgets/admin_ui_kit.dart';

class ManageAlbumsScreen extends StatefulWidget {
  const ManageAlbumsScreen({super.key});

  @override
  State<ManageAlbumsScreen> createState() => _ManageAlbumsScreenState();
}

class _ManageAlbumsScreenState extends State<ManageAlbumsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<Map<String, List<Album>>> _albumsFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _albumsFuture = _loadAndCategorizeAlbums();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Album>>> _loadAndCategorizeAlbums() async {
    final List<Album> allAlbums = await _firebaseService.getAlbums();
    final List<Artist> allArtists = await _firebaseService.getArtists();

    final Map<String, String> artistIdToRegionMap = {
      for (var artist in allArtists) artist.id: artist.region
    };

    final List<Album> ethiopianAlbums = [];
    final List<Album> worldwideAlbums = [];

    for (var album in allAlbums) {
      if (artistIdToRegionMap[album.artistId] == 'Ethiopian') {
        ethiopianAlbums.add(album);
      } else {
        worldwideAlbums.add(album);
      }
    }

    return {
      'Ethiopian': ethiopianAlbums,
      'Worldwide': worldwideAlbums,
    };
  }

  void _refreshData() {
    setState(() {
      _albumsFuture = _loadAndCategorizeAlbums();
    });
  }

  void _navigateToAddAlbum() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAlbumScreen()),
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
          'Manage Albums',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
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
                Tab(text: '🇪🇹 Ethiopian Albums'),
                Tab(text: '🌍 Worldwide Albums'),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, List<Album>>>(
        future: _albumsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AdminUiKit.goldAccent),
            );
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load albums',
              description: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _refreshData,
            );
          }

          final categorizedAlbums = snapshot.data ?? {};

          return TabBarView(
            controller: _tabController,
            children: [
              _AlbumListTab(
                category: 'Ethiopian',
                albums: categorizedAlbums['Ethiopian'] ?? [],
                onDataChanged: _refreshData,
                onAddAlbum: _navigateToAddAlbum,
              ),
              _AlbumListTab(
                category: 'Worldwide',
                albums: categorizedAlbums['Worldwide'] ?? [],
                onDataChanged: _refreshData,
                onAddAlbum: _navigateToAddAlbum,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AdminUiKit.hapticMedium();
          _navigateToAddAlbum();
        },
        backgroundColor: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
        foregroundColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Add Album',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }
}

class _AlbumListTab extends StatefulWidget {
  final String category;
  final List<Album> albums;
  final VoidCallback onDataChanged;
  final VoidCallback onAddAlbum;

  const _AlbumListTab({
    required this.category,
    required this.albums,
    required this.onDataChanged,
    required this.onAddAlbum,
  });

  @override
  State<_AlbumListTab> createState() => _AlbumListTabState();
}

class _AlbumListTabState extends State<_AlbumListTab> {
  final FirebaseService _firebaseService = FirebaseService();
  late List<Album> _filteredAlbums;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedAlbumIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _filteredAlbums = widget.albums;
    _searchController.addListener(_filterAlbums);
  }

  @override
  void didUpdateWidget(covariant _AlbumListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albums != oldWidget.albums) {
      _filteredAlbums = widget.albums;
      _filterAlbums();
    }
  }

  void _filterAlbums() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredAlbums = widget.albums;
      } else {
        _filteredAlbums = widget.albums.where((album) =>
            album.title.toLowerCase().contains(query) ||
            album.artistName.toLowerCase().contains(query)).toList();
      }
    });
  }

  void _toggleSelection(String albumId) {
    AdminUiKit.hapticLight();
    setState(() {
      if (_selectedAlbumIds.contains(albumId)) {
        _selectedAlbumIds.remove(albumId);
      } else {
        _selectedAlbumIds.add(albumId);
      }
      if (_selectedAlbumIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _enterSelectionMode(String albumId) {
    AdminUiKit.hapticMedium();
    setState(() {
      _isSelectionMode = true;
      _selectedAlbumIds.add(albumId);
    });
  }

  void _exitSelectionMode() {
    AdminUiKit.hapticLight();
    setState(() {
      _isSelectionMode = false;
      _selectedAlbumIds.clear();
    });
  }

  Future<void> _deleteSelectedAlbums() async {
    final count = _selectedAlbumIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count Album(s)?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to permanently delete these $count album(s)? All attached songs will be affected.',
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
        final albumsToDelete = widget.albums
            .where((a) => _selectedAlbumIds.contains(a.id))
            .map((a) => a.title)
            .join(', ');

        await _firebaseService.deleteAlbums(_selectedAlbumIds.toList());

        if (authProvider.currentUser != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator?.fullName ?? 'Admin',
            action: 'DELETE_ALBUMS',
            details: 'Deleted $count album(s): $albumsToDelete',
          );
        }

        if (mounted) {
          CustomSnackbar.show(context, 'Successfully deleted $count album(s).');
          _exitSelectionMode();
          widget.onDataChanged();
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Error deleting albums: $e', isError: true);
        }
      }
    }
  }

  void _editAlbum(Album album) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditAlbumScreen(album: album)),
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
                        '${_selectedAlbumIds.length} Selected',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : AdminUiKit.roseRed,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _selectedAlbumIds.isNotEmpty ? _deleteSelectedAlbums : null,
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
                  hintText: 'Search by album title or artist...',
                  onChanged: (_) => _filterAlbums(),
                ),
        ),

        Expanded(
          child: _filteredAlbums.isEmpty
              ? AdminEmptyState(
                  icon: Icons.album_rounded,
                  title: 'No Albums Found',
                  description: _searchController.text.isNotEmpty
                      ? 'No matching albums for "${_searchController.text}".'
                      : 'There are no ${widget.category.toLowerCase()} albums added yet.',
                  actionLabel: _searchController.text.isEmpty ? 'Add Album' : null,
                  onAction: _searchController.text.isEmpty ? widget.onAddAlbum : null,
                )
              : RefreshIndicator(
                  color: AdminUiKit.goldAccent,
                  onRefresh: () async => widget.onDataChanged(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredAlbums.length,
                    itemBuilder: (context, index) {
                      final album = _filteredAlbums[index];
                      final isSelected = _selectedAlbumIds.contains(album.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: AdminGlassCard(
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(album.id);
                            } else {
                              _editAlbum(album);
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              _enterSelectionMode(album.id);
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
                              // Cover Art
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                  child: album.coverImageUrl.isNotEmpty
                                      ? Image.network(
                                          album.coverImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.album_rounded,
                                            size: 28,
                                            color: AdminUiKit.goldAccent,
                                          ),
                                        )
                                      : Icon(
                                          Icons.album_rounded,
                                          size: 28,
                                          color: AdminUiKit.goldAccent,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Metadata
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      album.title,
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
                                      album.artistName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (album.year != null || album.volume != null) ...[
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          if (album.year != null)
                                            Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AdminUiKit.royalBlue.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '📅 ${album.year}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AdminUiKit.royalBlue,
                                                ),
                                              ),
                                            ),
                                          if (album.volume != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AdminUiKit.goldAccent.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Vol. ${album.volume}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AdminUiKit.goldHighlight : AdminUiKit.primaryNavy,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              if (_isSelectionMode)
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AdminUiKit.goldAccent,
                                  checkColor: AdminUiKit.primaryNavy,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (_) => _toggleSelection(album.id),
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