import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../l10n/app_localizations.dart';
import '../models/bug_report_model.dart';
import '../providers/auth_proveider.dart';
import '../services/firebase_service.dart';
import '../services/supabase_storage_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/web_content_wrapper.dart';
import 'widgets/admin_ui_kit.dart';

class ReviewBugReportsScreen extends StatefulWidget {
  const ReviewBugReportsScreen({super.key});

  @override
  State<ReviewBugReportsScreen> createState() => _ReviewBugReportsScreenState();
}

class _ReviewBugReportsScreenState extends State<ReviewBugReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _firebaseService.markAllBugReportsAsSeen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          l10n.adminBugReportsTitle,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AdminConstrainedBar(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13233D) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: l10n.adminOpenTab),
                  Tab(text: l10n.adminInProgressTab),
                  Tab(text: l10n.adminResolvedTab),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<BugReport>>(
        stream: _firebaseService.getBugReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminUiKit.goldAccent));
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.reportFailed,
              description: snapshot.error.toString(),
            );
          }
          final all = snapshot.data ?? const <BugReport>[];
          if (all.isEmpty) {
            return AdminEmptyState(
              icon: Icons.bug_report_outlined,
              title: l10n.adminNoBugReports,
              description: l10n.adminNoBugReportsDesc,
            );
          }

          final open = all.where((r) => r.status == BugReportStatus.open).toList();
          final inProgress = all.where((r) => r.status == BugReportStatus.inProgress).toList();
          final resolved = all.where((r) => r.status == BugReportStatus.resolved).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _ReportList(
                reports: open,
                emptyLabel: l10n.adminNoOpenReports,
                firebaseService: _firebaseService,
              ),
              _ReportList(
                reports: inProgress,
                emptyLabel: l10n.adminNoInProgressReports,
                firebaseService: _firebaseService,
              ),
              _ReportList(
                reports: resolved,
                emptyLabel: l10n.adminNoResolvedReports,
                firebaseService: _firebaseService,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  final List<BugReport> reports;
  final String emptyLabel;
  final FirebaseService firebaseService;

  const _ReportList({
    required this.reports,
    required this.emptyLabel,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return AdminEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: AppLocalizations.of(context)?.allClear ?? 'All Clear',
        description: emptyLabel,
      );
    }

    return WebContentWrapper(
      maxWidth: 850,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        physics: const BouncingScrollPhysics(),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          return _ReportCard(report: reports[index], firebaseService: firebaseService);
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final BugReport report;
  final FirebaseService firebaseService;

  const _ReportCard({required this.report, required this.firebaseService});

  Color get _typeColor {
    switch (report.type) {
      case BugReportType.crash:
        return AdminUiKit.amberOrange;
      case BugReportType.feedback:
        return AdminUiKit.royalBlue;
      case BugReportType.bug:
        return AdminUiKit.roseRed;
    }
  }

  IconData get _typeIcon {
    switch (report.type) {
      case BugReportType.crash:
        return Icons.warning_amber_rounded;
      case BugReportType.feedback:
        return Icons.chat_bubble_rounded;
      case BugReportType.bug:
        return Icons.bug_report_rounded;
    }
  }

  Color get _statusColor {
    switch (report.status) {
      case BugReportStatus.open:
        return AdminUiKit.amberOrange;
      case BugReportStatus.inProgress:
        return AdminUiKit.royalBlue;
      case BugReportStatus.resolved:
        return AdminUiKit.emeraldGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeLabel = switch (report.type) {
      BugReportType.bug => l10n.reportTypeBug,
      BugReportType.crash => l10n.reportTypeCrash,
      BugReportType.feedback => l10n.reportTypeFeedback,
    };
    final statusLabel = switch (report.status) {
      BugReportStatus.open => l10n.adminOpenTab,
      BugReportStatus.inProgress => l10n.adminInProgressTab,
      BugReportStatus.resolved => l10n.adminResolvedTab,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 18,
        isGlowing: !report.isSeen,
        glowColor: AdminUiKit.roseRed,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 20),
                ),
                if (!report.isSeen)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AdminUiKit.roseRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              report.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AdminStatusBadge(label: typeLabel, color: _typeColor, fontSize: 9.5),
                  AdminStatusBadge(label: statusLabel, color: _statusColor, fontSize: 9.5),
                  if (!report.isSeen)
                    AdminStatusBadge(label: l10n.adminUnread, color: AdminUiKit.roseRed, fontSize: 9.5),
                  if (report.screenshotUrls.isNotEmpty)
                    AdminStatusBadge(
                      label: '${report.screenshotUrls.length}',
                      color: AdminUiKit.violetPurple,
                      icon: Icons.image_outlined,
                      fontSize: 9.5,
                    ),
                ],
              ),
            ),
            trailing: Text(
              timeago.format(report.createdAt),
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.grey),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              Text(
                report.description,
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.5),
              ),
              if (report.screenshotUrls.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.adminScreenshots,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: report.screenshotUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final url = report.screenshotUrls[index];
                      return GestureDetector(
                        onTap: () => _openGallery(context, index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 92,
                              height: 92,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 92,
                              height: 92,
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _InfoGrid(report: report, l10n: l10n, isDark: isDark),
              if (report.stackTrace != null && report.stackTrace!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.adminStackTrace,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      report.stackTrace!,
                      style: GoogleFonts.robotoMono(fontSize: 11, height: 1.4),
                    ),
                  ),
                ),
              ],
              if (report.adminNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.adminAddNotes,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(report.adminNotes, style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4)),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  IconButton(
                    tooltip: l10n.adminDeleteReport,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AdminUiKit.roseRed,
                    onPressed: () => _confirmDelete(context, l10n),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                    label: Text(l10n.adminAddNotes),
                    onPressed: () => _editNotes(context, l10n),
                  ),
                  if (report.status != BugReportStatus.inProgress)
                    OutlinedButton(
                      onPressed: () => _updateStatus(context, BugReportStatus.inProgress, l10n),
                      child: Text(l10n.adminMarkInProgress),
                    ),
                  if (report.status != BugReportStatus.resolved)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminUiKit.emeraldGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(l10n.adminMarkResolved),
                      onPressed: () => _updateStatus(context, BugReportStatus.resolved, l10n),
                    ),
                  if (report.status != BugReportStatus.open)
                    TextButton(
                      onPressed: () => _updateStatus(context, BugReportStatus.open, l10n),
                      child: Text(l10n.adminReopen),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    BugReportStatus status,
    AppLocalizations l10n,
  ) async {
    try {
      await firebaseService.updateBugReport(id: report.id, status: status, isSeen: true);
      if (!context.mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        firebaseService.logActivity(
          moderatorId: auth.currentUser!.uid,
          moderatorName: auth.currentModerator?.fullName ?? 'Moderator',
          action: 'UPDATE_BUG_REPORT',
          details: 'Set "${report.title}" to ${status.dbValue}',
        );
      }
      CustomSnackbar.show(context, l10n.adminReportUpdated);
    } catch (e) {
      if (context.mounted) CustomSnackbar.show(context, l10n.reportFailed, isError: true);
    }
  }

  Future<void> _editNotes(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController(text: report.adminNotes);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.adminAddNotes, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: l10n.adminNotesHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.adminSaveNotes),
          ),
        ],
      ),
    );
    if (saved == null) return;
    try {
      await firebaseService.updateBugReport(id: report.id, adminNotes: saved, isSeen: true);
      if (context.mounted) CustomSnackbar.show(context, l10n.adminReportUpdated);
    } catch (_) {
      if (context.mounted) CustomSnackbar.show(context, l10n.reportFailed, isError: true);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.adminDeleteReport, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(l10n.adminDeleteReportConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminUiKit.roseRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      for (final url in report.screenshotUrls) {
        await SupabaseStorageService.deleteFile(url, defaultBucket: 'bug-reports');
      }
      if (!context.mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        firebaseService.logActivity(
          moderatorId: auth.currentUser!.uid,
          moderatorName: auth.currentModerator?.fullName ?? 'Moderator',
          action: 'DELETE_BUG_REPORT',
          details: 'Deleted report: "${report.title}"',
        );
      }
      await firebaseService.deleteBugReport(report.id);
      if (context.mounted) CustomSnackbar.show(context, l10n.adminReportDeleted);
    } catch (_) {
      if (context.mounted) CustomSnackbar.show(context, l10n.reportFailed, isError: true);
    }
  }

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ScreenshotGallery(
          urls: report.screenshotUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final BugReport report;
  final AppLocalizations l10n;
  final bool isDark;

  const _InfoGrid({required this.report, required this.l10n, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final submitted = DateFormat('MMM d, yyyy · HH:mm').format(report.createdAt.toLocal());
    final items = <MapEntry<String, String>>[
      MapEntry(l10n.adminAppVersion, report.versionLabel.isEmpty ? '—' : report.versionLabel),
      MapEntry(l10n.adminDeviceInfo, report.deviceLabel.isEmpty ? report.platform : report.deviceLabel),
      if (report.contactEmail != null && report.contactEmail!.isNotEmpty)
        MapEntry(l10n.adminContact, report.contactEmail!),
      MapEntry(l10n.timestamp, submitted),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        item.key,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.grey),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ScreenshotGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ScreenshotGallery({required this.urls, required this.initialIndex});

  @override
  State<_ScreenshotGallery> createState() => _ScreenshotGalleryState();
}

class _ScreenshotGalleryState extends State<_ScreenshotGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}
