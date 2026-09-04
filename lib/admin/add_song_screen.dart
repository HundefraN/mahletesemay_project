import 'dart:convert';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/draft_service.dart';
import '../../services/duplicate_detection_service.dart';
import '../../services/firebase_service.dart';
import '../../services/search_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/searchable_dropdown.dart';
import 'widgets/admin_ui_kit.dart';
import 'widgets/draft_prompt_dialog.dart';
import 'widgets/duplicate_warning_dialog.dart';

class AddSongScreen extends StatefulWidget {
  const AddSongScreen({super.key});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _duplicateService = DuplicateDetectionService();

  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _otherScaleController = TextEditingController();
  final _otherRhythmController = TextEditingController();

  bool _isSaving = false;
  bool _isCheckingDuplicates = false;
  bool _isSingle = false;
  bool _hasUnsavedChanges = false;
  bool _hasDraftBanner = false;

  Artist? _selectedArtist;
  Album? _selectedAlbum;
  String? _selectedScale;
  String? _selectedRhythm;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _lyricsController.addListener(_markDirty);
    _otherScaleController.addListener(_markDirty);
    _otherRhythmController.addListener(_markDirty);
    _checkForDraft();
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _lyricsController.removeListener(_markDirty);
    _otherScaleController.removeListener(_markDirty);
    _otherRhythmController.removeListener(_markDirty);
    _titleController.dispose();
    _lyricsController.dispose();
    _otherScaleController.dispose();
    _otherRhythmController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  // ---------------------------------------------------------------------------
  // DRAFT MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<void> _checkForDraft() async {
    final hasDraft = await DraftService.hasSongDraft();
    if (hasDraft && mounted) {
      setState(() => _hasDraftBanner = true);
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await DraftService.loadSongDraft();
    if (draft == null) return;

    setState(() {
      _titleController.text = draft['title'] ?? '';
      _lyricsController.text = draft['lyrics'] ?? '';
      _otherScaleController.text = draft['otherScale'] ?? '';
      _otherRhythmController.text = draft['otherRhythm'] ?? '';
      _selectedScale = draft['scale'];
      _selectedRhythm = draft['rhythm'];
      _isSingle = draft['isSingle'] == true;

      // Restore artist if saved
      if (draft['artistId'] != null && draft['artistName'] != null) {
        _selectedArtist = Artist(
          id: draft['artistId'],
          name: draft['artistName'],
          imageUrl: draft['artistImageUrl'] ?? '',
          region: draft['artistRegion'] ?? '',
        );
      }

      // Restore album if saved
      if (draft['albumId'] != null && draft['albumTitle'] != null) {
        _selectedAlbum = Album(
          id: draft['albumId'],
          title: draft['albumTitle'],
          artistId: _selectedArtist?.id ?? '',
          artistName: _selectedArtist?.name ?? '',
          coverImageUrl: draft['albumCoverUrl'] ?? '',
        );
      }

      _hasDraftBanner = false;
      _hasUnsavedChanges = true;
    });

    await DraftService.clearSongDraft();
    if (mounted) {
      CustomSnackbar.show(context, 'Draft restored successfully!');
    }
  }

  Future<void> _dismissDraft() async {
    await DraftService.clearSongDraft();
    if (mounted) {
      setState(() => _hasDraftBanner = false);
    }
  }

  Future<void> _saveDraft() async {
    await DraftService.saveSongDraft(
      title: _titleController.text,
      lyrics: _lyricsController.text,
      artistId: _selectedArtist?.id,
      artistName: _selectedArtist?.name,
      artistImageUrl: _selectedArtist?.imageUrl,
      artistRegion: _selectedArtist?.region,
      albumId: _selectedAlbum?.id,
      albumTitle: _selectedAlbum?.title,
      albumCoverUrl: _selectedAlbum?.coverImageUrl,
      scale: _selectedScale,
      rhythm: _selectedRhythm,
      otherScale: _otherScaleController.text,
      otherRhythm: _otherRhythmController.text,
      isSingle: _isSingle,
    );
  }

  // ---------------------------------------------------------------------------
  // BACK NAVIGATION HANDLING
  // ---------------------------------------------------------------------------

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await DraftPromptDialog.show(context, 'song');
    switch (result) {
      case DraftPromptResult.saveDraft:
        await _saveDraft();
        if (mounted) {
          CustomSnackbar.show(context, 'Draft saved! You can resume later.');
        }
        return true;
      case DraftPromptResult.discard:
        return true;
      case DraftPromptResult.cancel:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // RECENT ARTISTS (existing logic preserved)
  // ---------------------------------------------------------------------------

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
      _hasUnsavedChanges = true;
    });
  }

  // ---------------------------------------------------------------------------
  // SUBMIT WITH DUPLICATE CHECK
  // ---------------------------------------------------------------------------

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      // Run duplicate detection before saving
      setState(() => _isCheckingDuplicates = true);
      try {
        final duplicateResult = await _duplicateService.checkSongDuplicates(
          title: _titleController.text.trim(),
          artistId: _isSingle ? (_selectedArtist?.id ?? singlesArtistId) : _selectedArtist?.id,
          artistName: _isSingle ? (_selectedArtist?.name ?? "Various Artists") : _selectedArtist?.name,
          albumId: _isSingle ? singlesAlbumId : _selectedAlbum?.id,
          albumTitle: _isSingle ? "Singles" : _selectedAlbum?.title,
        );

        setState(() => _isCheckingDuplicates = false);

        if (duplicateResult != null && duplicateResult.hasDuplicates && mounted) {
          final proceed = await DuplicateWarningDialog.show(context, duplicateResult);
          if (!proceed) return;
        }
      } catch (e) {
        setState(() => _isCheckingDuplicates = false);
        // If duplicate check fails, don't block — just proceed
        debugPrint('Duplicate check failed: $e');
      }

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

        // Clear any saved draft on successful submission
        await DraftService.clearSongDraft();
        if (!mounted) return;

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
          _hasUnsavedChanges = false;
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

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
              // Draft restoration banner
              if (_hasDraftBanner) _buildDraftBanner(isDark),

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
                    // Single Switch Tile
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
                        activeThumbColor: AdminUiKit.goldAccent,
                        onChanged: (value) {
                          AdminUiKit.hapticLight();
                          setState(() {
                            _isSingle = value;
                            _hasUnsavedChanges = true;
                          });
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

                        final filteredRecent = SearchService().filterArtists(query: filter, artists: recent);
                        final filteredAll = SearchService().filterArtists(query: filter, artists: all)
                            .where((a) => !recent.any((r) => r.id == a.id)).toList();

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
                        label: AppLocalizations.of(context)?.selectAlbumPrompt ?? '2. Select Album *',
                        icon: Icons.album_rounded,
                        isEnabled: !_isSingle && _selectedArtist != null,
                        selectedItem: _selectedAlbum,
                        onChanged: (album) {
                          setState(() {
                            _selectedAlbum = album;
                            _hasUnsavedChanges = true;
                          });
                        },
                        validator: (album) => !_isSingle && album == null ? 'Please select an album' : null,
                        itemToString: (album) => album.title,
                        onFind: (filter) async {
                          if (_selectedArtist == null) return [];
                          final albums = await _firebaseService.getAlbums();
                          final artistAlbums = albums.where((a) => a.artistId == _selectedArtist!.id).toList();
                          return SearchService().filterAlbums(query: filter, albums: artistAlbums);
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
              AdminSectionHeader(
                title: AppLocalizations.of(context)?.songDetailsMetadataSection ?? 'Song Details & Metadata',
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
                      onChanged: (value) {
                        setState(() {
                          _selectedScale = value;
                          _hasUnsavedChanges = true;
                        });
                      },
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
                      onChanged: (value) {
                        setState(() {
                          _selectedRhythm = value;
                          _hasUnsavedChanges = true;
                        });
                      },
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
                label: _isCheckingDuplicates ? 'Checking for duplicates...' : 'Save & Publish Song',
                icon: _isCheckingDuplicates ? Icons.search_rounded : Icons.check_circle_rounded,
                isLoading: _isSaving || _isCheckingDuplicates,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DRAFT BANNER WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildDraftBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminUiKit.royalBlue.withValues(alpha: 0.12),
            AdminUiKit.royalBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminUiKit.royalBlue.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminUiKit.royalBlue.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.restore_rounded, color: AdminUiKit.royalBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Draft Available',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You have an unsaved song draft. Restore it?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _dismissDraft,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Dismiss',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _restoreDraft,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AdminUiKit.royalBlue.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Restore',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminUiKit.royalBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

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