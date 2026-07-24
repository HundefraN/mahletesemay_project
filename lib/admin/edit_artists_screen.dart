import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/artist_model.dart';
import '../../services/firebase_service.dart';
import '../providers/auth_proveider.dart';
import '../services/coudinary_service.dart';
import '../widgets/custom_snackbar.dart';
import '../../utils/permission_helper.dart';

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
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.artist.name);
    _region = widget.artist.region;
    _existingImageUrl = widget.artist.imageUrl;
  }

  Future<void> _pickAndCropImage() async {
    final hasPermission = await PermissionHelper.requestPhotoAccess(context);
    if (!hasPermission) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPresetCustom(), 
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _pickedImage = File(croppedFile.path);
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      String finalImageUrl = _existingImageUrl;

      if (_pickedImage != null) {
        final uploadedUrl = await CloudinaryService.uploadImage(_pickedImage!, onProgress: (count, total) => setState(() => _uploadProgress = count / total));
        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        } else {
          CustomSnackbar.show(context, 'Image upload failed. Please try again.', isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      final Map<String, dynamic> updatedData = {
        'name': _nameController.text,
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
          details: 'Edited artist: ${_nameController.text.trim()}',
        );
      }

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context, true);
        CustomSnackbar.show(context, 'Artist updated successfully!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.artist.name}')),
      body: _isSaving
          ? _buildLoadingIndicator()
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              context,
              title: 'Artist Details',
              icon: MdiIcons.accountDetails,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Artist Name', Icons.person_outline),
                  validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _region,
                  decoration: _inputDecoration('Region', Icons.public),
                  items: ['Ethiopian', 'Worldwide']
                      .map((label) => DropdownMenuItem(child: Text(label), value: label))
                      .toList(),
                  onChanged: (value) => setState(() => _region = value!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Artist Image',
              icon: MdiIcons.imageEdit,
              children: [
                _buildImagePreview(),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickAndCropImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_pickedImage == null ? 'Change Image' : 'Select a Different Image'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Saving data...", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            if (_uploadProgress > 0 && _uploadProgress < 1) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 10),
              Text('${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded'),
            ] else ...[
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      prefixIcon: Icon(icon),
    );
  }

  Widget _buildImagePreview() {
    Widget imageWidget;
    if (_pickedImage != null) {
      imageWidget = Image.file(_pickedImage!, fit: BoxFit.cover, width: double.infinity, height: 200);
    } else if (_existingImageUrl.isNotEmpty) {
      imageWidget = Image.network(_existingImageUrl, fit: BoxFit.cover, width: double.infinity, height: 200);
    } else {
      imageWidget = const SizedBox(
        height: 150,
        child: Center(child: Icon(Icons.person, size: 60, color: Colors.grey)),
      );
    }
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 200,
          width: 200,
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
class CropAspectRatioPresetCustom implements CropAspectRatioPresetData {
  @override
  (int, int)? get data => (2, 3);

  @override
  String get name => '2x3 (customized)';
}
