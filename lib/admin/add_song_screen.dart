import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../services/firebase_service.dart';

class AddSongScreen extends StatefulWidget {
  const AddSongScreen({super.key});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _scaleController = TextEditingController();
  final _scaleDegreeController = TextEditingController();

  bool _isSaving = false;
  bool _isDataLoading = true;

  List<Artist> _artists = [];
  List<Album> _allAlbums = [];
  List<Album> _filteredAlbums = [];

  Artist? _selectedArtist;
  Album? _selectedAlbum;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final artists = await _firebaseService.getArtists();
    final albums = await _firebaseService.getAlbums();
    if(mounted) {
      setState(() {
        _artists = artists;
        _allAlbums = albums;
        _isDataLoading = false;
      });
    }
  }

  void _onArtistChanged(Artist? artist) {
    if (artist == null) return;
    setState(() {
      _selectedArtist = artist;
      _selectedAlbum = null;
      _filteredAlbums = _allAlbums.where((album) => album.artistId == artist.id).toList();
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedArtist == null || _selectedAlbum == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both artist and album')));
        return;
      }
      setState(() => _isSaving = true);
      final newSong = Song(
        id: '',
        title: _titleController.text,
        lyrics: _lyricsController.text,
        scale: _scaleController.text,
        scaleDegree: int.parse(_scaleDegreeController.text),
        artistId: _selectedArtist!.id,
        artistName: _selectedArtist!.name,
        albumId: _selectedAlbum!.id,
        albumTitle: _selectedAlbum!.title,
        createdAt: Timestamp.now(),
        viewCount: 0,
      );
      await _firebaseService.addSong(newSong);
      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song added successfully!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Song')),
      body: _isSaving || _isDataLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait...'),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              context,
              title: 'Song Association',
              children: [
                DropdownButtonFormField<Artist>(
                  value: _selectedArtist,
                  decoration: _inputDecoration('1. Select Artist', Icons.person_search_outlined),
                  isExpanded: true,
                  items: _artists.map((artist) => DropdownMenuItem(
                    value: artist,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                          child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(artist.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  )).toList(),
                  onChanged: _onArtistChanged,
                  validator: (value) => value == null ? 'Please select an artist' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Album>(
                  value: _selectedAlbum,
                  decoration: _inputDecoration('2. Select Album', Icons.album_outlined),
                  isExpanded: true,
                  items: _filteredAlbums.map((album) => DropdownMenuItem(
                    value: album,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
                          child: album.coverImageUrl.isEmpty ? const Icon(Icons.album, size: 16) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(album.title, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (album) {
                    setState(() => _selectedAlbum = album);
                  },
                  validator: (value) => value == null ? 'Please select an album' : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Song Details',
              children: [
                TextFormField(controller: _titleController, decoration: _inputDecoration('Song Title', Icons.music_note_outlined), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(controller: _scaleController, decoration: _inputDecoration('Scale', Icons.queue_music_outlined), validator: (v) => v!.isEmpty ? 'Required' : null),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(controller: _scaleDegreeController, decoration: _inputDecoration('Scale Degree', Icons.format_list_numbered), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? 'Required' : null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _lyricsController, decoration: _inputDecoration('Lyrics', Icons.text_fields_outlined, alignLabel: true), minLines: 8, maxLines: 15, validator: (v) => v!.isEmpty ? 'Required' : null),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _submit, child: const Text('Save Song'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      prefixIcon: Icon(icon),
      alignLabelWithHint: alignLabel,
    );
  }
}