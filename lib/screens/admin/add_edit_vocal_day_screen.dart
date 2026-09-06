import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../../models/vocal_plan_catalog.dart';
import '../../models/vocal_plan_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';

enum VocalDaySavePhase { idle, uploading, saving }

@visibleForTesting
String vocalAudioDisplayName(String? url, {String? pickedName}) {
  if (pickedName != null && pickedName.trim().isNotEmpty) {
    return pickedName.trim();
  }
  if (url == null || url.trim().isEmpty) return '';
  try {
    final name = Uri.decodeComponent(Uri.parse(url).pathSegments.last);
    return name.isEmpty ? 'audio' : name;
  } catch (_) {
    return 'audio';
  }
}

@visibleForTesting
String formatUploadBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AddEditVocalDayScreen extends StatefulWidget {
  final String? planId;
  final VocalExerciseDay? existingDay;
  final bool isGeneralExercise;
  final List<int> occupiedDayNumbers;
  final int? suggestedDayNumber;

  const AddEditVocalDayScreen({
    super.key,
    this.planId,
    this.existingDay,
    this.isGeneralExercise = false,
    this.occupiedDayNumbers = const [],
    this.suggestedDayNumber,
  });

  bool get isEditing => existingDay != null;

  @override
  State<AddEditVocalDayScreen> createState() => _AddEditVocalDayScreenState();
}

class _AddEditVocalDayScreenState extends State<AddEditVocalDayScreen> {
  AppLocalizations? get l10n => AppLocalizations.of(context);

  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _previewPlayer = AudioPlayer();

  late TextEditingController _dayController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isRestDay = false;

  Uint8List? _pickedAudioBytes;
  String? _originalAudioUrl;
  String? _existingAudioUrl;
  String _pickedAudioFileName = '';
  bool _existingAudioRemoved = false;

  bool _isSaving = false;
  VocalDaySavePhase _savePhase = VocalDaySavePhase.idle;
  double _uploadProgress = 0.0;
  int _uploadedBytes = 0;
  int _uploadTotalBytes = 0;

  PlayerState _previewState = PlayerState.stopped;
  bool _previewLoading = false;
  StreamSubscription<PlayerState>? _previewStateSub;
  StreamSubscription<void>? _previewCompleteSub;

  int get _expectedDays =>
      widget.planId == null ? 0 : VocalPlanCatalog.expectedDaysFor(widget.planId!);

  bool get _hasReplacement => _pickedAudioBytes != null;

  bool get _hasExistingAudio =>
      !_existingAudioRemoved &&
      _existingAudioUrl != null &&
      _existingAudioUrl!.isNotEmpty;

  bool get _hasAudio => _hasReplacement || _hasExistingAudio;

  bool get _hasUnsavedChanges {
    if (_isSaving) return false;
    if (widget.isEditing) {
      final day = widget.existingDay!;
      return _dayController.text.trim() != day.dayNumber.toString() ||
          _titleController.text.trim() != day.title ||
          _descriptionController.text.trim() != day.description ||
          _isRestDay != day.isRestDay ||
          _hasReplacement ||
          _existingAudioRemoved;
    }
    final suggested = widget.suggestedDayNumber;
    final initialDay =
        suggested != null && suggested > 0 ? suggested.toString() : '';
    return _dayController.text.trim() != initialDay ||
        _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _hasReplacement ||
        _isRestDay;
  }

  @override
  void initState() {
    super.initState();
    final suggested = widget.suggestedDayNumber;
    _dayController = TextEditingController(
      text: widget.isEditing
          ? widget.existingDay!.dayNumber.toString()
          : (suggested != null && suggested > 0 ? suggested.toString() : ''),
    );
    _titleController = TextEditingController(
      text: widget.isEditing ? widget.existingDay!.title : '',
    );
    _descriptionController = TextEditingController(
      text: widget.isEditing ? widget.existingDay!.description : '',
    );
    _isRestDay = widget.isEditing ? widget.existingDay!.isRestDay : false;
    _originalAudioUrl = widget.isEditing ? widget.existingDay!.audioUrl : null;
    _existingAudioUrl = _originalAudioUrl;
    _dayController.addListener(_onFormChanged);
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _previewStateSub = _previewPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _previewState = state);
    });
    _previewCompleteSub = _previewPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _previewState = PlayerState.completed);
    });
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _previewStateSub?.cancel();
    _previewCompleteSub?.cancel();
    _previewPlayer.dispose();
    _dayController.removeListener(_onFormChanged);
    _titleController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _dayController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _stopPreview() async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _previewState = PlayerState.stopped;
        _previewLoading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.unsavedDraftFound ?? 'Unsaved Changes',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n?.discardUnsavedVocalDay ??
              'Discard unsaved changes to this vocal drill?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancel ?? 'Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.discard ?? 'Discard'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String? _validateDayNumber(String? value) {
    if (widget.isGeneralExercise) return null;
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return l10n?.dayNumberRequired ?? 'Day number is required';
    }
    final number = int.tryParse(raw);
    if (number == null || number < 1) {
      return l10n?.dayNumberInvalid ?? 'Enter a day number of 1 or higher';
    }
    if (widget.occupiedDayNumbers.contains(number)) {
      return l10n?.dayNumberDuplicate(number) ??
          'Day $number already exists in this plan';
    }
    if (VocalPlanCatalog.enforcesDayRange(widget.planId ?? '') &&
        number > _expectedDays) {
      return l10n?.dayNumberOutOfRange(_expectedDays) ??
          'This plan uses days 1–$_expectedDays';
    }
    return null;
  }

  Future<void> _pickAudio() async {
    if (_isSaving) return;
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
          await _stopPreview();
          setState(() {
            _pickedAudioBytes = bytes;
            _pickedAudioFileName = file.name;
            _existingAudioRemoved = false;
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

  Future<void> _removeAudio() async {
    if (_isSaving || !_hasAudio) return;

    if (_hasExistingAudio && !_hasReplacement) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n?.confirmRemoveAudioTitle ?? 'Remove audio?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            l10n?.confirmRemoveAudioBody ??
                'This audio will be detached from the drill. Upload a replacement before saving if the exercise still needs audio.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AdminUiKit.roseRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n?.removeAudio ?? l10n?.remove ?? 'Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _stopPreview();
    setState(() {
      _pickedAudioBytes = null;
      _pickedAudioFileName = '';
      if (_originalAudioUrl != null && _originalAudioUrl!.isNotEmpty) {
        _existingAudioRemoved = true;
        _existingAudioUrl = null;
      }
    });
  }

  Future<void> _keepExistingAudio() async {
    if (_isSaving) return;
    await _stopPreview();
    setState(() {
      _pickedAudioBytes = null;
      _pickedAudioFileName = '';
      _existingAudioRemoved = false;
      _existingAudioUrl = _originalAudioUrl;
    });
  }

  Future<void> _togglePreview() async {
    if (_isSaving || _previewLoading || !_hasAudio) return;

    if (_previewState == PlayerState.playing) {
      await _previewPlayer.pause();
      return;
    }

    setState(() => _previewLoading = true);
    try {
      if (_previewState == PlayerState.paused) {
        await _previewPlayer.resume();
      } else if (_pickedAudioBytes != null) {
        await _previewPlayer.play(BytesSource(_pickedAudioBytes!));
      } else if (_hasExistingAudio) {
        await _previewPlayer.play(UrlSource(_existingAudioUrl!));
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          l10n?.audioPreviewFailed ?? 'Could not play this audio file',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    await _stopPreview();
    setState(() {
      _isSaving = true;
      _savePhase = _hasReplacement
          ? VocalDaySavePhase.uploading
          : VocalDaySavePhase.saving;
      _uploadProgress = 0.0;
      _uploadedBytes = 0;
      _uploadTotalBytes = _pickedAudioBytes?.length ?? 0;
    });

    try {
      String? finalAudioUrl = _existingAudioRemoved ? null : _existingAudioUrl;

      if (_pickedAudioBytes != null) {
        final ext = p.extension(_pickedAudioFileName);
        final uploadedUrl = await SupabaseStorageService.uploadAudioBytes(
          _pickedAudioBytes!,
          extension: ext.isNotEmpty ? ext : '.mp3',
          folder: 'vocal-plans',
          onProgress: (count, total) {
            if (!mounted) return;
            final actualTotal = total > 0 ? total : _pickedAudioBytes!.length;
            setState(() {
              _savePhase = VocalDaySavePhase.uploading;
              _uploadedBytes = count.clamp(0, actualTotal);
              _uploadTotalBytes = actualTotal;
              _uploadProgress =
                  actualTotal > 0 ? (count / actualTotal).clamp(0.0, 1.0) : 0.0;
            });
          },
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
            setState(() {
              _isSaving = false;
              _savePhase = VocalDaySavePhase.idle;
            });
          }
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
          setState(() {
            _isSaving = false;
            _savePhase = VocalDaySavePhase.idle;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _savePhase = VocalDaySavePhase.saving);
      }

      final dayData = VocalExerciseDay.fromForm(
        id: widget.isEditing ? widget.existingDay!.id : '',
        dayNumber: int.tryParse(_dayController.text.trim()) ?? 0,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isRestDay: widget.isGeneralExercise ? false : _isRestDay,
        audioUrl: finalAudioUrl,
      );
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final moderator = authProvider.currentModerator;

      if (widget.isGeneralExercise) {
        if (widget.isEditing) {
          await _firebaseService.updateGeneralExercise(
              dayData.id, dayData.toJson());
          if (user != null && moderator != null) {
            _firebaseService.logActivity(
              moderatorId: user.uid,
              moderatorName: moderator.fullName,
              action: 'UPDATE_EXERCISE',
              details: 'Updated general exercise: "${dayData.title}"',
            );
          }
        } else {
          await _firebaseService.addGeneralExercise(dayData);
          if (user != null && moderator != null) {
            _firebaseService.logActivity(
              moderatorId: user.uid,
              moderatorName: moderator.fullName,
              action: 'CREATE_EXERCISE',
              details: 'Added general exercise: "${dayData.title}"',
            );
          }
        }
      } else {
        if (widget.isEditing) {
          await _firebaseService.updateVocalExerciseDay(
              widget.planId!, dayData.id, dayData);
          if (user != null && moderator != null) {
            _firebaseService.logActivity(
              moderatorId: user.uid,
              moderatorName: moderator.fullName,
              action: 'UPDATE_EXERCISE_DAY',
              details:
                  'Updated vocal plan day ${dayData.dayNumber}: "${dayData.title}"',
            );
          }
        } else {
          await _firebaseService.addVocalExerciseDay(widget.planId!, dayData);
          if (user != null && moderator != null) {
            _firebaseService.logActivity(
              moderatorId: user.uid,
              moderatorName: moderator.fullName,
              action: 'CREATE_EXERCISE_DAY',
              details:
                  'Added vocal plan day ${dayData.dayNumber}: "${dayData.title}"',
            );
          }
        }
      }

      final previousUrl = _originalAudioUrl;
      if (previousUrl != null &&
          previousUrl.isNotEmpty &&
          previousUrl != finalAudioUrl) {
        unawaited(SupabaseStorageService.deleteFile(previousUrl));
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _savePhase = VocalDaySavePhase.idle;
        });
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
        setState(() {
          _isSaving = false;
          _savePhase = VocalDaySavePhase.idle;
        });
        CustomSnackbar.show(context,
            '${l10n?.failedToSaveExercise ?? "Failed to save exercise"}: $e',
            isError: true);
      }
    }
  }

  String _saveButtonLabel(AppLocalizations? l10n) {
    if (_isSaving && _savePhase == VocalDaySavePhase.uploading) {
      final percent = (_uploadProgress * 100).clamp(0, 100).toInt();
      return '${l10n?.uploadingAudio ?? "Uploading audio file"} $percent%';
    }
    if (_isSaving) {
      return l10n?.savingVocalDrill ?? 'Saving vocal drill...';
    }
    return widget.isEditing
        ? (l10n?.saveDrillChanges ?? 'Save Drill Changes')
        : (l10n?.publishVocalDrill ?? 'Publish Vocal Drill');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_isSaving && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSaving) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
        body: AdminFormBody(
          maxWidth: 800,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              physics: const BouncingScrollPhysics(),
              children: [
                if (_isSaving) ...[
                  _UploadStatusBanner(
                    phase: _savePhase,
                    progress: _uploadProgress,
                    uploadedBytes: _uploadedBytes,
                    totalBytes: _uploadTotalBytes,
                  ),
                  const SizedBox(height: 12),
                ],
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
                          enabled: !_isSaving,
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
                          validator: _validateDayNumber,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _titleController,
                        enabled: !_isSaving,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(
                            l10n?.exerciseTitleField ?? 'Exercise Title *',
                            Icons.title_rounded),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? (l10n?.titleRequired ?? 'Title is required')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_isSaving,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5, height: 1.4),
                        decoration: _inputDecoration(
                            l10n?.descriptionInstructionsField ??
                                'Description & Instructions *',
                            Icons.description_outlined,
                            alignLabel: true),
                        minLines: 4,
                        maxLines: 8,
                        validator: (v) => (v ?? '').trim().isEmpty
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
                            onChanged: _isSaving
                                ? null
                                : (val) {
                                    AdminUiKit.hapticLight();
                                    setState(() => _isRestDay = val);
                                  },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
                  label: _saveButtonLabel(l10n),
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submit,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPicker(bool isDark, AppLocalizations? l10n) {
    final canRestoreOriginal = _originalAudioUrl != null &&
        _originalAudioUrl!.isNotEmpty &&
        (_existingAudioRemoved || _hasReplacement);
    final displayName = vocalAudioDisplayName(
      _hasExistingAudio ? _existingAudioUrl : null,
      pickedName: _hasReplacement ? _pickedAudioFileName : null,
    );
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (_isSaving && _savePhase == VocalDaySavePhase.uploading) {
      statusColor = AdminUiKit.royalBlue;
      statusText = _uploadStatusText(l10n);
      statusIcon = Icons.cloud_upload_rounded;
    } else if (_isSaving) {
      statusColor = AdminUiKit.goldAccent;
      statusText = l10n?.savingVocalDrill ?? 'Saving vocal drill...';
      statusIcon = Icons.save_rounded;
    } else if (_hasReplacement &&
        _originalAudioUrl != null &&
        _originalAudioUrl!.isNotEmpty) {
      statusColor = AdminUiKit.amberOrange;
      statusText = l10n?.audioPendingReplacement ?? 'Ready to replace on save';
      statusIcon = Icons.swap_horiz_rounded;
    } else if (_hasReplacement) {
      statusColor = AdminUiKit.emeraldGreen;
      statusText = l10n?.replacementAudioSelected ?? 'Replacement selected';
      statusIcon = Icons.audio_file_rounded;
    } else if (_existingAudioRemoved) {
      statusColor = AdminUiKit.roseRed;
      statusText = l10n?.audioMarkedForRemoval ?? 'Will be removed when you save';
      statusIcon = Icons.link_off_rounded;
    } else if (_hasExistingAudio) {
      statusColor = AdminUiKit.emeraldGreen;
      statusText = l10n?.previouslyUploadedAudio ?? 'Previously uploaded';
      statusIcon = Icons.cloud_done_rounded;
    } else {
      statusColor = Colors.grey;
      statusText = l10n?.uploadAudioDrillPrompt ??
          'Upload MP3, WAV, or AAC audio drill';
      statusIcon = Icons.audiotrack_rounded;
    }

    final title = displayName.isNotEmpty
        ? displayName
        : (_existingAudioRemoved
            ? (l10n?.noAudioFileSelected ?? 'No audio file selected')
            : (l10n?.noAudioFileSelected ?? 'No audio file selected'));
    final sizeLabel = _hasReplacement
        ? formatUploadBytes(_pickedAudioBytes!.length)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hasAudio
                ? statusColor.withValues(alpha: 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasAudio
                  ? statusColor.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
                          sizeLabel == null
                              ? statusText
                              : '$statusText · $sizeLabel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_hasAudio)
                    _AudioActionChip(
                      icon: _previewLoading
                          ? Icons.hourglass_top_rounded
                          : (_previewState == PlayerState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                      label: _previewState == PlayerState.playing
                          ? (l10n?.pausePreview ?? 'Pause')
                          : (l10n?.previewAudio ?? 'Preview'),
                      color: AdminUiKit.royalBlue,
                      enabled: !_isSaving && !_previewLoading,
                      onPressed: _togglePreview,
                    ),
                  _AudioActionChip(
                    icon: _hasAudio
                        ? Icons.swap_horiz_rounded
                        : Icons.upload_rounded,
                    label: _hasAudio
                        ? (l10n?.replaceAudio ?? l10n?.changeAudio ?? 'Replace')
                        : (l10n?.uploadAudio ?? 'Upload'),
                    color: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                    enabled: !_isSaving,
                    filled: true,
                    onPressed: _pickAudio,
                  ),
                  if (_hasAudio)
                    _AudioActionChip(
                      icon: Icons.delete_outline_rounded,
                      label: l10n?.removeAudio ?? l10n?.remove ?? 'Remove',
                      color: AdminUiKit.roseRed,
                      enabled: !_isSaving,
                      onPressed: _removeAudio,
                    ),
                  if (canRestoreOriginal)
                    _AudioActionChip(
                      icon: Icons.undo_rounded,
                      label: l10n?.keepExistingAudio ?? 'Keep existing audio',
                      color: AdminUiKit.emeraldGreen,
                      enabled: !_isSaving,
                      onPressed: _keepExistingAudio,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_isSaving &&
            (_savePhase == VocalDaySavePhase.uploading ||
                _hasReplacement)) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _savePhase == VocalDaySavePhase.uploading
                  ? (_uploadProgress <= 0 ? null : _uploadProgress)
                  : 1,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _savePhase == VocalDaySavePhase.saving
                    ? AdminUiKit.emeraldGreen
                    : AdminUiKit.royalBlue,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _savePhase == VocalDaySavePhase.uploading
                ? _uploadStatusText(l10n)
                : (l10n?.audioUploadComplete ?? 'Upload complete'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _savePhase == VocalDaySavePhase.saving
                  ? AdminUiKit.emeraldGreen
                  : AdminUiKit.royalBlue,
            ),
          ),
        ],
      ],
    );
  }

  String _uploadStatusText(AppLocalizations? l10n) {
    if (_uploadTotalBytes <= 0 || _uploadProgress <= 0) {
      return l10n?.preparingAudioUpload ?? 'Preparing audio upload...';
    }
    final percent = (_uploadProgress * 100).clamp(0, 100).toStringAsFixed(0);
    return l10n?.uploadingAudioProgress(
          formatUploadBytes(_uploadedBytes),
          formatUploadBytes(_uploadTotalBytes),
          percent,
        ) ??
        'Uploading ${formatUploadBytes(_uploadedBytes)} of ${formatUploadBytes(_uploadTotalBytes)} · $percent%';
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

class _UploadStatusBanner extends StatelessWidget {
  const _UploadStatusBanner({
    required this.phase,
    required this.progress,
    required this.uploadedBytes,
    required this.totalBytes,
  });

  final VocalDaySavePhase phase;
  final double progress;
  final int uploadedBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final uploading = phase == VocalDaySavePhase.uploading;
    final color = uploading ? AdminUiKit.royalBlue : AdminUiKit.goldAccent;
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    final label = uploading
        ? (totalBytes <= 0 || progress <= 0
            ? (l10n?.preparingAudioUpload ?? 'Preparing audio upload...')
            : (l10n?.uploadingAudioProgress(
                  formatUploadBytes(uploadedBytes),
                  formatUploadBytes(totalBytes),
                  percent,
                ) ??
                'Uploading ${formatUploadBytes(uploadedBytes)} of ${formatUploadBytes(totalBytes)} · $percent%'))
        : (l10n?.savingVocalDrill ?? 'Saving vocal drill...');

    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  value: uploading && progress > 0 ? progress : null,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: uploading && progress > 0 ? progress : null,
              minHeight: 7,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioActionChip extends StatelessWidget {
  const _AudioActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.enabled = true,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool enabled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color.computeLuminance() > 0.55
              ? AdminUiKit.primaryNavy
              : Colors.white,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
