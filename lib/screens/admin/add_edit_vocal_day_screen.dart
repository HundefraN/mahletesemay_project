import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../models/vocal_plan_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/web_content_wrapper.dart';
import '../../l10n/app_localizations.dart';

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
  AppLocalizations? get l10n => AppLocalizations.of(context);

  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  late TextEditingController _dayController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isRestDay = false;

  Uint8List? _pickedAudioBytes;
  String? _existingAudioUrl;
  String _pickedAudioFileName = '';

  bool _isSaving = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _dayController = TextEditingController(
      text: widget.isEditing ? widget.existingDay!.dayNumber.toString() : '',
    );
    _titleController = TextEditingController(
      text: widget.isEditing ? widget.existingDay!.title : '',
    );
    _descriptionController = TextEditingController(
      text: widget.isEditing ? widget.existingDay!.description : '',
    );
    _isRestDay = widget.isEditing ? widget.existingDay!.isRestDay : false;
    _existingAudioUrl = widget.isEditing ? widget.existingDay!.audioUrl : null;
  }

  @override
  void dispose() {
    _dayController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final hasPermission = await PermissionHelper.requestAudioAccess(context);
    if (!hasPermission) return;

    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.audio, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null && !kIsWeb) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          setState(() {
            _pickedAudioBytes = bytes;
            _pickedAudioFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context,
            '${l10n?.errorPickingAudio ?? "Error picking audio file"}: $e',
            isError: true);
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        String? finalAudioUrl = _existingAudioUrl;

        if (_pickedAudioBytes != null) {
          final ext = p.extension(_pickedAudioFileName);
          final uploadedUrl = await SupabaseStorageService.uploadAudioBytes(
            _pickedAudioBytes!,
            extension: ext.isNotEmpty ? ext : '.mp3',
            onProgress: (count, total) =>
                setState(() => _uploadProgress = count / total),
          );
          if (uploadedUrl != null) {
            finalAudioUrl = uploadedUrl;
          } else {
            if (mounted) {
              CustomSnackbar.show(
                  context,
                  l10n?.audioUploadFailed ??
                      'Audio upload failed. Please try again.',
                  isError: true);
            }
            setState(() => _isSaving = false);
            return;
          }
        }

        if (_isRestDay && !widget.isGeneralExercise) {
          finalAudioUrl = null;
        }

        if (!_isRestDay && (finalAudioUrl == null || finalAudioUrl.isEmpty)) {
          if (mounted) {
            CustomSnackbar.show(
                context,
                l10n?.audioRequired ??
                    'An audio file is required for this vocal exercise.',
                isError: true);
          }
          setState(() => _isSaving = false);
          return;
        }

        final dayData = VocalExerciseDay(
          id: widget.isEditing ? widget.existingDay!.id : '',
          dayNumber: int.tryParse(_dayController.text.trim()) ?? 0,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          isRestDay: widget.isGeneralExercise ? false : _isRestDay,
          audioUrl: finalAudioUrl,
        );

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (widget.isGeneralExercise) {
          if (widget.isEditing) {
            await _firebaseService.updateGeneralExercise(
                dayData.id, dayData.toJson());
            if (authProvider.currentModerator != null) {
              _firebaseService.logActivity(
                moderatorId: authProvider.currentUser!.uid,
                moderatorName: authProvider.currentModerator!.fullName,
                action: 'UPDATE_EXERCISE',
                details: 'Updated general exercise: "${dayData.title}"',
              );
            }
          } else {
            await _firebaseService.addGeneralExercise(dayData);
            if (authProvider.currentModerator != null) {
              _firebaseService.logActivity(
                moderatorId: authProvider.currentUser!.uid,
                moderatorName: authProvider.currentModerator!.fullName,
                action: 'CREATE_EXERCISE',
                details: 'Added general exercise: "${dayData.title}"',
              );
            }
          }
        } else {
          if (widget.isEditing) {
            await _firebaseService.updateVocalExerciseDay(
                widget.planId!, dayData.id, dayData.toJson());
            if (authProvider.currentModerator != null) {
              _firebaseService.logActivity(
                moderatorId: authProvider.currentUser!.uid,
                moderatorName: authProvider.currentModerator!.fullName,
                action: 'UPDATE_EXERCISE_DAY',
                details:
                    'Updated vocal plan day ${dayData.dayNumber}: "${dayData.title}"',
              );
            }
          } else {
            await _firebaseService.addVocalExerciseDay(widget.planId!, dayData);
            if (authProvider.currentModerator != null) {
              _firebaseService.logActivity(
                moderatorId: authProvider.currentUser!.uid,
                moderatorName: authProvider.currentModerator!.fullName,
                action: 'CREATE_EXERCISE_DAY',
                details:
                    'Added vocal plan day ${dayData.dayNumber}: "${dayData.title}"',
              );
            }
          }
        }

        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
          CustomSnackbar.show(
            context,
            widget.isEditing
                ? (l10n?.exerciseUpdated ?? 'Exercise updated successfully!')
                : (l10n?.exerciseAdded ?? 'Exercise added successfully!'),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackbar.show(context,
              '${l10n?.failedToSaveExercise ?? "Failed to save exercise"}: $e',
              isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? (l10n?.editVocalDrill ?? 'Edit Vocal Drill')
                : (l10n?.addVocalDrill ?? 'Add Vocal Drill'),
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 19),
          ),
        ),
        body: WebContentWrapper(
          maxWidth: 800,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              physics: const BouncingScrollPhysics(),
              children: [
                // Section 1: Details
                AdminSectionHeader(
                  title: l10n?.exerciseInformation ?? 'Exercise Information',
                  icon: Icons.fitness_center_rounded,
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                ),
                AdminGlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (!widget.isGeneralExercise) ...[
                        TextFormField(
                          controller: _dayController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600),
                          decoration: _inputDecoration(
                              l10n?.dayNumberCurriculum ??
                                  'Day Number in Curriculum *',
                              Icons.format_list_numbered_rounded),
                          validator: (v) => v!.trim().isEmpty
                              ? (l10n?.dayNumberRequired ??
                                  'Day number is required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _titleController,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(
                            l10n?.exerciseTitleField ?? 'Exercise Title *',
                            Icons.title_rounded),
                        validator: (v) => v!.trim().isEmpty
                            ? (l10n?.titleRequired ?? 'Title is required')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5, height: 1.4),
                        decoration: _inputDecoration(
                            l10n?.descriptionInstructionsField ??
                                'Description & Instructions *',
                            Icons.description_outlined,
                            alignLabel: true),
                        minLines: 4,
                        maxLines: 8,
                        validator: (v) => v!.trim().isEmpty
                            ? (l10n?.descriptionRequired ??
                                'Description is required')
                            : null,
                      ),
                      if (!widget.isGeneralExercise) ...[
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: _isRestDay
                                ? AdminUiKit.amberOrange.withValues(alpha: 0.12)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isRestDay
                                  ? AdminUiKit.amberOrange.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n?.restDayPrompt ??
                                  'Is this a Rest & Recovery Day?',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              l10n?.restDayDescription ??
                                  'Rest days do not require audio drills.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            ),
                            value: _isRestDay,
                            activeThumbColor: AdminUiKit.amberOrange,
                            onChanged: (val) {
                              AdminUiKit.hapticLight();
                              setState(() => _isRestDay = val);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Section 2: Audio File
                if (!_isRestDay) ...[
                  const SizedBox(height: 20),
                  AdminSectionHeader(
                    title: l10n?.exerciseAudioGuide ?? 'Exercise Audio Guide',
                    icon: Icons.graphic_eq_rounded,
                    padding: const EdgeInsets.only(top: 8, bottom: 10),
                  ),
                  AdminGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: _buildAudioPicker(isDark, l10n),
                  ),
                ],

                const SizedBox(height: 28),

                AdminPrimaryButton(
                  label: widget.isEditing
                      ? (l10n?.saveDrillChanges ?? 'Save Drill Changes')
                      : (l10n?.publishVocalDrill ?? 'Publish Vocal Drill'),
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ));
  }

  Widget _buildAudioPicker(bool isDark, AppLocalizations? l10n) {
    final hasAudio = _pickedAudioFileName.isNotEmpty ||
        (_existingAudioUrl != null && _existingAudioUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasAudio
                ? AdminUiKit.emeraldGreen.withValues(alpha: 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasAudio
                  ? AdminUiKit.emeraldGreen.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasAudio
                      ? AdminUiKit.emeraldGreen.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.audiotrack_rounded,
                  color: hasAudio ? AdminUiKit.emeraldGreen : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pickedAudioFileName.isNotEmpty
                          ? _pickedAudioFileName
                          : (_existingAudioUrl != null
                              ? (l10n?.audioDrillAttached ??
                                  'Audio drill attached')
                              : (l10n?.noAudioFileSelected ??
                                  'No audio file selected')),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAudio
                          ? (l10n?.readyForPlayback ?? 'Ready for playback')
                          : (l10n?.uploadAudioDrillPrompt ??
                              'Upload MP3, WAV, or AAC audio drill'),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _pickAudio,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                  foregroundColor:
                      isDark ? AdminUiKit.primaryNavy : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(hasAudio
                    ? (l10n?.changeAudio ?? 'Change')
                    : (l10n?.uploadAudio ?? 'Upload')),
              ),
            ],
          ),
        ),
        if (_isSaving && _uploadProgress > 0 && _uploadProgress < 1) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
              value: _uploadProgress, color: AdminUiKit.goldAccent),
          const SizedBox(height: 4),
          Text(
            '${l10n?.uploadingAudio ?? "Uploading audio file"}: ${(_uploadProgress * 100).toInt()}%',
            style:
                GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {bool alignLabel = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      prefixIcon: Icon(icon, size: 20),
      alignLabelWithHint: alignLabel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
