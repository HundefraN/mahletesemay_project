import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:mahlete_semay_project/widgets/searchable_dropdown.dart';
import 'package:provider/provider.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../providers/auth_proveider.dart';

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
  final _otherScaleController = TextEditingController();
  final _otherRhythmController = TextEditingController();

  bool _isSaving = false;

  Artist? _selectedArtist;
  Album? _selectedAlbum;
  String? _selectedScale;
  String? _selectedRhythm;

  void _onArtistChanged(Artist? artist) {
    if (artist == null) return;
    setState(() {
      _selectedArtist = artist;
      _selectedAlbum = null;
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final finalScale = _selectedScale == 'Other'
          ? _otherScaleController.text
          : _selectedScale;
      final finalRhythm = _selectedRhythm == 'Other' ? _otherRhythmController
          .text : _selectedRhythm;

      final newSong = Song(
        id: '',
        title: _titleController.text,
        lyrics: _lyricsController.text,
        scale: finalScale,
        rhythm: finalRhythm,
        artistId: _selectedArtist!.id,
        artistName: _selectedArtist!.name,
        albumId: _selectedAlbum!.id,
        albumTitle: _selectedAlbum!.title,
        createdAt: Timestamp.now(),
        viewCount: 0,
      );
      await _firebaseService.addSong(newSong);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentModerator != null) {
        _firebaseService.logActivity(
          moderatorId: authProvider.currentUser!.uid,
          moderatorName: authProvider.currentModerator!.fullName,
          action: 'CREATE_SONG',
          details: 'Added new song: ${_titleController.text.trim()}',
        );
      }

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context, 'Song added successfully!');
      }
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Song')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              context,
              title: 'Song Association',
              children: [
                SearchableDropdown<Artist>(
                  label: '1. Select Artist *',
                  icon: Icons.person_search_outlined,
                  selectedItem: _selectedArtist,
                  onChanged: _onArtistChanged,
                  validator: (artist) => artist == null ? 'Required' : null,
                  onFind: (filter) async {
                    final artists = await _firebaseService.getArtists();
                    return artists.where((a) => a.name.toLowerCase().contains(filter.toLowerCase())).toList();
                  },
                  dropdownBuilder: (artist) => _buildArtistDropdownItem(artist),
                  itemBuilder: (artist) => ListTile(leading: CircleAvatar(backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null, child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 16) : null), title: Text(artist.name)),
                ),
                const SizedBox(height: 16),
                SearchableDropdown<Album>(
                  label: '2. Select Album *',
                  icon: Icons.album_outlined,
                  isEnabled: _selectedArtist != null,
                  selectedItem: _selectedAlbum,
                  onChanged: (album) => setState(() => _selectedAlbum = album),
                  validator: (album) => album == null ? 'Required' : null,
                  onFind: (filter) async {
                    if (_selectedArtist == null) return [];
                    final albums = await _firebaseService.getAlbums();
                    return albums.where((a) => a.artistId == _selectedArtist!.id && a.title.toLowerCase().contains(filter.toLowerCase())).toList();
                  },
                  dropdownBuilder: (album) => _buildAlbumDropdownItem(album),
                  itemBuilder: (album) => ListTile(leading: CircleAvatar(backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null, child: album.coverImageUrl.isEmpty ? const Icon(Icons.album, size: 16) : null), title: Text(album.title)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Song Details',
              children: [
                TextFormField(controller: _titleController, decoration: _inputDecoration('Song Title *', Icons.music_note_outlined), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(value: _selectedScale, decoration: _inputDecoration('Scale (Optional)', Icons.queue_music_outlined), items: scaleMenuItems.map((scale) => DropdownMenuItem(value: scale, child: Text(scale))).toList(), onChanged: (value) => setState(() => _selectedScale = value)),
                if (_selectedScale == 'Other') ...[const SizedBox(height: 16), TextFormField(controller: _otherScaleController, decoration: _inputDecoration('Enter Custom Scale', Icons.edit), validator: (v) => v!.isEmpty ? 'Required' : null)],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(value: _selectedRhythm, decoration: _inputDecoration('Rhythm (Optional)', Icons.timelapse_outlined), items: rhythmMenuItems.map((rhythm) => DropdownMenuItem(value: rhythm, child: Text(rhythm))).toList(), onChanged: (value) => setState(() => _selectedRhythm = value)),
                if (_selectedRhythm == 'Other') ...[const SizedBox(height: 16), TextFormField(controller: _otherRhythmController, decoration: _inputDecoration('Enter Custom Rhythm', Icons.edit), validator: (v) => v!.isEmpty ? 'Required' : null)],
                const SizedBox(height: 16),
                TextFormField(controller: _lyricsController, decoration: _inputDecoration('Lyrics *', Icons.text_fields_outlined, alignLabel: true), minLines: 8, maxLines: 15, validator: (v) => v!.isEmpty ? 'Required' : null),
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
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height: 24), ...children])));
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(labelText: label, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), prefixIcon: Icon(icon), alignLabelWithHint: alignLabel);
  }

  Widget _buildArtistDropdownItem(Artist artist) => Row(children: [CircleAvatar(radius: 12, backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null, child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 12) : null), const SizedBox(width: 12), Text(artist.name)]);

  Widget _buildAlbumDropdownItem(Album album) => Row(children: [CircleAvatar(radius: 12, backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null, child: album.coverImageUrl.isEmpty ? const Icon(Icons.album, size: 12) : null), const SizedBox(width: 12), Text(album.title)]);
}