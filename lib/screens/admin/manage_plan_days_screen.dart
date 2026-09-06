import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../../models/vocal_plan_catalog.dart';
import '../../models/vocal_plan_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/loading_placeholders.dart';
import 'add_edit_vocal_day_screen.dart';

class ManagePlanDaysScreen extends StatefulWidget {
  final String planId;
  final String planTitle;

  const ManagePlanDaysScreen({
    super.key,
    required this.planId,
    required this.planTitle,
  });

  @override
  State<ManagePlanDaysScreen> createState() => _ManagePlanDaysScreenState();
}

class _ManagePlanDaysScreenState extends State<ManagePlanDaysScreen> {
  final _firebaseService = FirebaseService();
  final _searchController = TextEditingController();
  final _deletingIds = <String>{};

  StreamSubscription<List<VocalExerciseDay>>? _subscription;
  List<VocalExerciseDay> _days = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    _subscription = _firebaseService.getVocalPlanDaysStream(widget.planId).listen(
      (days) {
        if (!mounted) return;
        setState(() {
          _days = days;
          _loading = false;
          _error = null;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      },
    );
  }

  List<int> _occupiedDayNumbers({String? exceptId}) {
    return _days
        .where((day) => day.id != exceptId)
        .map((day) => day.dayNumber)
        .toList();
  }

  Future<void> _openDayEditor({VocalExerciseDay? existingDay}) async {
    final occupied = _occupiedDayNumbers(exceptId: existingDay?.id);
    final expected = VocalPlanCatalog.expectedDaysFor(widget.planId);
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditVocalDayScreen(
          planId: widget.planId,
          existingDay: existingDay,
          occupiedDayNumbers: occupied,
          suggestedDayNumber: existingDay?.dayNumber ??
              VocalPlanCatalog.nextAvailableDay(
                occupied,
                maxDay: expected > 1 ? expected : null,
              ),
        ),
      ),
    );
  }

  Future<void> _deleteDay(VocalExerciseDay day) async {
    if (_deletingIds.contains(day.id)) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.deletePrompt('Day ${day.dayNumber}') ??
              'Delete Day ${day.dayNumber}?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n?.deleteConfirmPrompt('Day ${day.dayNumber} ("${day.title}")') ??
              'Are you sure you want to delete Day ${day.dayNumber} ("${day.title}")?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(day.id));
    try {
      await _firebaseService.deleteVocalExerciseDay(widget.planId, day.id);
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final moderator = authProvider.currentModerator;
      if (user != null && moderator != null) {
        _firebaseService.logActivity(
          moderatorId: user.uid,
          moderatorName: moderator.fullName,
          action: 'DELETE_EXERCISE_DAY',
          details:
              'Deleted Day ${day.dayNumber} ("${day.title}") from "${widget.planTitle}"',
        );
      }

      if (mounted) {
        CustomSnackbar.show(context, l10n?.dayDeleted ?? 'Day deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          '${l10n?.failedToDeleteDay ?? "Failed to delete day"}: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(day.id));
      }
    }
  }

  List<VocalExerciseDay> _filteredDays() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _days;
    return _days.where((day) {
      return day.title.toLowerCase().contains(query) ||
          day.description.toLowerCase().contains(query) ||
          '${day.dayNumber}'.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          widget.planTitle,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: AdminPageBody(child: _buildBody(isDark, l10n)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDayEditor(),
        backgroundColor: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
        foregroundColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          l10n?.addDay ?? 'Add Day',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, AppLocalizations? l10n) {
    if (_loading && _days.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (context, index) => const ListTileShimmer(),
      );
    }

    if (_error != null && _days.isEmpty) {
      return AdminEmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n?.failedToLoadPlanDays ?? 'Failed to load plan days',
        description: _error!,
        actionLabel: l10n?.retry ?? 'Retry',
        actionIcon: Icons.refresh_rounded,
        onAction: _subscribe,
      );
    }

    if (_days.isEmpty) {
      return AdminEmptyState(
        icon: Icons.fitness_center_rounded,
        title: l10n?.noDaysAddedYet ?? 'No Days Added Yet',
        description: l10n?.startBuildingCurriculum ??
            'Start building this vocal curriculum by adding Day 1.',
        actionLabel: l10n?.addFirstDay ?? 'Add First Day',
        onAction: () => _openDayEditor(),
      );
    }

    final filtered = _filteredDays();
    final expected = VocalPlanCatalog.expectedDaysFor(widget.planId);
    final missing = VocalPlanCatalog.missingDays(
      _days.map((d) => d.dayNumber),
      expected,
    );
    final duplicates = VocalPlanCatalog.duplicateDays(
      _days.map((d) => d.dayNumber),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminSearchBar(
            controller: _searchController,
            hintText: l10n?.searchPlanDaysHint ?? 'Search days by title or number...',
            onChanged: (_) => setState(() {}),
            onClear: () => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _PlanHealthBanner(
            published: _days.length,
            uniqueDays: _days.map((d) => d.dayNumber).toSet().length,
            expected: expected,
            missing: missing,
            duplicates: duplicates,
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? AdminEmptyState(
                  icon: Icons.search_off_rounded,
                  title: l10n?.noMatchingPlanDays ?? 'No days match your search',
                  description: _searchController.text.trim(),
                )
              : AdminResponsiveItemList(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final day = filtered[index];
                    final isDuplicate = duplicates.contains(day.dayNumber);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: AdminGlassCard(
                        onTap: () => _openDayEditor(existingDay: day),
                        padding: const EdgeInsets.all(14),
                        borderRadius: 18,
                        borderColor: isDuplicate
                            ? AdminUiKit.roseRed.withValues(alpha: 0.45)
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : AdminUiKit.royalBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.dayNumber}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: isDark
                                        ? Colors.white
                                        : AdminUiKit.royalBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          day.title,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : AdminUiKit.primaryNavy,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isDuplicate)
                                        AdminStatusBadge(
                                          label: l10n?.duplicateDayBadge ??
                                              'DUPLICATE',
                                          color: AdminUiKit.roseRed,
                                          icon: Icons.copy_all_rounded,
                                          fontSize: 9.5,
                                        )
                                      else if (day.isRestDay)
                                        AdminStatusBadge(
                                          label: l10n?.restDayBadge ?? 'REST DAY',
                                          color: AdminUiKit.amberOrange,
                                          icon: Icons.hotel_rounded,
                                          fontSize: 9.5,
                                        )
                                      else if (day.audioUrl != null &&
                                          day.audioUrl!.isNotEmpty)
                                        AdminStatusBadge(
                                          label: l10n?.audioAttachedBadge ??
                                              'AUDIO ATTACHED',
                                          color: AdminUiKit.emeraldGreen,
                                          icon: Icons.graphic_eq_rounded,
                                          fontSize: 9.5,
                                        )
                                      else
                                        AdminStatusBadge(
                                          label: l10n?.missingAudioBadge ??
                                              'NO AUDIO',
                                          color: AdminUiKit.roseRed,
                                          icon: Icons.music_off_rounded,
                                          fontSize: 9.5,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    day.isRestDay
                                        ? (l10n?.scheduledRest ??
                                            'Scheduled vocal rest & recovery')
                                        : day.description,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (_deletingIds.contains(day.id))
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: AdminUiKit.roseRed,
                                ),
                                tooltip: l10n?.deleteDay ?? 'Delete Day',
                                onPressed: () => _deleteDay(day),
                              ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PlanHealthBanner extends StatelessWidget {
  const _PlanHealthBanner({
    required this.published,
    required this.uniqueDays,
    required this.expected,
    required this.missing,
    required this.duplicates,
  });

  final int published;
  final int uniqueDays;
  final int expected;
  final List<int> missing;
  final List<int> duplicates;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final complete = expected > 0 && uniqueDays >= expected;
    final color = duplicates.isNotEmpty
        ? AdminUiKit.roseRed
        : (complete ? AdminUiKit.emeraldGreen : AdminUiKit.amberOrange);

    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      borderColor: color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expected > 1
                ? (l10n?.planDaysProgress(uniqueDays, expected) ??
                    '$uniqueDays of $expected days')
                : (l10n?.planDaysCount(published) ?? '$published days'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AdminUiKit.primaryNavy,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n?.missingDaysWarning(VocalPlanCatalog.formatDayList(missing)) ??
                  'Missing days: ${VocalPlanCatalog.formatDayList(missing)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
          if (duplicates.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n?.duplicateDaysWarning(
                    VocalPlanCatalog.formatDayList(duplicates),
                  ) ??
                  'Duplicate day numbers: ${VocalPlanCatalog.formatDayList(duplicates)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminUiKit.roseRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
