import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:provider/provider.dart';
import '../../models/artist_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../providers/auth_proveider.dart';
import 'edit_artists_screen.dart';

class ManageArtistsScreen extends StatefulWidget {
  const ManageArtistsScreen({super.key});

  @override
  State<ManageArtistsScreen> createState() => _ManageArtistsScreenState();
}

class _ManageArtistsScreenState extends State<ManageArtistsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<List<Artist>> _artistsFuture;
  List<Artist> _allArtists = [];
  List<Artist> _filteredArtists = [];
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedArtistIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _artistsFuture = _loadArtists();
    _searchController.addListener(_filterArtists);
  }

  Future<List<Artist>> _loadArtists() async {
    _allArtists = await _firebaseService.getArtists();
    _filteredArtists = _allArtists;
    return _allArtists;
  }

  void _filterArtists() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredArtists = _allArtists.where((artist) {
        return artist.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleSelection(String artistId) {
    setState(() {
      if (_selectedArtistIds.contains(artistId)) {
        _selectedArtistIds.remove(artistId);
      } else {
        _selectedArtistIds.add(artistId);
      }
      if (_selectedArtistIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _enterSelectionMode(String artistId) {
    setState(() {
      _isSelectionMode = true;
      _selectedArtistIds.add(artistId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedArtistIds.clear();
    });
  }

  Future<void> _deleteSelectedArtists() async {
    final shouldDelete = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirm Deletion'), content: Text('Are you sure you want to delete ${_selectedArtistIds.length} artist(s)? This action cannot be undone.'), actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)), FilledButton(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red))]));
    if (shouldDelete == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final artistsToDelete = _allArtists.where((a) => _selectedArtistIds.contains(a.id)).map((a) => a.name).join(', ');

        await _firebaseService.deleteArtists(_selectedArtistIds.toList());

        _firebaseService.logActivity(
          moderatorId: authProvider.currentUser!.uid,
          moderatorName: authProvider.currentModerator!.fullName,
          action: 'DELETE_ARTISTS',
          details: 'Deleted ${_selectedArtistIds.length} artist(s): $artistsToDelete',
        );

        CustomSnackbar.show(context, 'Successfully deleted artist(s).');
        _exitSelectionMode();
        setState(() {
          _artistsFuture = _loadArtists();
        });
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: FutureBuilder<List<Artist>>(
          future: _artistsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No artists found.'));
            }

            _allArtists = snapshot.data!;
            final ethiopianArtists = _allArtists.where((a) => a.region == 'Ethiopian').toList();
            final worldwideArtists = _allArtists.where((a) => a.region == 'Worldwide').toList();

            return Column(
              children: [
                if (!_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(controller: _searchController, decoration: InputDecoration(labelText: 'Search by Artist Name', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Ethiopian'),
                    Tab(text: 'Worldwide'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildArtistList(ethiopianArtists),
                      _buildArtistList(worldwideArtists),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildArtistList(List<Artist> artists) {
    final query = _searchController.text.toLowerCase();
    final displayList = artists.where((artist) => artist.name.toLowerCase().contains(query)).toList();

    if (displayList.isEmpty) {
      return const Center(child: Text('No artists found.'));
    }

    return ListView.builder(
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final artist = displayList[index];
        final isSelected = _selectedArtistIds.contains(artist.id);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
          child: ListTile(
            leading: CircleAvatar(backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null, child: artist.imageUrl.isEmpty ? const Icon(Icons.person) : null),
            title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(artist.region),
            trailing: _isSelectionMode ? Checkbox(value: isSelected, onChanged: (value) => _toggleSelection(artist.id)) : const Icon(Icons.edit_outlined),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(artist.id);
              } else {
                _editArtist(artist);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                _enterSelectionMode(artist.id);
              }
            },
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        title: Text('${_selectedArtistIds.length} selected'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _selectedArtistIds.isNotEmpty ? _deleteSelectedArtists : null)],
      );
    } else {
      return AppBar(title: const Text('Manage Artists'));
    }
  }

  void _editArtist(Artist artist) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditArtistScreen(artist: artist)));
    if (result == true) {
      setState(() { _artistsFuture = _loadArtists(); });
    }
  }
}