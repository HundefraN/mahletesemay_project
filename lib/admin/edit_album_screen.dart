import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/album_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import 'widgets/admin_ui_kit.dart';

class EditAlbumScreen extends StatefulWidget {
  final Album album;
  const EditAlbumScreen({super.key, required this.album});

  @override
  State<EditAlbumScreen> createState() => _EditAlbumScreenState();
}

class _EditAlbumScreenState extends State<EditAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _volumeController;
  late String _existingCoverUrl;

  final _firebaseService = FirebaseService();
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.album.title);
    _yearController = TextEditingController(text: widget.album.year?.toString() ?? '');
    _volumeController = TextEditingController(text: widget.album.volume?.toString() ?? '');
    _existingCoverUrl = widget.album.coverImageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _volumeController.dispose();
    super.dispose();
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
        String finalImageUrl = _existingCoverUrl;

        if (_pickedImage != null) {
          final uploadedUrl = await SupabaseStorageService.uploadImage(
            _pickedImage!,
            onProgress: (count, total) => setState(() => _uploadProgress = count / total),
          );
          if (uploadedUrl != null) {
            finalImageUrl = uploadedUrl;
          } else {
            if (mounted) {
              CustomSnackbar.show(context, 'Cover image upload failed.', isError: true);
            }
            setState(() => _isSaving = false);
            return;
          }
        }

        final Map<String, dynamic> updatedData = {
          'title': _titleController.text.trim(),
          'coverImageUrl': finalImageUrl,
          'year': int.tryParse(_yearController.text.trim()),
          'volume': int.tryParse(_volumeController.text.trim()),
        };

        await _firebaseService.updateAlbum(widget.album.id, updatedData);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'UPDATE_ALBUM',
            details: 'Updated album: ${_titleController.text.trim()}',
          );
        }

        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Album updated successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Failed to update album: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteAlbum() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)?.deleteAlbumPrompt ?? 'Delete Album?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(AppLocalizations.of(context)?.deleteAlbumConfirm(widget.album.title) ?? 'Are you sure you want to delete "${widget.album.title}"? This cannot be undone.'),
        actions: [
          TextButton(child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'), onPressed: () => Navigator.of(context).pop(false)),
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
      setState(() => _isSaving = true);
      try {
        await _firebaseService.deleteAlbums([widget.album.id]);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator?.fullName ?? 'Admin',
            action: 'DELETE_ALBUM',
            details: 'Deleted album: ${widget.album.title}',
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Album deleted.');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Error deleting album: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Edit Album',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AdminUiKit.roseRed, size: 20),
            tooltip: 'Delete Album',
            onPressed: _deleteAlbum,
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
            // Section 1: Details
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.albumDetailsSection ?? 'Album Details',
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
                          decoration: _inputDecoration('Release Year', Icons.calendar_today_rounded),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _volumeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                          decoration: _inputDecoration('Volume No.', Icons.format_list_numbered_rounded),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Section 2: Cover Art
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.albumCoverArt ?? 'Album Cover Art',
              icon: Icons.image_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: _buildCoverImagePicker(context),
            ),

            const SizedBox(height: 16),

            AdminPrimaryButton(
              label: AppLocalizations.of(context)?.saveAlbumChanges ?? 'Save Album Changes',
              icon: Icons.save_rounded,
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

    if (_pickedImage != null || _existingCoverUrl.isNotEmpty) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _pickedImage != null
                ? Image.file(_pickedImage!, height: 130, width: double.infinity, fit: BoxFit.cover)
                : Image.network(
                    _existingCoverUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 130,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pickAndCropImage,
                icon: const Icon(Icons.change_circle_rounded, size: 16),
                label: Text(AppLocalizations.of(context)?.changeCover ?? 'Change Cover', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              ),
              if (_pickedImage != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _pickedImage = null),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(AppLocalizations.of(context)?.revert ?? 'Revert', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                ),
              ],
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