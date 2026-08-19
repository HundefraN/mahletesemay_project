import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/widgets/admin_ui_kit.dart';
import 'manage_plan_days_screen.dart';

class ManageVocalPlansScreen extends StatelessWidget {
  const ManageVocalPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Manage Vocal Plans',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        physics: const BouncingScrollPhysics(),
        children: [
          // Daily Plans
          const AdminSectionHeader(
            title: 'Daily Training Plans',
            icon: Icons.wb_sunny_rounded,
            padding: EdgeInsets.only(top: 8, bottom: 10),
          ),
          _buildPlanCard(
            context,
            title: 'Male Daily Vocal Plan',
            subtitle: 'Daily routine drills for male vocal ranges',
            planId: 'male_daily',
            icon: Icons.male_rounded,
            accentColor: AdminUiKit.royalBlue,
          ),
          _buildPlanCard(
            context,
            title: 'Female Daily Vocal Plan',
            subtitle: 'Daily routine drills for female vocal ranges',
            planId: 'female_daily',
            icon: Icons.female_rounded,
            accentColor: AdminUiKit.violetPurple,
          ),

          const SizedBox(height: 16),

          // Weekly Plans
          const AdminSectionHeader(
            title: 'Weekly 7-Day Curriculums',
            icon: Icons.calendar_view_week_rounded,
            padding: EdgeInsets.only(top: 8, bottom: 10),
          ),
          _buildPlanCard(
            context,
            title: 'Male Weekly Plan',
            subtitle: 'Structured 7-day progressive workout',
            planId: 'male_weekly',
            icon: Icons.male_rounded,
            accentColor: AdminUiKit.royalBlue,
          ),
          _buildPlanCard(
            context,
            title: 'Female Weekly Plan',
            subtitle: 'Structured 7-day progressive workout',
            planId: 'female_weekly',
            icon: Icons.female_rounded,
            accentColor: AdminUiKit.violetPurple,
          ),

          const SizedBox(height: 16),

          // Monthly Plans
          const AdminSectionHeader(
            title: 'Monthly 30-Day Intensives',
            icon: Icons.calendar_month_rounded,
            padding: EdgeInsets.only(top: 8, bottom: 10),
          ),
          _buildPlanCard(
            context,
            title: 'Male Monthly Plan',
            subtitle: '30-day stamina and range expansion',
            planId: 'male_monthly',
            icon: Icons.male_rounded,
            accentColor: AdminUiKit.royalBlue,
          ),
          _buildPlanCard(
            context,
            title: 'Female Monthly Plan',
            subtitle: '30-day stamina and range expansion',
            planId: 'female_monthly',
            icon: Icons.female_rounded,
            accentColor: AdminUiKit.violetPurple,
          ),

          const SizedBox(height: 16),

          // Quarterly Plans
          const AdminSectionHeader(
            title: 'Quarterly (90-Day) Masteries',
            icon: Icons.military_tech_rounded,
            padding: EdgeInsets.only(top: 8, bottom: 10),
          ),
          _buildPlanCard(
            context,
            title: 'Male Quarterly Plan',
            subtitle: 'Comprehensive 3-month vocal mastery',
            planId: 'male_quarterly',
            icon: Icons.male_rounded,
            accentColor: AdminUiKit.royalBlue,
          ),
          _buildPlanCard(
            context,
            title: 'Female Quarterly Plan',
            subtitle: 'Comprehensive 3-month vocal mastery',
            planId: 'female_quarterly',
            icon: Icons.female_rounded,
            accentColor: AdminUiKit.violetPurple,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String planId,
    required IconData icon,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: AdminGlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManagePlanDaysScreen(planId: planId, planTitle: title),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 18,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withOpacity(0.25)),
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
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}