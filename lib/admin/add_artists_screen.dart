import 'dart:io';
import 'package:flutter/material.dart';
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

class AddArtistScreen extends StatefulWidget {
  const AddArtistScreen({super.key});

  @override
  State<AddArtistScreen> createState() => _AddArtistScreenState();
}

class _AddArtistScreenState extends State<AddArtistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _region = 'Ethiopian';
  final _firebaseService = FirebaseService();
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  File? _pickedImage;

  @override
  void dispose() {
    _nameController.dispose();
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

        if (mounted) {
          setState(() {
            _pickedImage = File(croppedFile?.path ?? pickedFile.path);
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
        String imageUrl = '';

        if (_pickedImage != null) {
          final uploadedUrl = await SupabaseStorageService.uploadImage(
            _pickedImage!,
            onProgress: (count, total) => setState(() => _uploadProgress = count / total),
          );
          if (uploadedUrl != null) {
            imageUrl = uploadedUrl;
          } else {
            if (mounted) {
              CustomSnackbar.show(context, 'Image upload failed. Please try again.', isError: true);
            }
            setState(() => _isSaving = false);
            return;
          }
        }

        final newArtist = Artist(
          id: '',
          name: _nameController.text.trim(),
          imageUrl: imageUrl,
          region: _region,
        );
        await _firebaseService.addArtist(newArtist);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentModerator != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator!.fullName,
            action: 'CREATE_ARTIST',
            details: 'Added new artist: ${_nameController.text.trim()}',
          );
        }

        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(context, 'Artist added successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context, 'Failed to save artist: $e', isError: true);
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
          'Add New Artist',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          physics: const BouncingScrollPhysics(),
          children: [
            // Section 1: Details
            const AdminSectionHeader(
              title: 'Artist Information',
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
                    value: _region,
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
            const AdminSectionHeader(
              title: 'Artist Photo (Optional)',
              icon: Icons.add_a_photo_rounded,
              padding: EdgeInsets.only(top: 4, bottom: 6),
            ),
            AdminGlassCard(
              padding: const EdgeInsets.all(12),
              child: _buildAvatarPicker(context),
            ),

            const SizedBox(height: 16),

            AdminPrimaryButton(
              label: 'Save & Publish Artist',
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

  Widget _buildAvatarPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_pickedImage != null) {
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(_pickedImage!, width: 100, height: 100, fit: BoxFit.cover),
                  if (_isSaving && _uploadProgress > 0 && _uploadProgress < 1)
                    Container(
                      width: 100,
                      height: 100,
                      color: Colors.black54,
                      child: CircularProgressIndicator(value: _uploadProgress, color: AdminUiKit.goldAccent),
                    ),
                ],
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
                label: Text('Change', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
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
                color: AdminUiKit.royalBlue.withOpacity(0.12),
              ),
              child: const Icon(Icons.add_a_photo_rounded, size: 24, color: AdminUiKit.royalBlue),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to upload artist portrait',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Square portrait ratio recommended',
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