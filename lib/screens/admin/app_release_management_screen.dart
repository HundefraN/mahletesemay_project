import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../models/app_config_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/force_update_service.dart';
import '../../services/supabase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../update/app_update_lock_screen.dart';

/// Admin Screen for managing application versions, force updates, and APK releases
/// hosted on Supabase Storage (`app-releases` bucket) and database table `app_config`.
class AppReleaseManagementScreen extends StatefulWidget {
  const AppReleaseManagementScreen({super.key});

  @override
  State<AppReleaseManagementScreen> createState() =>
      _AppReleaseManagementScreenState();
}

class _AppReleaseManagementScreenState extends State<AppReleaseManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latestVersionController = TextEditingController();
  final _minRequiredVersionController = TextEditingController();
  final _releaseNotesController = TextEditingController();
  final _apkUrlController = TextEditingController();

  bool _forceUpdate = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingApk = false;
  double _uploadProgress = 0.0;

  PlatformFile? _pickedApkFile;
  Uint8List? _pickedApkBytes;
  AppConfigModel? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _latestVersionController.dispose();
    _minRequiredVersionController.dispose();
    _releaseNotesController.dispose();
    _apkUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await SupabaseService().getAppConfig();
      if (mounted) {
        setState(() {
          _currentConfig = config;
          _latestVersionController.text = config?.latestVersion ?? '1.0.0';
          _minRequiredVersionController.text = config?.minRequiredVersion ?? '1.0.0';
          _releaseNotesController.text = config?.releaseNotes ?? '';
          _apkUrlController.text = config?.apkUrl ?? '';
          _forceUpdate = config?.forceUpdate ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.show(context, 'Error loading configuration: $e', isError: true);
      }
    }
  }

  Future<void> _pickApkFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: true, // Required for Web and direct byte upload
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;

        // On desktop/mobile, if bytes is null, read from path
        if (bytes == null && file.path != null && !kIsWeb) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes == null) {
          if (mounted) {
            CustomSnackbar.show(context, 'Could not read file data. Try again.', isError: true);
          }
          return;
        }

        setState(() {
          _pickedApkFile = file;
          _pickedApkBytes = bytes;
        });

        if (mounted) {
          CustomSnackbar.show(
            context,
            'Selected APK: ${file.name} (${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB)',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Error selecting APK: $e', isError: true);
      }
    }
  }

  Future<void> _uploadApkToSupabase() async {
    if (_pickedApkBytes == null || _pickedApkFile == null) {
      CustomSnackbar.show(context, 'Please choose an .apk file first', isError: true);
      return;
    }

    setState(() {
      _isUploadingApk = true;
      _uploadProgress = 0.1;
    });

    try {
      final fileName = _pickedApkFile!.name.isNotEmpty
          ? _pickedApkFile!.name
          : 'mahlete_semay_v${_latestVersionController.text.trim()}.apk';

      // Upload binary to Supabase 'app-releases' bucket
      final uploadedUrl = await SupabaseStorageService.uploadApkBytes(
        _pickedApkBytes!,
        fileName: fileName,
        bucket: 'app-releases',
        onProgress: (count, total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = count / total;
            });
          }
        },
      );

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() {
          _apkUrlController.text = uploadedUrl;
          _uploadProgress = 1.0;
        });

        if (mounted) {
          CustomSnackbar.show(context, 'APK uploaded successfully to Supabase Storage!');
        }
      } else {
        throw Exception('Upload returned empty URL. Please verify storage bucket permissions.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Upload error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingApk = false);
      }
    }
  }

  Future<void> _saveReleaseConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) {
      CustomSnackbar.show(context, 'Unauthorized: Only Administrators can publish app releases.', isError: true);
      return;
    }

    final latestVer = _latestVersionController.text.trim();
    final minVer = _minRequiredVersionController.text.trim();
    final notes = _releaseNotesController.text.trim();
    final apkUrl = _apkUrlController.text.trim();

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Publish App Release?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will update the global app configuration.\n\n'
          '• Latest Version: $latestVer\n'
          '• Minimum Required: $minVer\n'
          '• Force Update: ${_forceUpdate ? "ACTIVE (All users locked)" : "INACTIVE"}\n'
          '• APK URL: ${apkUrl.isNotEmpty ? apkUrl : "None"}',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.royalBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final adminId = authProvider.currentModerator?.id ?? authProvider.currentUser?.id ?? 'admin';
      final adminName = authProvider.currentModerator?.fullName ?? authProvider.currentUser?.email ?? 'Admin';

      final newConfig = AppConfigModel(
        id: 'default',
        latestVersion: latestVer,
        minRequiredVersion: minVer,
        apkUrl: apkUrl.isNotEmpty ? apkUrl : null,
        releaseNotes: notes.isNotEmpty ? notes : null,
        forceUpdate: _forceUpdate,
        updatedAt: DateTime.now().toUtc(),
      );

      await SupabaseService().saveAppConfig(newConfig, adminId, adminName);

      if (mounted) {
        setState(() {
          _currentConfig = newConfig;
          _isSaving = false;
        });
        CustomSnackbar.show(context, 'App Release published successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        CustomSnackbar.show(context, 'Error publishing release: $e', isError: true);
      }
    }
  }

  void _previewLockScreen() {
    final previewConfig = AppConfigModel(
      id: 'preview',
      latestVersion: _latestVersionController.text.trim().isNotEmpty
          ? _latestVersionController.text.trim()
          : '1.2.0',
      minRequiredVersion: _minRequiredVersionController.text.trim().isNotEmpty
          ? _minRequiredVersionController.text.trim()
          : '1.1.0',
      apkUrl: _apkUrlController.text.trim(),
      releaseNotes: _releaseNotesController.text.trim().isNotEmpty
          ? _releaseNotesController.text.trim()
          : '• Brand new modern home interface\n• Performance optimizations and bug fixes\n• Instant background lyrics synchronization',
      forceUpdate: _forceUpdate,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Lock Screen Live Preview'),
            backgroundColor: AdminUiKit.primaryNavy,
          ),
          body: AppUpdateLockScreen(config: previewConfig),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only Administrators can access App Release Management.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'App Version & APK Release',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0A1E3F) : AdminUiKit.primaryNavy,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Preview Lock Screen UI',
            icon: const Icon(Icons.remove_red_eye_rounded, color: AdminUiKit.goldHighlight),
            onPressed: _previewLockScreen,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadCurrentConfig,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminUiKit.goldAccent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Current Active Release Summary Card
                        _buildCurrentStatusCard(isDark),
                        const SizedBox(height: 24),

                        // 2. Form Section Header
                        const AdminSectionHeader(
                          title: 'Configure Release & Semver',
                          icon: Icons.tune_rounded,
                        ),
                        const SizedBox(height: 12),

                        // Form Container Card
                        AdminGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Latest Version
                              Text(
                                'Latest App Version',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _latestVersionController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 1.2.0',
                                  prefixIcon: const Icon(Icons.verified_outlined, size: 20),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter latest version';
                                  }
                                  if (ForceUpdateService.parseVersion(val) == null) {
                                    return 'Invalid semver (e.g. 1.2.0)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Min Required Version
                              Text(
                                'Minimum Required Version',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Users running any version below this will be strictly blocked from using the app until they update.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _minRequiredVersionController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 1.1.0',
                                  prefixIcon: const Icon(Icons.security_rounded, size: 20),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter minimum required version';
                                  }
                                  if (ForceUpdateService.parseVersion(val) == null) {
                                    return 'Invalid semver (e.g. 1.1.0)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Force Update All Switch
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (_forceUpdate ? AdminUiKit.roseRed : AdminUiKit.royalBlue).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (_forceUpdate ? AdminUiKit.roseRed : AdminUiKit.royalBlue).withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _forceUpdate ? Icons.lock_rounded : Icons.lock_open_rounded,
                                      color: _forceUpdate ? AdminUiKit.roseRed : AdminUiKit.royalBlue,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Force Update All Users',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                            ),
                                          ),
                                          Text(
                                            _forceUpdate
                                                ? 'Active: All users will be locked out immediately until updated'
                                                : 'Inactive: Only users below min required version are locked',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: _forceUpdate ? AdminUiKit.roseRed : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _forceUpdate,
                                      activeTrackColor: AdminUiKit.roseRed,
                                      onChanged: (val) => setState(() => _forceUpdate = val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Release Notes Field
                              Text(
                                'Release Notes & Changelog',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _releaseNotesController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: '• New features, bug fixes, and improvements...',
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 3. Supabase Storage APK Upload Section
                        const AdminSectionHeader(
                          title: 'APK Upload & Hosting (Supabase Storage)',
                          icon: Icons.cloud_upload_rounded,
                        ),
                        const SizedBox(height: 12),

                        AdminGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload New Android APK (.apk)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Directly uploads to bucket "app-releases". Android clients will download from here with live progress.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Pick & Upload Row
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        side: BorderSide(
                                          color: AdminUiKit.royalBlue.withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _isUploadingApk ? null : _pickApkFile,
                                      icon: const Icon(Icons.file_present_rounded, color: AdminUiKit.royalBlue),
                                      label: Text(
                                        _pickedApkFile != null
                                            ? _pickedApkFile!.name
                                            : 'Choose .apk File',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AdminUiKit.royalBlue,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: (_pickedApkBytes != null && !_isUploadingApk)
                                        ? _uploadApkToSupabase
                                        : null,
                                    icon: _isUploadingApk
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                                    label: Text(
                                      _isUploadingApk ? 'Uploading...' : 'Upload',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Upload progress bar
                              if (_isUploadingApk) ...[
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _uploadProgress > 0 ? _uploadProgress : null,
                                    minHeight: 8,
                                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AdminUiKit.royalBlue),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Uploading to Supabase: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AdminUiKit.royalBlue),
                                ),
                              ],

                              const SizedBox(height: 18),

                              // Public APK URL field
                              Text(
                                'Hosted APK Public URL',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _apkUrlController,
                                decoration: InputDecoration(
                                  hintText: 'https://.../storage/v1/object/public/app-releases/apks/...',
                                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                                  suffixIcon: _apkUrlController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                          onPressed: () async {
                                            final uri = Uri.tryParse(_apkUrlController.text.trim());
                                            if (uri != null && await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 4. Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: AdminUiKit.goldAccent.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _previewLockScreen,
                                icon: const Icon(Icons.preview_rounded, color: AdminUiKit.goldAccent),
                                label: Text(
                                  'Preview Lock Screen',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AdminUiKit.emeraldGreen,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                onPressed: _isSaving ? null : _saveReleaseConfig,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.publish_rounded, color: Colors.white, size: 20),
                                label: Text(
                                  _isSaving ? 'Publishing...' : 'Publish Release',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentStatusCard(bool isDark) {
    final latest = _currentConfig?.latestVersion ?? 'Not configured';
    final minVer = _currentConfig?.minRequiredVersion ?? 'None';
    final isForced = _currentConfig?.forceUpdate ?? false;
    final apkUrl = _currentConfig?.apkUrl;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1D33) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isForced ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isForced ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isForced ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: isForced ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Active Release Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                    ),
                  ),
                ],
              ),
              AdminStatusBadge(
                label: isForced ? 'FORCE UPDATE' : 'ACTIVE',
                color: isForced ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'LATEST VERSION',
                  'v$latest',
                  AdminUiKit.royalBlue,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'MIN REQUIRED',
                  'v$minVer',
                  isForced ? AdminUiKit.roseRed : AdminUiKit.amberOrange,
                  isDark,
                ),
              ),
            ],
          ),
          if (apkUrl != null && apkUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.android_rounded, size: 16, color: AdminUiKit.emeraldGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    apkUrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: apkUrl));
                    CustomSnackbar.show(context, 'APK URL copied to clipboard');
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AdminUiKit.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}
