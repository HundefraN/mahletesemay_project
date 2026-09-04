import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/search_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/searchable_dropdown.dart';
import 'widgets/admin_ui_kit.dart';

class EditSongScreen extends StatefulWidget {
  final Song song;
  const EditSongScreen({super.key, required this.song});

  @override
  State<EditSongScreen> createState() => _EditSongScreenState();
}

class _EditSongScreenState extends State<EditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  late TextEditingController _titleController;
  late TextEditingController _lyricsController;
  late TextEditingController _otherScaleController;
  late TextEditingController _otherRhythmController;

  bool _isLoading = false;
  late bool _isSingle;
  String? _selectedScale;
  String? _selectedRhythm;
  Artist? _selectedArtist;
  Album? _selectedAlbum;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _lyricsController = TextEditingController(text: widget.song.lyrics);
    _isSingle = widget.song.albumId == singlesAlbumId;

    if (widget.song.artistId.isNotEmpty && widget.song.artistId != singlesArtistId) {
      _selectedArtist = Artist(
        id: widget.song.artistId,
        name: widget.song.artistName,
        imageUrl: '',
        region: '',
      );
    }

    if (widget.song.albumId.isNotEmpty && widget.song.albumId != singlesAlbumId) {
      _selectedAlbum = Album(
        id: widget.song.albumId,
        title: widget.song.albumTitle,
        artistId: widget.song.artistId,
        artistName: widget.song.artistName,
        coverImageUrl: '',
      );
    }

    if (widget.song.scale != null && widget.song.scale!.isNotEmpty) {
      if (scaleMenuItems.contains(widget.song.scale)) {
        _selectedScale = widget.song.scale;
        _otherScaleController = TextEditingController();
      } else {
        _selectedScale = 'Other';
        _otherScaleController = TextEditingController(text: widget.song.scale);
      }
    } else {
      _otherScaleController = TextEditingController();
    }

    if (widget.song.rhythm != null && widget.song.rhythm!.isNotEmpty) {
      if (rhythmMenuItems.contains(widget.song.rhythm)) {
        _selectedRhythm = widget.song.rhythm;
        _otherRhythmController = TextEditingController();
      } else {
        _selectedRhythm = 'Other';
        _otherRhythmController = TextEditingController(text: widget.song.rhythm);
      }
    } else {
      _otherRhythmController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _otherScaleController.dispose();
    _otherRhythmController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final finalScale = _selectedScale == 'Other' ? _otherScaleController.text.trim() : _selectedScale;
        final finalRhythm = _selectedRhythm == 'Other' ? _otherRhythmController.text.trim() : _selectedRhythm;

        final artistId = _isSingle ? (_selectedArtist?.id ?? singlesArtistId) : (_selectedArtist?.id ?? widget.song.artistId);
        final artistName = _isSingle ? (_selectedArtist?.name ?? "Various Artists") : (_selectedArtist?.name ?? widget.song.artistName);
        final albumId = _isSingle ? singlesAlbumId : (_selectedAlbum?.id ?? widget.song.albumId);
        final albumTitle = _isSingle ? "Singles" : (_selectedAlbum?.title ?? widget.song.albumTitle);

        final Map<String, dynamic> updatedData = {
          'title': _titleController.text.trim(),
          'lyrics': _lyricsController.text.trim(),
          'scale': finalScale,
          'rhythm': finalRhythm,
          'artistId': artistId,
          'artistName': artistName,
          'albumId': albumId,
          'albumTitle': albumTitle,
        };

        await _firebaseService.updateSong(widget.song.id, updatedData);
        if (!mounted) return;

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'UPDATE_SONG',
            details: 'Updated song: ${_titleController.text.trim()}',
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Song updated successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          CustomSnackbar.show(context, 'Failed to update song: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteSong() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)?.deleteSongPrompt ?? 'Delete Song?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(AppLocalizations.of(context)?.deleteSongConfirm(widget.song.title) ?? 'Are you sure you want to delete "${widget.song.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context)?.deleteAction ?? 'Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);
      try {
        await _firebaseService.deleteSongs([widget.song.id]);
        if (!mounted) return;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator?.fullName ?? 'Admin',
            action: 'DELETE_SONG',
            details: 'Deleted song: ${widget.song.title}',
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Song deleted.');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          CustomSnackbar.show(context, 'Error deleting song: $e', isError: true);
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
          'Edit Song',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AdminUiKit.roseRed, size: 20),
            tooltip: 'Delete Song',
            onPressed: _deleteSong,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            physics: const BouncingScrollPhysics(),
            children: [
            // Section 1: Association
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.songAssociationSection ?? 'Song Association',
              icon: Icons.link_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _isSingle
                          ? AdminUiKit.goldAccent.withValues(alpha: 0.12)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSingle ? AdminUiKit.goldAccent.withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Is this a Single Release?',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        'For songs not part of an official album.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11),
                      ),
                      value: _isSingle,
                      activeThumbColor: AdminUiKit.goldAccent,
                      onChanged: (value) {
                        AdminUiKit.hapticLight();
                        setState(() => _isSingle = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  SearchableDropdown<Artist>(
                    label: _isSingle ? 'Select Artist (Optional)' : '1. Select Artist *',
                    icon: Icons.person_search_rounded,
                    selectedItem: _selectedArtist,
                    onChanged: (artist) {
                      setState(() {
                        _selectedArtist = artist;
                        _selectedAlbum = null;
                      });
                    },
                    validator: (artist) => !_isSingle && artist == null ? 'Please select an artist' : null,
                    itemToString: (artist) => artist.name,
                    onFind: (filter) async {
                      final artists = await _firebaseService.getArtists();
                      return SearchService().filterArtists(query: filter, artists: artists);
                    },
                    dropdownBuilder: (artist) => Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                          child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 11) : null,
                        ),
                        const SizedBox(width: 8),
                        Text(artist.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
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

                  AnimatedOpacity(
                    opacity: _isSingle ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: SearchableDropdown<Album>(
                      label: AppLocalizations.of(context)?.selectAlbumPrompt ?? '2. Select Album *',
                      icon: Icons.album_rounded,
                      isEnabled: !_isSingle && _selectedArtist != null,
                      selectedItem: _selectedAlbum,
                      onChanged: (album) => setState(() => _selectedAlbum = album),
                      validator: (album) => !_isSingle && album == null ? 'Please select an album' : null,
                      itemToString: (album) => album.title,
                      onFind: (filter) async {
                        if (_selectedArtist == null) return [];
                        final albums = await _firebaseService.getAlbums();
                        final artistAlbums = albums.where((a) => a.artistId == _selectedArtist!.id).toList();
                        return SearchService().filterAlbums(query: filter, albums: artistAlbums);
                      },
                      dropdownBuilder: (album) => Row(
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
                            child: album.coverImageUrl.isEmpty ? const Icon(Icons.album, size: 11) : null,
                          ),
                          const SizedBox(width: 8),
                          Text(album.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
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
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.songDetailsLyricsSection ?? 'Song Details & Lyrics',
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
                    initialValue: _selectedScale,
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
                    initialValue: _selectedRhythm,
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

            AdminPrimaryButton(
              label: AppLocalizations.of(context)?.updateSongChanges ?? 'Update Song Changes',
              icon: Icons.save_rounded,
              isLoading: _isLoading,
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
}