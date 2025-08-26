import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import '../../models/song_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';

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
  late TextEditingController _otherScaleController;
  late TextEditingController _otherRhythmController;

  bool _isLoading = false;
  String? _selectedScale;
  String? _selectedRhythm;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _lyricsController = TextEditingController(text: widget.song.lyrics);

    if (widget.song.scale != null) {
      if (scaleMenuItems.contains(widget.song.scale)) {
        _selectedScale = widget.song.scale;
      } else {
        _selectedScale = 'Other';
        _otherScaleController = TextEditingController(text: widget.song.scale);
      }
    } else {
      _otherScaleController = TextEditingController();
    }

    if (widget.song.rhythm != null) {
      if (rhythmMenuItems.contains(widget.song.rhythm)) {
        _selectedRhythm = widget.song.rhythm;
      } else {
        _selectedRhythm = 'Other';
        _otherRhythmController = TextEditingController(text: widget.song.rhythm);
      }
    } else {
      _otherRhythmController = TextEditingController();
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final finalScale = _selectedScale == 'Other' ? _otherScaleController.text : _selectedScale;
      final finalRhythm = _selectedRhythm == 'Other' ? _otherRhythmController.text : _selectedRhythm;

      final Map<String, dynamic> updatedData = {
        'title': _titleController.text,
        'lyrics': _lyricsController.text,
        'scale': finalScale,
        'rhythm': finalRhythm,
      };

      await _firebaseService.updateSong(widget.song.id, updatedData);

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context, 'Song updated successfully!');
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
            _buildSectionCard(
              context,
              title: 'Edit Song Details',
              children: [
                TextFormField(controller: _titleController, decoration: _inputDecoration('Song Title', Icons.music_note_outlined), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedScale,
                  decoration: _inputDecoration('Scale (Optional)', Icons.queue_music_outlined),
                  items: scaleMenuItems.map((scale) => DropdownMenuItem(value: scale, child: Text(scale))).toList(),
                  onChanged: (value) => setState(() => _selectedScale = value),
                ),
                if (_selectedScale == 'Other') ...[
                  const SizedBox(height: 16),
                  TextFormField(controller: _otherScaleController, decoration: _inputDecoration('Enter Custom Scale', Icons.edit), validator: (v) => v!.isEmpty ? 'Required' : null),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRhythm,
                  decoration: _inputDecoration('Rhythm (Optional)', Icons.timelapse_outlined),
                  items: rhythmMenuItems.map((rhythm) => DropdownMenuItem(value: rhythm, child: Text(rhythm))).toList(),
                  onChanged: (value) => setState(() => _selectedRhythm = value),
                ),
                if (_selectedRhythm == 'Other') ...[
                  const SizedBox(height: 16),
                  TextFormField(controller: _otherRhythmController, decoration: _inputDecoration('Enter Custom Rhythm', Icons.edit), validator: (v) => v!.isEmpty ? 'Required' : null),
                ],
                const SizedBox(height: 16),
                TextFormField(controller: _lyricsController, decoration: _inputDecoration('Lyrics', Icons.text_fields_outlined, alignLabel: true), minLines: 10, maxLines: 20, validator: (v) => v!.isEmpty ? 'Required' : null),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text('Save Changes'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
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

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      prefixIcon: Icon(icon),
      alignLabelWithHint: alignLabel,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _otherScaleController.dispose();
    _otherRhythmController.dispose();
    super.dispose();
  }
}