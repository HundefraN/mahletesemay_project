import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/artist_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/draft_service.dart';
import '../../services/duplicate_detection_service.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import 'widgets/admin_ui_kit.dart';
import 'widgets/draft_prompt_dialog.dart';
import 'widgets/duplicate_warning_dialog.dart';

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
  final _duplicateService = DuplicateDetectionService();

  bool _isSaving = false;
  bool _isCheckingDuplicates = false;
  double _uploadProgress = 0.0;
  Uint8List? _pickedImageBytes;
  bool _hasUnsavedChanges = false;
  bool _hasDraftBanner = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_markDirty);
    _checkForDraft();
  }

  @override
  void dispose() {
    _nameController.removeListener(_markDirty);
    _nameController.dispose();
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
    final hasDraft = await DraftService.hasArtistDraft();
    if (hasDraft && mounted) {
      setState(() => _hasDraftBanner = true);
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await DraftService.loadArtistDraft();
    if (draft == null) return;

    setState(() {
      _nameController.text = draft['name'] ?? '';
      _region = draft['region'] ?? 'Ethiopian';
      _hasDraftBanner = false;
      _hasUnsavedChanges = true;
    });

    await DraftService.clearArtistDraft();
    if (mounted) {
      CustomSnackbar.show(context, 'Draft restored successfully!');
    }
  }

  Future<void> _dismissDraft() async {
    await DraftService.clearArtistDraft();
    if (mounted) {
      setState(() => _hasDraftBanner = false);
    }
  }

  Future<void> _saveDraft() async {
    await DraftService.saveArtistDraft(
      name: _nameController.text,
      region: _region,
    );
  }

  // ---------------------------------------------------------------------------
  // BACK NAVIGATION HANDLING
  // ---------------------------------------------------------------------------

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await DraftPromptDialog.show(context, 'artist');
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
  // IMAGE PICKER (existing logic preserved)
  // ---------------------------------------------------------------------------

  Future<void> _pickAndCropImage() async {
    final hasPermission = await PermissionHelper.requestPhotoAccess(context);
    if (!hasPermission) return;

    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);

      if (pickedFile != null) {
        if (!mounted) return;
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
        final duplicateResult = await _duplicateService.checkArtistDuplicates(
          name: _nameController.text.trim(),
          region: _region,
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
        String imageUrl = '';

        if (_pickedImageBytes != null) {
          final uploadedUrl = await SupabaseStorageService.uploadImageBytes(
            _pickedImageBytes!,
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

        // Clear any saved draft on successful submission
        await DraftService.clearArtistDraft();
        if (!mounted) return;

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
          _hasUnsavedChanges = false;
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
              // Draft restoration banner
              if (_hasDraftBanner) _buildDraftBanner(isDark),

              // Section 1: Details
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
                        setState(() {
                          _region = value!;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Section 2: Photo
              AdminSectionHeader(
                title: AppLocalizations.of(context)?.artistPhotoOptional ?? 'Artist Photo (Optional)',
                icon: Icons.add_a_photo_rounded,
                padding: EdgeInsets.only(top: 4, bottom: 6),
              ),
              AdminGlassCard(
                padding: const EdgeInsets.all(12),
                child: _buildAvatarPicker(context),
              ),

              const SizedBox(height: 16),

              AdminPrimaryButton(
                label: _isCheckingDuplicates ? 'Checking for duplicates...' : 'Save & Publish Artist',
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
                    'You have an unsaved artist draft. Restore it?',
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
  // AVATAR PICKER (existing logic preserved)
  // ---------------------------------------------------------------------------

  Widget _buildAvatarPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_pickedImageBytes != null) {
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
                  Image.memory(_pickedImageBytes!, width: 100, height: 100, fit: BoxFit.cover),
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
                label: Text(AppLocalizations.of(context)?.change ?? 'Change', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _pickedImageBytes = null;
                  _hasUnsavedChanges = true;
                }),
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AdminUiKit.roseRed),
                label: Text(AppLocalizations.of(context)?.remove ?? 'Remove', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AdminUiKit.roseRed)),
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
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
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
                color: AdminUiKit.royalBlue.withValues(alpha: 0.12),
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