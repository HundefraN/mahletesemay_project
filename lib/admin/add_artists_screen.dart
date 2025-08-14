import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import '../../models/artist_model.dart';
import '../../services/firebase_service.dart';
import '../services/coudinary_service.dart';

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

  Future<void> _pickAndCropImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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
      String imageUrl = '';

      if (_pickedImage != null) {
        final uploadedUrl = await CloudinaryService.uploadImage(
          _pickedImage!,
          onProgress: (count, total) {
            setState(() {
              _uploadProgress = count / total;
            });
          },
        );
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        } else {
          CustomSnackbar.show(context, 'Image upload failed. Please try again.', isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      final newArtist = Artist(
        id: '',
        name: _nameController.text,
        imageUrl: imageUrl,
        region: _region,
      );
      await _firebaseService.addArtist(newArtist);

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context, 'Artist added successfully!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Artist')),
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
                  onChanged: (value) {
                    setState(() => _region = value!);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Artist Image (Optional)',
              children: [
                _buildImagePicker(),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Artist'),
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
            const Text("Saving artist...", style: TextStyle(fontSize: 18)),
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

  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickAndCropImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _pickedImage != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_pickedImage!, fit: BoxFit.cover),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            const Text('Tap to select image'),
          ],
        ),
      ),
    );
  }
}