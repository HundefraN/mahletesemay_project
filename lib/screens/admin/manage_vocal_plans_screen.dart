import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../../models/vocal_plan_catalog.dart';
import '../../services/firebase_service.dart';
import 'manage_plan_days_screen.dart';

class ManageVocalPlansScreen extends StatefulWidget {
  const ManageVocalPlansScreen({super.key});

  @override
  State<ManageVocalPlansScreen> createState() => _ManageVocalPlansScreenState();
}

class _ManageVocalPlansScreenState extends State<ManageVocalPlansScreen> {
  final _firebaseService = FirebaseService();
  Map<String, VocalPlanDayStats> _stats = {
    for (final id in VocalPlanCatalog.planIds) id: VocalPlanDayStats.empty(id),
  };
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _firebaseService.getVocalPlanDayStats();
      if (!mounted) return;
      setState(() {
        _stats = {
          for (final id in VocalPlanCatalog.planIds)
            id: stats[id] ?? VocalPlanDayStats.empty(id),
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openPlan({
    required String planId,
    required String title,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagePlanDaysScreen(planId: planId, planTitle: title),
      ),
    );
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          l10n?.manageVocalPlans ?? 'Manage Vocal Plans',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: l10n?.retry ?? 'Refresh',
            onPressed: _loading ? null : _loadStats,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AdminPageBody(
        child: _error != null && !_loading
            ? AdminEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n?.failedToLoadVocalPlans ?? 'Failed to load vocal plan progress',
                description: _error!,
                actionLabel: l10n?.retry ?? 'Retry',
                actionIcon: Icons.refresh_rounded,
                onAction: _loadStats,
              )
            : RefreshIndicator(
                color: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                onRefresh: _loadStats,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _OverviewCard(stats: _stats.values.toList(), loading: _loading),
                    const SizedBox(height: 8),
                    AdminSectionHeader(
                      title: l10n?.dailyTrainingPlans ?? 'Daily Training Plans',
                      icon: Icons.wb_sunny_rounded,
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                    ),
                    AdminResponsiveWrap(
                      children: [
                        _PlanCard(
                          title: l10n?.maleDailyPlan ?? 'Male Daily Vocal Plan',
                          subtitle: l10n?.maleDailyPlanSubtitle ??
                              'Daily routine drills for male vocal ranges',
                          icon: Icons.male_rounded,
                          accentColor: AdminUiKit.royalBlue,
                          stats: _stats['male_daily']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'male_daily',
                            title: l10n?.maleDailyPlan ?? 'Male Daily Vocal Plan',
                          ),
                        ),
                        _PlanCard(
                          title: l10n?.femaleDailyPlan ?? 'Female Daily Vocal Plan',
                          subtitle: l10n?.femaleDailyPlanSubtitle ??
                              'Daily routine drills for female vocal ranges',
                          icon: Icons.female_rounded,
                          accentColor: AdminUiKit.violetPurple,
                          stats: _stats['female_daily']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'female_daily',
                            title: l10n?.femaleDailyPlan ?? 'Female Daily Vocal Plan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AdminSectionHeader(
                      title: l10n?.weeklyCurriculums ?? 'Weekly 7-Day Curriculums',
                      icon: Icons.calendar_view_week_rounded,
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                    ),
                    AdminResponsiveWrap(
                      children: [
                        _PlanCard(
                          title: l10n?.maleWeeklyPlan ?? 'Male Weekly Plan',
                          subtitle: l10n?.weeklyPlanSubtitle ??
                              'Structured 7-day progressive workout',
                          icon: Icons.male_rounded,
                          accentColor: AdminUiKit.royalBlue,
                          stats: _stats['male_weekly']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'male_weekly',
                            title: l10n?.maleWeeklyPlan ?? 'Male Weekly Plan',
                          ),
                        ),
                        _PlanCard(
                          title: l10n?.femaleWeeklyPlan ?? 'Female Weekly Plan',
                          subtitle: l10n?.weeklyPlanSubtitle ??
                              'Structured 7-day progressive workout',
                          icon: Icons.female_rounded,
                          accentColor: AdminUiKit.violetPurple,
                          stats: _stats['female_weekly']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'female_weekly',
                            title: l10n?.femaleWeeklyPlan ?? 'Female Weekly Plan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AdminSectionHeader(
                      title: l10n?.monthlyIntensives ?? 'Monthly 30-Day Intensives',
                      icon: Icons.calendar_month_rounded,
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                    ),
                    AdminResponsiveWrap(
                      children: [
                        _PlanCard(
                          title: l10n?.maleMonthlyPlan ?? 'Male Monthly Plan',
                          subtitle: l10n?.monthlyPlanSubtitle ??
                              '30-day stamina and range expansion',
                          icon: Icons.male_rounded,
                          accentColor: AdminUiKit.royalBlue,
                          stats: _stats['male_monthly']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'male_monthly',
                            title: l10n?.maleMonthlyPlan ?? 'Male Monthly Plan',
                          ),
                        ),
                        _PlanCard(
                          title: l10n?.femaleMonthlyPlan ?? 'Female Monthly Plan',
                          subtitle: l10n?.monthlyPlanSubtitle ??
                              '30-day stamina and range expansion',
                          icon: Icons.female_rounded,
                          accentColor: AdminUiKit.violetPurple,
                          stats: _stats['female_monthly']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'female_monthly',
                            title: l10n?.femaleMonthlyPlan ?? 'Female Monthly Plan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AdminSectionHeader(
                      title: l10n?.quarterlyMasteries ?? 'Quarterly (90-Day) Masteries',
                      icon: Icons.military_tech_rounded,
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                    ),
                    AdminResponsiveWrap(
                      children: [
                        _PlanCard(
                          title: l10n?.maleQuarterlyPlan ?? 'Male Quarterly Plan',
                          subtitle: l10n?.quarterlyPlanSubtitle ??
                              'Comprehensive 3-month vocal mastery',
                          icon: Icons.male_rounded,
                          accentColor: AdminUiKit.royalBlue,
                          stats: _stats['male_quarterly']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'male_quarterly',
                            title: l10n?.maleQuarterlyPlan ?? 'Male Quarterly Plan',
                          ),
                        ),
                        _PlanCard(
                          title: l10n?.femaleQuarterlyPlan ?? 'Female Quarterly Plan',
                          subtitle: l10n?.quarterlyPlanSubtitle ??
                              'Comprehensive 3-month vocal mastery',
                          icon: Icons.female_rounded,
                          accentColor: AdminUiKit.violetPurple,
                          stats: _stats['female_quarterly']!,
                          loading: _loading,
                          onTap: () => _openPlan(
                            planId: 'female_quarterly',
                            title: l10n?.femaleQuarterlyPlan ?? 'Female Quarterly Plan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats, required this.loading});

  final List<VocalPlanDayStats> stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final published = stats.fold<int>(0, (sum, s) => sum + s.uniqueDayCount);
    final expected = stats.fold<int>(0, (sum, s) => sum + s.expectedDays);
    final complete = stats.where((s) => s.isComplete).length;
    final progress = expected == 0 ? 0.0 : (published / expected).clamp(0.0, 1.0);

    return AdminGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.vocalPlansOverview ?? 'Curriculum coverage',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n?.vocalPlansPublishedCount(published, expected) ??
                '$published of $expected days published',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AdminUiKit.primaryNavy,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: loading ? null : progress,
              minHeight: 7,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              color: complete == stats.length
                  ? AdminUiKit.emeraldGreen
                  : AdminUiKit.goldAccent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.vocalPlansCompleteCount(complete, stats.length) ??
                '$complete of ${stats.length} plans complete',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.stats,
    required this.loading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VocalPlanDayStats stats;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final expected = stats.expectedDays;
    final current = stats.uniqueDayCount;
    final progress = expected == 0 ? 0.0 : (current / expected).clamp(0.0, 1.0);

    final Color badgeColor;
    final String badgeLabel;
    if (stats.isEmpty) {
      badgeColor = AdminUiKit.roseRed;
      badgeLabel = l10n?.planStatusEmpty ?? 'Empty';
    } else if (stats.isComplete) {
      badgeColor = AdminUiKit.emeraldGreen;
      badgeLabel = l10n?.planStatusComplete ?? 'Complete';
    } else {
      badgeColor = AdminUiKit.amberOrange;
      badgeLabel = l10n?.planStatusInProgress ?? 'In progress';
    }

    final countLabel = expected <= 1
        ? (l10n?.planDaysCount(current) ?? '$current days')
        : (l10n?.planDaysProgress(current, expected) ?? '$current of $expected days');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: AdminGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: loading ? null : progress,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                color: badgeColor,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AdminStatusBadge(
                  label: badgeLabel,
                  color: badgeColor,
                  icon: stats.isComplete
                      ? Icons.check_circle_rounded
                      : (stats.isEmpty
                          ? Icons.hourglass_empty_rounded
                          : Icons.timelapse_rounded),
                  fontSize: 9.5,
                ),
                Text(
                  countLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (stats.restDayCount > 0)
                  Text(
                    l10n?.restDaysCount(stats.restDayCount) ??
                        '${stats.restDayCount} rest',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AdminUiKit.amberOrange,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
