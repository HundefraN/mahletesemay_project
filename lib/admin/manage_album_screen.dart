import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:provider/provider.dart';
import '../../models/album_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../providers/auth_proveider.dart';
import 'edit_album_screen.dart';

class ManageAlbumsScreen extends StatefulWidget {
  const ManageAlbumsScreen({super.key});

  @override
  State<ManageAlbumsScreen> createState() => _ManageAlbumsScreenState();
}

class _ManageAlbumsScreenState extends State<ManageAlbumsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<Map<String, List<Album>>> _albumsFuture;

  @override
  void initState() {
    super.initState();
    _albumsFuture = _loadAndCategorizeAlbums();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Albums'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ethiopian'),
              Tab(text: 'Worldwide'),
            ],
          ),
        ),
        body: FutureBuilder<Map<String, List<Album>>>(
          future: _albumsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No albums found.'));
            }

            final categorizedAlbums = snapshot.data!;

            return TabBarView(
              children: [
                _AlbumListTab(
                  albums: categorizedAlbums['Ethiopian'] ?? [],
                  onDataChanged: _refreshData,
                ),
                _AlbumListTab(
                  albums: categorizedAlbums['Worldwide'] ?? [],
                  onDataChanged: _refreshData,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlbumListTab extends StatefulWidget {
  final List<Album> albums;
  final VoidCallback onDataChanged;

  const _AlbumListTab({required this.albums, required this.onDataChanged});

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
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAlbums = widget.albums.where((album) =>
      album.title.toLowerCase().contains(query) ||
          album.artistName.toLowerCase().contains(query)).toList();
    });
  }

  void _toggleSelection(String albumId) {
    setState(() {
      if (_selectedAlbumIds.contains(albumId)) _selectedAlbumIds.remove(albumId);
      else _selectedAlbumIds.add(albumId);
      if (_selectedAlbumIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _enterSelectionMode(String albumId) {
    setState(() {
      _isSelectionMode = true;
      _selectedAlbumIds.add(albumId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAlbumIds.clear();
    });
  }

  Future<void> _deleteSelectedAlbums() async {
    final shouldDelete = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirm Deletion'), content: Text('Are you sure you want to delete ${_selectedAlbumIds.length} album(s)? This cannot be undone.'), actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)), FilledButton(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red))]));
    if (shouldDelete == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final albumsToDelete = widget.albums.where((a) => _selectedAlbumIds.contains(a.id)).map((a) => a.title).join(', ');

        await _firebaseService.deleteAlbums(_selectedAlbumIds.toList());

        _firebaseService.logActivity(
          moderatorId: authProvider.currentUser!.uid,
          moderatorName: authProvider.currentModerator!.fullName,
          action: 'DELETE_ALBUMS',
          details: 'Deleted ${_selectedAlbumIds.length} album(s): $albumsToDelete',
        );

        CustomSnackbar.show(context, 'Successfully deleted album(s).');
        _exitSelectionMode();
        widget.onDataChanged();
      } catch (e) {
        CustomSnackbar.show(context, 'An error occurred during deletion.', isError: true);
      }
    }
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSelectionMode)
          _buildSelectionAppBar()
        else
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(controller: _searchController, decoration: InputDecoration(labelText: 'Search by Album or Artist', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ),
        Expanded(
          child: _filteredAlbums.isEmpty
              ? const Center(child: Text('No albums found.'))
              : ListView.builder(
            itemCount: _filteredAlbums.length,
            itemBuilder: (context, index) {
              final album = _filteredAlbums[index];
              final isSelected = _selectedAlbumIds.contains(album.id);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                child: ListTile(
                  leading: CircleAvatar(backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null, child: album.coverImageUrl.isEmpty ? const Icon(Icons.album) : null),
                  title: Text(album.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(album.artistName),
                  trailing: _isSelectionMode ? Checkbox(value: isSelected, onChanged: (value) => _toggleSelection(album.id)) : const Icon(Icons.edit_outlined),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionAppBar() {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode),
          Text('${_selectedAlbumIds.length} selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _selectedAlbumIds.isNotEmpty ? _deleteSelectedAlbums : null),
        ],
      ),
    );
  }

  void _editAlbum(Album album) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditAlbumScreen(album: album)));
    if (result == true) {
      widget.onDataChanged();
    }
  }
}