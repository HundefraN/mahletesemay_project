import 'dart:io';

import '../../services/coudinary_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:mahlete_semay_project/utils/permission_helper.dart';

class AddEditVocalDayScreen extends StatefulWidget {
  final String? planId;
  final VocalExerciseDay? existingDay;
  final bool isGeneralExercise;

  const AddEditVocalDayScreen({
    super.key,
    this.planId,
    this.existingDay,
    this.isGeneralExercise = false,
  });

  bool get isEditing => existingDay != null;

  @override
  State<AddEditVocalDayScreen> createState() => _AddEditVocalDayScreenState();
}

class _AddEditVocalDayScreenState extends State<AddEditVocalDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  late TextEditingController _dayController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isRestDay = false;

  String? _pickedAudioPath;
  String? _existingAudioUrl;
  String _pickedAudioFileName = '';

  bool _isSaving = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _dayController = TextEditingController(text: widget.isEditing ? widget.existingDay!.dayNumber.toString() : '');
    _titleController = TextEditingController(text: widget.isEditing ? widget.existingDay!.title : '');
    _descriptionController = TextEditingController(text: widget.isEditing ? widget.existingDay!.description : '');
    _isRestDay = widget.isEditing ? widget.existingDay!.isRestDay : false;
    _existingAudioUrl = widget.isEditing ? widget.existingDay!.audioUrl : null;
  }

  Future<void> _pickAudio() async {
    final hasPermission = await PermissionHelper.requestAudioAccess(context);
    if (!hasPermission) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _pickedAudioPath = result.files.single.path;
        _pickedAudioFileName = result.files.single.name;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      String? finalAudioUrl = _existingAudioUrl;

      if (_pickedAudioPath != null) {
        final uploadedUrl = await CloudinaryService.uploadAudio(
          File(_pickedAudioPath!),
          onProgress: (count, total) => setState(() => _uploadProgress = count / total),
        );
        if (uploadedUrl != null) {
          finalAudioUrl = uploadedUrl;
        } else {
          CustomSnackbar.show(context, 'Audio upload failed. Please try again.', isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      if (_isRestDay && !widget.isGeneralExercise) {
        finalAudioUrl = null;
      }

      if (!_isRestDay && finalAudioUrl == null) {
        CustomSnackbar.show(context, 'An audio file is required for an exercise day.', isError: true);
        setState(() => _isSaving = false);
        return;
      }

      final dayData = VocalExerciseDay(
        id: widget.isEditing ? widget.existingDay!.id : '',
        dayNumber: int.tryParse(_dayController.text) ?? 0,
        title: _titleController.text,
        description: _descriptionController.text,
        isRestDay: widget.isGeneralExercise ? false : _isRestDay,
        audioUrl: finalAudioUrl,
      );

      if (widget.isGeneralExercise) {
        if (widget.isEditing) {
          await _firebaseService.updateGeneralExercise(dayData.id, dayData.toJson());
        } else {
          await _firebaseService.addGeneralExercise(dayData);
        }
      } else {
        if (widget.isEditing) {
          await _firebaseService.updateVocalExerciseDay(widget.planId!, dayData.id, dayData.toJson());
        } else {
          await _firebaseService.addVocalExerciseDay(widget.planId!, dayData);
        }
      }

      setState(() => _isSaving = false);
      if (mounted) {
        Navigator.pop(context, true);
        CustomSnackbar.show(context, widget.isEditing ? 'Exercise updated successfully!' : 'Exercise added successfully!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Exercise' : 'Add Exercise')),
      body: _isSaving
          ? _buildLoadingIndicator()
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.isGeneralExercise) ...[
              TextFormField(controller: _dayController, decoration: _inputDecoration('Day Number', Icons.format_list_numbered), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
            ],
            TextFormField(controller: _titleController, decoration: _inputDecoration('Title', Icons.title), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _descriptionController, decoration: _inputDecoration('Description', Icons.description_outlined, alignLabel: true), minLines: 5, maxLines: 10, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            if (!widget.isGeneralExercise)
              SwitchListTile(
                title: const Text('Is this a Rest Day?'),
                value: _isRestDay,
                onChanged: (val) => setState(() => _isRestDay = val),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            const SizedBox(height: 24),
            if (!_isRestDay) ...[
              Text('Exercise Audio', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.audiotrack_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_pickedAudioFileName.isNotEmpty ? _pickedAudioFileName : 'No file selected', overflow: TextOverflow.ellipsis)),
                    ElevatedButton(onPressed: _pickAudio, child: const Text('Select Audio')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _submit, child: Text(widget.isEditing ? 'Save Changes' : 'Add Exercise')),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Saving data...", style: TextStyle(fontSize: 18)), const SizedBox(height: 20), if (_uploadProgress > 0 && _uploadProgress < 1) ...[LinearProgressIndicator(value: _uploadProgress, minHeight: 10, borderRadius: BorderRadius.circular(10)), const SizedBox(height: 10), Text('${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded')] else const CircularProgressIndicator()])));
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool alignLabel = false}) {
    return InputDecoration(labelText: label, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), prefixIcon: Icon(icon), alignLabelWithHint: alignLabel);
  }
}