import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../providers/auth_proveider.dart';
import 'edit_songs_screen.dart';

class ManageSongsScreen extends StatefulWidget {
  const ManageSongsScreen({super.key});

  @override
  State<ManageSongsScreen> createState() => _ManageSongsScreenState();
}

class _ManageSongsScreenState extends State<ManageSongsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<Map<String, List<Song>>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture = _loadAndCategorizeSongs();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Songs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ethiopian'),
              Tab(text: 'Worldwide'),
            ],
          ),
        ),
        body: FutureBuilder<Map<String, List<Song>>>(
          future: _songsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No songs found.'));
            }

            final categorizedSongs = snapshot.data!;

            return TabBarView(
              children: [
                _SongListTab(
                  songs: categorizedSongs['Ethiopian'] ?? [],
                  onDataChanged: _refreshData,
                ),
                _SongListTab(
                  songs: categorizedSongs['Worldwide'] ?? [],
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

class _SongListTab extends StatefulWidget {
  final List<Song> songs;
  final VoidCallback onDataChanged;

  const _SongListTab({required this.songs, required this.onDataChanged});

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
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = widget.songs.where((song) =>
      song.title.toLowerCase().contains(query) ||
          song.artistName.toLowerCase().contains(query) ||
          song.lyrics.toLowerCase().contains(query)).toList();
    });
  }

  void _toggleSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) _selectedSongIds.remove(songId);
      else _selectedSongIds.add(songId);
      if (_selectedSongIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _enterSelectionMode(String songId) {
    setState(() {
      _isSelectionMode = true;
      _selectedSongIds.add(songId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSongIds.clear();
    });
  }

  Future<void> _deleteSelectedSongs() async {
    final shouldDelete = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirm Deletion'), content: Text('Are you sure you want to delete ${_selectedSongIds.length} song(s)? This cannot be undone.'), actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)), FilledButton(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red))]));
    if (shouldDelete == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final songsToDelete = widget.songs.where((s) => _selectedSongIds.contains(s.id)).map((s) => s.title).join(', ');

        await _firebaseService.deleteSongs(_selectedSongIds.toList());

        _firebaseService.logActivity(
          moderatorId: authProvider.currentUser!.uid,
          moderatorName: authProvider.currentModerator!.fullName,
          action: 'DELETE_SONGS',
          details: 'Deleted ${_selectedSongIds.length} song(s): $songsToDelete',
        );

        CustomSnackbar.show(context, 'Successfully deleted song(s).');
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
            child: TextField(controller: _searchController, decoration: InputDecoration(labelText: 'Search by Title, Artist, or Lyrics', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ),
        Expanded(
          child: _filteredSongs.isEmpty
              ? const Center(child: Text('No songs found.'))
              : ListView.builder(
            itemCount: _filteredSongs.length,
            itemBuilder: (context, index) {
              final song = _filteredSongs[index];
              final isSelected = _selectedSongIds.contains(song.id);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.music_note)),
                  title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${song.artistName} - ${song.albumTitle}'),
                  trailing: _isSelectionMode ? Checkbox(value: isSelected, onChanged: (value) => _toggleSelection(song.id)) : const Icon(Icons.edit_outlined),
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
          Text('${_selectedSongIds.length} selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _selectedSongIds.isNotEmpty ? _deleteSelectedSongs : null),
        ],
      ),
    );
  }

  void _editSong(Song song) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditSongScreen(song: song)));
    if (result == true) {
      widget.onDataChanged();
    }
  }
}