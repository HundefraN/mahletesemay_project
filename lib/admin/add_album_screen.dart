import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/draft_service.dart';
import '../../services/duplicate_detection_service.dart';
import '../../services/firebase_service.dart';
import '../../services/search_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/searchable_dropdown.dart';
import 'widgets/admin_ui_kit.dart';
import 'widgets/draft_prompt_dialog.dart';
import 'widgets/duplicate_warning_dialog.dart';

class AddAlbumScreen extends StatefulWidget {
  const AddAlbumScreen({super.key});

  @override
  State<AddAlbumScreen> createState() => _AddAlbumScreenState();
}

class _AddAlbumScreenState extends State<AddAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _volumeController = TextEditingController();
  final _firebaseService = FirebaseService();
  final _duplicateService = DuplicateDetectionService();

  bool _isSaving = false;
  bool _isCheckingDuplicates = false;
  double _uploadProgress = 0.0;
  bool _hasUnsavedChanges = false;
  bool _hasDraftBanner = false;

  Artist? _selectedArtist;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _yearController.addListener(_markDirty);
    _volumeController.addListener(_markDirty);
    _checkForDraft();
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _yearController.removeListener(_markDirty);
    _volumeController.removeListener(_markDirty);
    _titleController.dispose();
    _yearController.dispose();
    _volumeController.dispose();
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
    final hasDraft = await DraftService.hasAlbumDraft();
    if (hasDraft && mounted) {
      setState(() => _hasDraftBanner = true);
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await DraftService.loadAlbumDraft();
    if (draft == null) return;

    setState(() {
      _titleController.text = draft['title'] ?? '';
      _yearController.text = draft['year'] ?? '';
      _volumeController.text = draft['volume'] ?? '';

      if (draft['artistId'] != null && draft['artistName'] != null) {
        _selectedArtist = Artist(
          id: draft['artistId'],
          name: draft['artistName'],
          imageUrl: draft['artistImageUrl'] ?? '',
          region: draft['artistRegion'] ?? '',
        );
      }

      _hasDraftBanner = false;
      _hasUnsavedChanges = true;
    });

    await DraftService.clearAlbumDraft();
    if (mounted) {
      CustomSnackbar.show(context, 'Draft restored successfully!');
    }
  }

  Future<void> _dismissDraft() async {
    await DraftService.clearAlbumDraft();
    if (mounted) {
      setState(() => _hasDraftBanner = false);
    }
  }

  Future<void> _saveDraft() async {
    await DraftService.saveAlbumDraft(
      title: _titleController.text,
      year: _yearController.text,
      volume: _volumeController.text,
      artistId: _selectedArtist?.id,
      artistName: _selectedArtist?.name,
      artistImageUrl: _selectedArtist?.imageUrl,
      artistRegion: _selectedArtist?.region,
    );
  }

  // ---------------------------------------------------------------------------
  // BACK NAVIGATION HANDLING
  // ---------------------------------------------------------------------------

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await DraftPromptDialog.show(context, 'album');
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

  // ---------------------------------------------------------------------------
  // IMAGE PICKER (existing logic preserved)
  // ---------------------------------------------------------------------------

  Future<void> _pickAndCropImage() async {
    final hasPermission = await PermissionHelper.requestPhotoAccess(context);
    if (!hasPermission) return;

    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        CroppedFile? croppedFile;
        try {
          croppedFile = await ImageCropper().cropImage(
            sourcePath: pickedFile.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Cover Image',
                toolbarColor: Theme.of(context).colorScheme.primary,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
              ),
              IOSUiSettings(title: 'Crop Cover Image', aspectRatioLockEnabled: true),
            ],
          );
        } catch (e) {
          debugPrint('Image cropping error: $e');
        }

        if (mounted) {
          setState(() {
            _pickedImage = File(croppedFile?.path ?? pickedFile.path);
            _hasUnsavedChanges = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Error picking image: $e', isError: true);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SUBMIT WITH DUPLICATE CHECK
  // ---------------------------------------------------------------------------

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      // Run duplicate detection before saving
      setState(() => _isCheckingDuplicates = true);
      try {
        final duplicateResult = await _duplicateService.checkAlbumDuplicates(
          title: _titleController.text.trim(),
          artistId: _selectedArtist?.id,
          artistName: _selectedArtist?.name,
          volume: int.tryParse(_volumeController.text.trim()),
        );

        setState(() => _isCheckingDuplicates = false);

        if (duplicateResult != null && duplicateResult.hasDuplicates && mounted) {
          final proceed = await DuplicateWarningDialog.show(context, duplicateResult);
          if (!proceed) return;
        }
      } catch (e) {
        setState(() => _isCheckingDuplicates = false);
        debugPrint('Duplicate check failed: $e');
      }

      setState(() => _isSaving = true);
      try {
        String coverImageUrl = '';

        if (_pickedImage != null) {
          final uploadedUrl = await SupabaseStorageService.uploadImage(
            _pickedImage!,
            onProgress: (count, total) => setState(() => _uploadProgress = count / total),
          );
          if (uploadedUrl != null) {
            coverImageUrl = uploadedUrl;
          } else {
            if (mounted) {
              CustomSnackbar.show(context, 'Image upload failed. Please try again.', isError: true);
            }
            setState(() => _isSaving = false);
            return;
          }
        }

        await _saveRecentArtist(_selectedArtist!);

        final newAlbum = Album(
          id: '',
          title: _titleController.text.trim(),
          artistId: _selectedArtist!.id,
          artistName: _selectedArtist!.name,
          coverImageUrl: coverImageUrl,
          year: int.tryParse(_yearController.text.trim()),
          volume: int.tryParse(_volumeController.text.trim()),
        );
        await _firebaseService.addAlbum(newAlbum);

        // Clear any saved draft on successful submission
        await DraftService.clearAlbumDraft();

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'CREATE_ALBUM',
            details: 'Added new album: ${_titleController.text.trim()}',
          );
        }

        if (mounted) {
          _hasUnsavedChanges = false;
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Album added successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Failed to save album: $e', isError: true);
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
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: Text(
            'Add New Album',
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

              // Section 1: Artist
              const AdminSectionHeader(
                title: 'Album Artist',
                icon: Icons.person_rounded,
                padding: EdgeInsets.only(top: 4, bottom: 6),
              ),
              AdminGlassCard(
                padding: const EdgeInsets.all(12),
                child: SearchableDropdown<Artist>(
                  label: 'Select Artist *',
                  icon: Icons.person_search_rounded,
                  selectedItem: _selectedArtist,
                  onChanged: (artist) {
                    setState(() {
                      _selectedArtist = artist;
                      _hasUnsavedChanges = true;
                    });
                  },
                  validator: (artist) => artist == null ? 'Please select an artist' : null,
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
              ),

              const SizedBox(height: 12),

              // Section 2: Details
              const AdminSectionHeader(
                title: 'Album Details',
                icon: Icons.album_rounded,
                padding: EdgeInsets.only(top: 4, bottom: 6),
              ),
              AdminGlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                      decoration: _inputDecoration('Album Title *', Icons.album_rounded),
                      validator: (v) => v!.trim().isEmpty ? 'Album title is required' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                            decoration: _inputDecoration('Year (e.g. 2024)', Icons.calendar_today_rounded),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _volumeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                            decoration: _inputDecoration('Volume (e.g. 1)', Icons.format_list_numbered_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Section 3: Cover Art
              const AdminSectionHeader(
                title: 'Album Cover Art (Optional)',
                icon: Icons.image_rounded,
                padding: EdgeInsets.only(top: 4, bottom: 6),
              ),
              AdminGlassCard(
                padding: const EdgeInsets.all(12),
                child: _buildCoverImagePicker(context),
              ),

              const SizedBox(height: 16),

              AdminPrimaryButton(
                label: _isCheckingDuplicates ? 'Checking for duplicates...' : 'Save & Publish Album',
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
            AdminUiKit.royalBlue.withOpacity(0.12),
            AdminUiKit.royalBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminUiKit.royalBlue.withOpacity(0.25),
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
                color: AdminUiKit.royalBlue.withOpacity(0.15),
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
                    'You have an unsaved album draft. Restore it?',
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
                backgroundColor: AdminUiKit.royalBlue.withOpacity(0.12),
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
  // COVER IMAGE PICKER (existing logic preserved)
  // ---------------------------------------------------------------------------

  Widget _buildCoverImagePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_pickedImage != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  _pickedImage!,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                if (_isSaving && _uploadProgress > 0 && _uploadProgress < 1)
                  Container(
                    height: 130,
                    width: double.infinity,
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(value: _uploadProgress, color: AdminUiKit.goldAccent),
                          const SizedBox(height: 6),
                          Text('${(_uploadProgress * 100).toInt()}% uploaded', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pickAndCropImage,
                icon: const Icon(Icons.change_circle_rounded, size: 16),
                label: Text('Change Cover', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _pickedImage = null;
                  _hasUnsavedChanges = true;
                }),
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AdminUiKit.roseRed),
                label: Text('Remove', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AdminUiKit.roseRed)),
              ),
            ],
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickAndCropImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            style: BorderStyle.solid,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminUiKit.amberOrange.withOpacity(0.12),
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, size: 24, color: AdminUiKit.amberOrange),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to upload cover artwork',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Square format recommended (PNG or JPG)',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      prefixIcon: Icon(icon, size: 18),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}