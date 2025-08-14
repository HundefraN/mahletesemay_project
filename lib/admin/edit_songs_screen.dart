import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/song_model.dart';
import '../../services/firebase_service.dart';

class EditSongScreen extends StatefulWidget {
  final Song song;
  const EditSongScreen({super.key, required this.song});

  @override
  State<EditSongScreen> createState() => _EditSongScreenState();
}

class _EditSongScreenState extends State<EditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  late TextEditingController _titleController;
  late TextEditingController _lyricsController;
  late TextEditingController _scaleController;
  late TextEditingController _scaleDegreeController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _lyricsController = TextEditingController(text: widget.song.lyrics);
    _scaleController = TextEditingController(text: widget.song.scale);
    _scaleDegreeController = TextEditingController(text: widget.song.scaleDegree.toString());
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final Map<String, dynamic> updatedData = {
        'title': _titleController.text,
        'lyrics': _lyricsController.text,
        'scale': _scaleController.text,
        'scaleDegree': int.parse(_scaleDegreeController.text),
      };

      await _firebaseService.updateSong(widget.song.id, updatedData);

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song updated successfully!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.song.title}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Song Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _scaleController, decoration: const InputDecoration(labelText: 'Scale (e.g., G Major)'), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _scaleDegreeController, decoration: const InputDecoration(labelText: 'Scale Degree (1, 4, 5, 6)'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _lyricsController, decoration: const InputDecoration(labelText: 'Lyrics'), maxLines: 10, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text('Save Changes')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _scaleController.dispose();
    _scaleDegreeController.dispose();
    super.dispose();
  }
}