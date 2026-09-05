import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../models/bug_report_model.dart';
import '../../services/crash_report_service.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/web_content_wrapper.dart';

class _PickedShot {
  final Uint8List bytes;
  final String extension;

  const _PickedShot({required this.bytes, required this.extension});
}

class ReportBugScreen extends StatefulWidget {
  final BugReportType? initialType;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialStackTrace;
  final bool clearPendingCrashOnSuccess;

  const ReportBugScreen({
    super.key,
    this.initialType,
    this.initialTitle,
    this.initialDescription,
    this.initialStackTrace,
    this.clearPendingCrashOnSuccess = false,
  });

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  static const int _maxScreenshots = 5;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _firebaseService = FirebaseService();

  late BugReportType _type;
  final List<_PickedShot> _shots = [];
  DeviceReportMeta? _deviceMeta;
  bool _isLoading = false;
  bool _isOffline = false;
  String? _uploadStatus;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? BugReportType.bug;
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    _checkInitialConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    _loadDeviceMeta();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceMeta() async {
    final meta = await CrashReportService.collectDeviceMeta();
    if (mounted) setState(() => _deviceMeta = meta);
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (!mounted) return;
    setState(() {
      _isOffline = !result.contains(ConnectivityResult.mobile) &&
          !result.contains(ConnectivityResult.wifi) &&
          !result.contains(ConnectivityResult.ethernet) &&
          !result.contains(ConnectivityResult.vpn);
    });
  }

  Future<void> _addFromGallery() async {
    final remaining = _maxScreenshots - _shots.length;
    if (remaining <= 0) {
      _showLimitSnack();
      return;
    }
    final hasPermission = await PermissionHelper.requestPhotoAccess(context);
    if (!hasPermission || !mounted) return;

    final picker = ImagePicker();
    if (remaining == 1) {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file != null) await _appendPicked([file]);
    } else {
      final files = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (files.isNotEmpty) {
        await _appendPicked(files.take(remaining).toList());
      }
    }
  }

  Future<void> _addFromCamera() async {
    if (_shots.length >= _maxScreenshots) {
      _showLimitSnack();
      return;
    }
    final hasPermission = await PermissionHelper.requestCameraAccess(context);
    if (!hasPermission || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file != null) await _appendPicked([file]);
  }

  Future<void> _appendPicked(List<XFile> files) async {
    final l10n = AppLocalizations.of(context)!;
    for (final file in files) {
      if (_shots.length >= _maxScreenshots) {
        if (mounted) {
          CustomSnackbar.show(context, l10n.reportMaxScreenshots(_maxScreenshots));
        }
        break;
      }
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        var ext = '.jpg';
        final name = file.name.toLowerCase();
        if (name.endsWith('.png')) {
          ext = '.png';
        } else if (name.endsWith('.webp')) {
          ext = '.webp';
        } else if (name.endsWith('.heic') || name.endsWith('.heif')) {
          ext = '.jpg';
        }
        _shots.add(_PickedShot(bytes: bytes, extension: ext));
      } catch (e) {
        debugPrint('Failed to read screenshot: $e');
      }
    }
    if (mounted) setState(() {});
  }

  void _showLimitSnack() {
    CustomSnackbar.show(
      context,
      AppLocalizations.of(context)!.reportMaxScreenshots(_maxScreenshots),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_isOffline) {
      CustomSnackbar.show(context, l10n.reportOffline, isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadStatus = _shots.isEmpty ? null : l10n.reportPleaseWait;
    });

    try {
      final uploadedUrls = <String>[];
      for (var i = 0; i < _shots.length; i++) {
        if (mounted) {
          setState(() {
            _uploadStatus = l10n.reportUploadingScreenshot(i + 1, _shots.length);
          });
        }
        final url = await SupabaseStorageService.uploadImageBytes(
          _shots[i].bytes,
          extension: _shots[i].extension,
          bucket: 'bug-reports',
          folder: 'screenshots',
        );
        if (url != null && url.isNotEmpty) {
          uploadedUrls.add(url);
        } else {
          throw Exception('Screenshot upload failed');
        }
      }

      final meta = _deviceMeta ?? await CrashReportService.collectDeviceMeta();
      final email = _emailController.text.trim();
      final now = DateTime.now();
      final report = BugReport(
        id: '',
        type: _type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        screenshotUrls: uploadedUrls,
        contactEmail: email.isEmpty ? null : email,
        appVersion: meta.appVersion,
        buildNumber: meta.buildNumber,
        platform: meta.platform,
        deviceModel: meta.deviceModel,
        osVersion: meta.osVersion,
        locale: meta.locale,
        stackTrace: widget.initialStackTrace,
        createdAt: now,
        updatedAt: now,
      );

      await _firebaseService.submitBugReport(report);
      if (widget.clearPendingCrashOnSuccess) {
        await CrashReportService.clearPending();
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
      CustomSnackbar.show(context, l10n.reportSuccess);
    } catch (e) {
      debugPrint('Bug report submit failed: $e');
      if (mounted) {
        CustomSnackbar.show(context, l10n.reportFailed, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF080E1A) : const Color(0xFFF7F9FC);
    final cardBg = isDark ? const Color(0xFF10192A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2E45) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF152238) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black87,
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: Text(
          l10n.reportABug,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF0B192C),
          ),
        ),
      ),
      body: Stack(
        children: [
          WebContentWrapper(
            maxWidth: 720,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
                children: [
                  _ModernHeroCard(isDark: isDark, l10n: l10n),
                  const SizedBox(height: 20),

                  if (_isOffline) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.reportOffline,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFEF4444),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Issue Type Section
                  _SectionHeader(
                    icon: Icons.category_rounded,
                    title: l10n.reportTypeLabel,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ModernTypeChip(
                          label: l10n.reportTypeBug,
                          icon: Icons.bug_report_rounded,
                          selected: _type == BugReportType.bug,
                          activeColor: const Color(0xFFF43F5E),
                          onTap: () => setState(() => _type = BugReportType.bug),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModernTypeChip(
                          label: l10n.reportTypeCrash,
                          icon: Icons.flash_on_rounded,
                          selected: _type == BugReportType.crash,
                          activeColor: const Color(0xFFF59E0B),
                          onTap: () => setState(() => _type = BugReportType.crash),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModernTypeChip(
                          label: l10n.reportTypeFeedback,
                          icon: Icons.lightbulb_rounded,
                          selected: _type == BugReportType.feedback,
                          activeColor: const Color(0xFF3B82F6),
                          onTap: () => setState(() => _type = BugReportType.feedback),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Issue Details Section
                  _SectionHeader(
                    icon: Icons.description_rounded,
                    title: l10n.reportTitleLabel,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _inputDecoration(
                      hint: l10n.reportTitleHint,
                      icon: Icons.title_rounded,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? l10n.reportTitleRequired : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 4,
                    maxLines: 8,
                    style: GoogleFonts.poppins(fontSize: 14, height: 1.45),
                    decoration: _inputDecoration(
                      hint: l10n.reportDescriptionHint,
                      icon: Icons.notes_rounded,
                      alignLabel: true,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.reportDescriptionRequired
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // 3. Media Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionHeader(
                        icon: Icons.attach_file_rounded,
                        title: l10n.reportScreenshots,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B283E) : const Color(0xFFE8EDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_shots.length}/$_maxScreenshots',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.reportScreenshotLimit(_maxScreenshots),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ScreenshotSection(
                    shots: _shots,
                    max: _maxScreenshots,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    onAddGallery: _addFromGallery,
                    onAddCamera: kIsWeb ? null : _addFromCamera,
                    onRemove: (index) => setState(() => _shots.removeAt(index)),
                    addPhotoLabel: l10n.reportAddScreenshot,
                    takePhotoLabel: l10n.reportTakePhoto,
                    removeLabel: l10n.reportRemoveScreenshot,
                  ),
                  const SizedBox(height: 24),

                  // 4. Contact Info
                  _SectionHeader(
                    icon: Icons.mail_outline_rounded,
                    title: l10n.reportContactEmail,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _inputDecoration(
                      hint: l10n.reportContactEmailHint,
                      icon: Icons.alternate_email_rounded,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      if (!text.contains('@') || !text.contains('.')) {
                        return l10n.pleaseEnterEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // 5. Diagnostics Card
                  _ModernDeviceInfoCard(
                    meta: _deviceMeta,
                    l10n: l10n,
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),
                ],
              ),
            ),
          ),

          // Floating Glassmorphic Submit Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ModernSubmitBar(
              isLoading: _isLoading,
              isOffline: _isOffline,
              status: _uploadStatus,
              label: l10n.reportSubmit,
              sendingLabel: l10n.reportSubmitting,
              offlineLabel: l10n.reportOffline,
              onSubmit: _submit,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color cardBg,
    required Color borderColor,
    bool alignLabel = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        fontSize: 13.5,
      ),
      alignLabelWithHint: alignLabel,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
      ),
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
          width: 1.6,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _ModernHeroCard extends StatelessWidget {
  final bool isDark;
  final AppLocalizations l10n;

  const _ModernHeroCard({required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF14243F), Color(0xFF0B1424)]
              : const [Color(0xFF0B1D3A), Color(0xFF1B3B6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE092), Color(0xFFDFB76C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDFB76C).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF0A1E3F), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reportHeroTitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.reportHeroSubtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModernTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? const Color(0xFF10192A) : Colors.white;
    final unselectedBorder = isDark ? const Color(0xFF1F2E45) : const Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? activeColor.withValues(alpha: isDark ? 0.18 : 0.1) : unselectedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? activeColor : unselectedBorder,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.2)
                      : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? activeColor : (isDark ? Colors.white60 : Colors.black54),
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotSection extends StatelessWidget {
  final List<_PickedShot> shots;
  final int max;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onAddGallery;
  final VoidCallback? onAddCamera;
  final ValueChanged<int> onRemove;
  final String addPhotoLabel;
  final String takePhotoLabel;
  final String removeLabel;

  const _ScreenshotSection({
    required this.shots,
    required this.max,
    required this.cardBg,
    required this.borderColor,
    required this.onAddGallery,
    required this.onAddCamera,
    required this.onRemove,
    required this.addPhotoLabel,
    required this.takePhotoLabel,
    required this.removeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          ...List.generate(shots.length, (index) {
            return Container(
              margin: const EdgeInsets.only(right: 12),
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(
                      shots[index].bytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => onRemove(index),
                            child: Tooltip(
                              message: removeLabel,
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.close_rounded, color: Colors.white, size: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (shots.length < max) ...[
            _ModernAddShotTile(
              icon: Icons.add_photo_alternate_rounded,
              label: addPhotoLabel,
              cardBg: cardBg,
              borderColor: borderColor,
              onTap: onAddGallery,
            ),
            if (onAddCamera != null) ...[
              const SizedBox(width: 12),
              _ModernAddShotTile(
                icon: Icons.photo_camera_rounded,
                label: takePhotoLabel,
                cardBg: cardBg,
                borderColor: borderColor,
                onTap: onAddCamera!,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ModernAddShotTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _ModernAddShotTile({
    required this.icon,
    required this.label,
    required this.cardBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              style: BorderStyle.solid,
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernDeviceInfoCard extends StatelessWidget {
  final DeviceReportMeta? meta;
  final AppLocalizations l10n;
  final Color cardBg;
  final Color borderColor;

  const _ModernDeviceInfoCard({
    required this.meta,
    required this.l10n,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final version = meta == null
        ? '…'
        : (meta!.buildNumber.isEmpty
            ? meta!.appVersion
            : 'v${meta!.appVersion} (${meta!.buildNumber})');

    final device = meta == null
        ? '…'
        : [meta!.deviceModel, meta!.osVersion]
            .where((part) => part.trim().isNotEmpty)
            .join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A263D) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phonelink_setup_rounded,
              color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
              size: 20,
            ),
          ),
          title: Text(
            l10n.reportDeviceInfo,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0B192C),
            ),
          ),
          subtitle: Text(
            l10n.reportPrivacyNote,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          children: [
            const Divider(height: 16),
            _diagRow(l10n.adminAppVersion, version, Icons.info_outline_rounded, isDark),
            const SizedBox(height: 8),
            _diagRow(l10n.adminDeviceInfo, device, Icons.devices_rounded, isDark),
            const SizedBox(height: 8),
            _diagRow('Platform', meta?.platform ?? '…', Icons.laptop_mac_rounded, isDark),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String title, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernSubmitBar extends StatelessWidget {
  final bool isLoading;
  final bool isOffline;
  final String? status;
  final String label;
  final String sendingLabel;
  final String offlineLabel;
  final VoidCallback onSubmit;

  const _ModernSubmitBar({
    required this.isLoading,
    required this.isOffline,
    required this.status,
    required this.label,
    required this.sendingLabel,
    required this.offlineLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 14 + bottomInset),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF080E1A).withValues(alpha: 0.82)
                : Colors.white.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1F2E45) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    status!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isLoading || isOffline ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFFDFB76C) : const Color(0xFF0A1E3F),
                    foregroundColor:
                        isDark ? const Color(0xFF080E1A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: isDark ? const Color(0xFF080E1A) : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                sendingLabel,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOffline ? Icons.wifi_off_rounded : Icons.send_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isOffline ? offlineLabel : label,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}