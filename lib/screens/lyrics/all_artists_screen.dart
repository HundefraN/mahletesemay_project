import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/artist_model.dart';
import '../../providers/song_provider.dart';
import 'albums_list_screen.dart';

class AllArtistsScreen extends StatefulWidget {
  final String title;
  final String region;

  const AllArtistsScreen({super.key, required this.title, required this.region});

  @override
  State<AllArtistsScreen> createState() => _AllArtistsScreenState();
}

class _AllArtistsScreenState extends State<AllArtistsScreen> {
  late List<Artist> _allArtistsInRegion;
  List<Artist> _filteredArtists = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    _allArtistsInRegion = songProvider.getRecommendedArtists(region: widget.region);
    _filteredArtists = _allArtistsInRegion;
    _searchController.addListener(_filterArtists);
  }

  void _filterArtists() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredArtists = _allArtistsInRegion.where((artist) {
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
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for an artist...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredArtists.length,
              itemBuilder: (context, index) {
                final artist = _filteredArtists[index];
                return ListTile(
                  leading: Hero(
                    tag: artist.id,
                    child: CircleAvatar(
                      backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                      child: artist.imageUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                  ),
                  title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumsListScreen(
                          artist: artist,
                          albums: songProvider.getAlbumsByArtist(artist.id),
                          artistHeroTag: artist.id,
                        ),
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