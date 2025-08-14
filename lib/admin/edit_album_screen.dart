import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/album_model.dart';
import '../../services/firebase_service.dart';
import '../services/coudinary_service.dart';

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
  late String _existingCoverUrl;

  final _firebaseService = FirebaseService();
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.album.title);
    _yearController = TextEditingController(text: widget.album.year.toString());
    _existingCoverUrl = widget.album.coverImageUrl;
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
        _uploadProgress = 0.0;
      });
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed.')));
          setState(() => _isSaving = false);
          return;
        }
      }

      final Map<String, dynamic> updatedData = {
        'title': _titleController.text,
        'year': int.parse(_yearController.text),
        'coverImageUrl': finalImageUrl,
      };

      await _firebaseService.updateAlbum(widget.album.id, updatedData);
      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Album updated successfully!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.album.title}')),
      body: _isSaving
          ? Center(
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
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              context,
              title: 'Album Details',
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('Album Title', Icons.album_outlined),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _yearController,
                  decoration: _inputDecoration('Year of Release', Icons.calendar_today_outlined),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              title: 'Album Cover Image',
              children: [
                _buildImagePreview(),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Change Cover'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _submit, child: const Text('Save Changes')),
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
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: imageWidget);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    super.dispose();
  }
}