import 'dart:io';

import '../services/coudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../services/firebase_service.dart';

class AddAlbumScreen extends StatefulWidget {
  const AddAlbumScreen({super.key});

  @override
  State<AddAlbumScreen> createState() => _AddAlbumScreenState();
}

class _AddAlbumScreenState extends State<AddAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _firebaseService = FirebaseService();

  bool _isSaving = false;
  bool _isFetchingArtists = true;
  double _uploadProgress = 0.0;

  List<Artist> _artists = [];
  Artist? _selectedArtist;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    final artists = await _firebaseService.getArtists();
    if (mounted) {
      setState(() {
        _artists = artists;
        _isFetchingArtists = false;
      });
    }
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
      if (_selectedArtist == null) {
        CustomSnackbar.show(context, 'Please select an artist', isError: true);
        return;
      }

      setState(() => _isSaving = true);
      String coverImageUrl = '';

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
          coverImageUrl = uploadedUrl;
        } else {
          CustomSnackbar.show(context, 'Image upload failed. Please try again.', isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      final newAlbum = Album(
        id: '',
        title: _titleController.text,
        artistId: _selectedArtist!.id,
        artistName: _selectedArtist!.name,
        coverImageUrl: coverImageUrl,
        year: int.parse(_yearController.text),
      );
      await _firebaseService.addAlbum(newAlbum);

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context, 'Album added successfully!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Album')),
      body: _isSaving || _isFetchingArtists
          ? _buildLoadingIndicator()
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              context,
              title: 'Album Details',
              children: [
                DropdownButtonFormField<Artist>(
                  value: _selectedArtist,
                  decoration: _inputDecoration('Select Artist', Icons.person_search_outlined),
                  isExpanded: true,
                  items: _artists.map((artist) {
                    return DropdownMenuItem<Artist>(
                      value: artist,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null,
                            child: artist.imageUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(artist.name, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (artist) {
                    setState(() => _selectedArtist = artist);
                  },
                  validator: (value) => value == null ? 'Please select an artist' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('Album Title', Icons.album_outlined),
                  validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _yearController,
                  decoration: _inputDecoration('Year of Release', Icons.calendar_today_outlined),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => value!.isEmpty ? 'Please enter a year' : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Album Cover (Optional)',
              children: [
                _buildImagePicker(),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Album'),
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
            const Text("Saving album...", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            if (_isSaving && _uploadProgress > 0 && _uploadProgress < 1) ...[
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
            const Text('Tap to select cover image'),
          ],
        ),
      ),
    );
  }
}