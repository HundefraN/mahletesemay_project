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
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/searchable_dropdown.dart';
import 'widgets/admin_ui_kit.dart';

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

  bool _isSaving = false;
  double _uploadProgress = 0.0;

  Artist? _selectedArtist;
  File? _pickedImage;

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _volumeController.dispose();
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
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Error picking image: $e', isError: true);
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
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

    return Scaffold(
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
                onChanged: (artist) => setState(() => _selectedArtist = artist),
                validator: (artist) => artist == null ? 'Please select an artist' : null,
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
              label: 'Save & Publish Album',
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
                onPressed: () => setState(() => _pickedImage = null),
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