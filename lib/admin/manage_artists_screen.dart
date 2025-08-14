import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import '../../models/artist_model.dart';
import '../../services/firebase_service.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Artists'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Artist Name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Artist>>(
              future: _artistsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) => const ListTileShimmer(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (_filteredArtists.isEmpty) {
                  return const Center(child: Text('No artists found.'));
                }

                return ListView.builder(
                  itemCount: _filteredArtists.length,
                  itemBuilder: (context, index) {
                    final artist = _filteredArtists[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                          child: artist.imageUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(artist.region),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditArtistScreen(artist: artist)),
                          );
                          if (result == true) {
                            setState(() {
                              _artistsFuture = _loadArtists();
                            });
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}