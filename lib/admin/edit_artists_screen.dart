import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/artist_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import 'widgets/admin_ui_kit.dart';

class EditArtistScreen extends StatefulWidget {
  final Artist artist;
  const EditArtistScreen({super.key, required this.artist});

  @override
  State<EditArtistScreen> createState() => _EditArtistScreenState();
}

class _EditArtistScreenState extends State<EditArtistScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _region;
  late String _existingImageUrl;

  final _firebaseService = FirebaseService();
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.artist.name);
    _region = widget.artist.region;
    _existingImageUrl = widget.artist.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final hasPermission = await PermissionHelper.requestPhotoAccess(context);
    if (!hasPermission) return;

    try {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);

      if (pickedFile != null) {
        Uint8List? imageBytes;
        if (!kIsWeb) {
          CroppedFile? croppedFile;
          try {
            croppedFile = await ImageCropper().cropImage(
              sourcePath: pickedFile.path,
              aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
              uiSettings: [
                AndroidUiSettings(
                  toolbarTitle: 'Crop Artist Photo',
                  toolbarColor: Theme.of(context).colorScheme.primary,
                  toolbarWidgetColor: Colors.white,
                  initAspectRatio: CropAspectRatioPreset.square,
                  lockAspectRatio: true,
                ),
                IOSUiSettings(
                  title: 'Crop Artist Photo',
                  aspectRatioLockEnabled: true,
                ),
              ],
            );
          } catch (e) {
            debugPrint('Crop error: $e');
          }

          if (croppedFile != null) {
            imageBytes = await croppedFile.readAsBytes();
          } else {
            imageBytes = await pickedFile.readAsBytes();
          }
        } else {
          imageBytes = await pickedFile.readAsBytes();
        }

        if (mounted) {
          setState(() {
            _pickedImageBytes = imageBytes;
            _uploadProgress = 0.0;
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
        String finalImageUrl = _existingImageUrl;

        if (_pickedImageBytes != null) {
          final uploadedUrl = await SupabaseStorageService.uploadImageBytes(
            _pickedImageBytes!,
            onProgress: (count, total) => setState(() => _uploadProgress = count / total),
          );
          if (uploadedUrl != null) {
            finalImageUrl = uploadedUrl;
          } else {
            if (mounted) {
              CustomSnackbar.show(context, 'Image upload failed.', isError: true);
            }
            setState(() => _isSaving = false);
            return;
          }
        }

        final Map<String, dynamic> updatedData = {
          'name': _nameController.text.trim(),
          'imageUrl': finalImageUrl,
          'region': _region,
        };

        await _firebaseService.updateArtist(widget.artist.id, updatedData);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'UPDATE_ARTIST',
            details: 'Updated artist: ${_nameController.text.trim()}',
          );
        }

        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Artist updated successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Failed to update artist: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteArtist() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)?.deleteArtistPrompt ?? 'Delete Artist?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(AppLocalizations.of(context)?.deleteArtistConfirm(widget.artist.name) ?? 'Are you sure you want to delete "${widget.artist.name}"? This will impact attached albums and songs.'),
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
        await _firebaseService.deleteArtists([widget.artist.id]);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator?.fullName ?? 'Admin',
            action: 'DELETE_ARTIST',
            details: 'Deleted artist: ${widget.artist.name}',
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Artist deleted.');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Error deleting artist: $e', isError: true);
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
          'Edit Artist',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AdminUiKit.roseRed, size: 20),
            tooltip: 'Delete Artist',
            onPressed: _deleteArtist,
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
            // Section 1: Info
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.artistInfoSection ?? 'Artist Information',
              icon: Icons.person_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                    decoration: _inputDecoration('Artist Full Name *', Icons.person_outline_rounded),
                    validator: (value) => value!.trim().isEmpty ? 'Please enter artist name' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _region,
                    decoration: _inputDecoration('Geographical Region', Icons.public_rounded),
                    items: ['Ethiopian', 'Worldwide']
                        .map((label) => DropdownMenuItem(
                              value: label,
                              child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _region = value!);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Section 2: Photo
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.artistPhoto ?? 'Artist Photo',
              icon: Icons.add_a_photo_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: _buildAvatarPicker(context),
            ),

            const SizedBox(height: 16),

            AdminPrimaryButton(
              label: AppLocalizations.of(context)?.saveArtistChanges ?? 'Save Artist Changes',
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

  Widget _buildAvatarPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_pickedImageBytes != null || _existingImageUrl.isNotEmpty) {
      return Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AdminUiKit.goldAccent, width: 2),
            ),
            child: ClipOval(
              child: _pickedImageBytes != null
                  ? Image.memory(_pickedImageBytes!, width: 100, height: 100, fit: BoxFit.cover)
                  : Image.network(
                      _existingImageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 40),
                      ),
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
                label: Text(AppLocalizations.of(context)?.change ?? 'Change', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              ),
              if (_pickedImageBytes != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _pickedImageBytes = null),
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
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminUiKit.royalBlue.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.add_a_photo_rounded, size: 24, color: AdminUiKit.royalBlue),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to upload photo',
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
