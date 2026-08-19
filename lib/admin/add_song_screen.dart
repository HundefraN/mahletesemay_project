import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/searchable_dropdown.dart';
import 'widgets/admin_ui_kit.dart';

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
  bool _isSingle = false;

  Artist? _selectedArtist;
  Album? _selectedAlbum;
  String? _selectedScale;
  String? _selectedRhythm;

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _otherScaleController.dispose();
    _otherRhythmController.dispose();
    super.dispose();
  }

  Future<void> _saveRecentArtist(Artist artist) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentArtistsJson = prefs.getStringList('recentArtists') ?? [];

    final artistMap = {'id': artist.id, 'name': artist.name, 'imageUrl': artist.imageUrl, 'region': artist.region};
    String artistJson = json.encode(artistMap);

    recentArtistsJson.removeWhere((item) => json.decode(item)['id'] == artist.id);
    recentArtistsJson.insert(0, artistJson);

    if (recentArtistsJson.length > 5) {
      recentArtistsJson = recentArtistsJson.sublist(0, 5);
    }

    await prefs.setStringList('recentArtists', recentArtistsJson);
  }

  Future<List<Artist>> _getRecentArtists() async {
    final prefs = await SharedPreferences.getInstance();
    final recentArtistsJson = prefs.getStringList('recentArtists') ?? [];
    return recentArtistsJson.map((jsonString) {
      final map = json.decode(jsonString);
      return Artist(id: map['id'], name: map['name'], imageUrl: map['imageUrl'], region: map['region']);
    }).toList();
  }

  void _onArtistChanged(Artist? artist) {
    setState(() {
      _selectedArtist = artist;
      _selectedAlbum = null;
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        if (_selectedArtist != null) {
          await _saveRecentArtist(_selectedArtist!);
        }

        final finalScale = _selectedScale == 'Other' ? _otherScaleController.text.trim() : _selectedScale;
        final finalRhythm = _selectedRhythm == 'Other' ? _otherRhythmController.text.trim() : _selectedRhythm;

        final newSong = Song(
          id: '',
          title: _titleController.text.trim(),
          lyrics: _lyricsController.text.trim(),
          scale: finalScale,
          rhythm: finalRhythm,
          artistId: _isSingle ? (_selectedArtist?.id ?? singlesArtistId) : _selectedArtist!.id,
          artistName: _isSingle ? (_selectedArtist?.name ?? "Various Artists") : _selectedArtist!.name,
          albumId: _isSingle ? singlesAlbumId : _selectedAlbum!.id,
          albumTitle: _isSingle ? "Singles" : _selectedAlbum!.title,
          createdAt: DateTime.now(),
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

        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Song added successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Failed to save song: $e', isError: true);
        }
      }
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
          'Add New Song',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          physics: const BouncingScrollPhysics(),
          children: [
            // Section 1: Association
            const AdminSectionHeader(
              title: 'Song Association',
              icon: Icons.link_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Single Switch Tile
                  Container(
                    decoration: BoxDecoration(
                      color: _isSingle
                          ? AdminUiKit.goldAccent.withOpacity(0.12)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSingle ? AdminUiKit.goldAccent.withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Is this a Single Release?',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      subtitle: Text(
                        'For songs released independently without an album.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11),
                      ),
                      value: _isSingle,
                      activeColor: AdminUiKit.goldAccent,
                      onChanged: (value) {
                        AdminUiKit.hapticLight();
                        setState(() => _isSingle = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Artist Dropdown
                  SearchableDropdown<Artist>(
                    label: _isSingle ? 'Select Artist (Optional)' : '1. Select Artist *',
                    icon: Icons.person_search_rounded,
                    selectedItem: _selectedArtist,
                    onChanged: _onArtistChanged,
                    validator: (artist) => !_isSingle && artist == null ? 'Please select an artist' : null,
                    itemToString: (artist) => artist.name,
                    onFindWithHeaders: (filter) async {
                      final recent = await _getRecentArtists();
                      final all = await _firebaseService.getArtists();

                      final filteredRecent = recent.where((a) => a.name.toLowerCase().contains(filter.toLowerCase())).toList();
                      final filteredAll = all.where((a) => a.name.toLowerCase().contains(filter.toLowerCase()) && !recent.any((r) => r.id == a.id)).toList();

                      Map<String, List<Artist>> categorized = {};
                      if (filteredRecent.isNotEmpty) categorized['Recently Used'] = filteredRecent;
                      if (filteredAll.isNotEmpty) categorized['All Artists'] = filteredAll;

                      return categorized;
                    },
                    dropdownBuilder: (artist) => _buildArtistDropdownItem(artist),
                    itemBuilder: (artist) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                        child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
                      ),
                      title: Text(artist.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Album Dropdown
                  AnimatedOpacity(
                    opacity: _isSingle ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: SearchableDropdown<Album>(
                      label: '2. Select Album *',
                      icon: Icons.album_rounded,
                      isEnabled: !_isSingle && _selectedArtist != null,
                      selectedItem: _selectedAlbum,
                      onChanged: (album) => setState(() => _selectedAlbum = album),
                      validator: (album) => !_isSingle && album == null ? 'Please select an album' : null,
                      itemToString: (album) => album.title,
                      onFind: (filter) async {
                        if (_selectedArtist == null) return [];
                        final albums = await _firebaseService.getAlbums();
                        return albums.where((a) => a.artistId == _selectedArtist!.id && a.title.toLowerCase().contains(filter.toLowerCase())).toList();
                      },
                      dropdownBuilder: (album) => _buildAlbumDropdownItem(album),
                      itemBuilder: (album) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
                          child: album.coverImageUrl.isEmpty ? const Icon(Icons.album, size: 14) : null,
                        ),
                        title: Text(album.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Section 2: Song Details & Lyrics
            const AdminSectionHeader(
              title: 'Song Details & Metadata',
              icon: Icons.queue_music_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                    decoration: _inputDecoration('Song Title *', Icons.music_note_rounded),
                    validator: (v) => v!.trim().isEmpty ? 'Song title is required' : null,
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _selectedScale,
                    decoration: _inputDecoration('Musical Scale (Optional)', Icons.graphic_eq_rounded),
                    items: scaleMenuItems.map((scale) => DropdownMenuItem(value: scale, child: Text(scale, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                    onChanged: (value) => setState(() => _selectedScale = value),
                  ),
                  if (_selectedScale == 'Other') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _otherScaleController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
                      decoration: _inputDecoration('Enter Custom Scale', Icons.edit_note_rounded),
                      validator: (v) => v!.trim().isEmpty ? 'Please specify custom scale' : null,
                    ),
                  ],
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _selectedRhythm,
                    decoration: _inputDecoration('Rhythm Pattern (Optional)', Icons.speed_rounded),
                    items: rhythmMenuItems.map((rhythm) => DropdownMenuItem(value: rhythm, child: Text(rhythm, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                    onChanged: (value) => setState(() => _selectedRhythm = value),
                  ),
                  if (_selectedRhythm == 'Other') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _otherRhythmController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
                      decoration: _inputDecoration('Enter Custom Rhythm', Icons.edit_note_rounded),
                      validator: (v) => v!.trim().isEmpty ? 'Please specify custom rhythm' : null,
                    ),
                  ],
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _lyricsController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.4),
                    decoration: _inputDecoration('Song Lyrics *', Icons.text_fields_rounded, alignLabel: true),
                    minLines: 5,
                    maxLines: 15,
                    validator: (v) => v!.trim().isEmpty ? 'Lyrics are required' : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Submit Button
            AdminPrimaryButton(
              label: 'Save & Publish Song',
              icon: Icons.check_circle_rounded,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      prefixIcon: Icon(icon, size: 18),
      alignLabelWithHint: alignLabel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildArtistDropdownItem(Artist artist) => Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
            child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 11) : null,
          ),
          const SizedBox(width: 8),
          Text(artist.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );

  Widget _buildAlbumDropdownItem(Album album) => Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
            child: album.coverImageUrl.isEmpty ? const Icon(Icons.album, size: 11) : null,
          ),
          const SizedBox(width: 8),
          Text(album.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );
}