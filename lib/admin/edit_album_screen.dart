import '../services/coudinary_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../models/album_model.dart';
import '../../services/firebase_service.dart';

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

  Future<void> _pickAndCropImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Cover Image',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true),
          IOSUiSettings(
            title: 'Crop Cover Image',
            aspectRatioLockEnabled: true,
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
      String finalImageUrl = _existingCoverUrl;

      if (_pickedImage != null) {
        final uploadedUrl = await CloudinaryService.uploadImage(
          _pickedImage!,
          onProgress: (count, total) {
            setState(() => _uploadProgress = count / total);
          },
        );
        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        } else {
          CustomSnackbar.show(context, 'Image upload failed.', isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      final Map<String, dynamic> updatedData = {
        'title': _titleController.text,
        'year': _yearController.text.isNotEmpty ? int.tryParse(_yearController.text) : null,
        'volume': _volumeController.text.isNotEmpty ? int.tryParse(_volumeController.text) : null,
        'coverImageUrl': finalImageUrl,
      };

      await _firebaseService.updateAlbum(widget.album.id, updatedData);
      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context, true);
        CustomSnackbar.show(context, 'Album updated successfully!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.album.title}')),
      body: _isSaving
          ? _buildLoadingIndicator()
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              context,
              title: 'Album Details',
              icon: MdiIcons.album,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('Album Title *', Icons.album_outlined),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        decoration: _inputDecoration('Year', Icons.calendar_today_outlined),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _volumeController,
                        decoration: _inputDecoration('Volume', Icons.looks_one_outlined),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Album Cover Image',
              icon: MdiIcons.imageEdit,
              children: [
                _buildImagePreview(),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickAndCropImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Change Cover'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    } else if (_existingCoverUrl.isNotEmpty) {
      imageWidget = Image.network(_existingCoverUrl, fit: BoxFit.cover, width: double.infinity, height: 200);
    } else {
      imageWidget = const SizedBox(
        height: 150,
        child: Center(child: Icon(Icons.album, size: 60, color: Colors.grey)),
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
    _titleController.dispose();
    _yearController.dispose();
    _volumeController.dispose();
    super.dispose();
  }
}