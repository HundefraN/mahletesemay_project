import 'package:flutter/material.dart';
import 'manage_plan_days_screen.dart';

class ManageVocalPlansScreen extends StatelessWidget {
  const ManageVocalPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vocal Plans'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, "Daily Plans"),
          _buildPlanTile(
            context,
            title: 'Male Daily Plan',
            icon: Icons.male,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'male_daily', planTitle: 'Male Daily Plan'))),
          ),
          _buildPlanTile(
            context,
            title: 'Female Daily Plan',
            icon: Icons.female,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'female_daily', planTitle: 'Female Daily Plan'))),
          ),
          const Divider(height: 32),
          _buildSectionHeader(context, "Weekly Plans"),
          _buildPlanTile(
            context,
            title: 'Male Weekly Plan',
            icon: Icons.male,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'male_weekly', planTitle: 'Male Weekly Plan'))),
          ),
          _buildPlanTile(
            context,
            title: 'Female Weekly Plan',
            icon: Icons.female,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'female_weekly', planTitle: 'Female Weekly Plan'))),
          ),
          const Divider(height: 32),
          _buildSectionHeader(context, "Monthly Plans"),
          _buildPlanTile(
            context,
            title: 'Male Monthly Plan',
            icon: Icons.male,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'male_monthly', planTitle: 'Male Monthly Plan'))),
          ),
          _buildPlanTile(
            context,
            title: 'Female Monthly Plan',
            icon: Icons.female,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'female_monthly', planTitle: 'Female Monthly Plan'))),
          ),
          const Divider(height: 32),
          _buildSectionHeader(context, "Quarterly (3-Month) Plans"),
          _buildPlanTile(
            context,
            title: 'Male Quarterly Plan',
            icon: Icons.male,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'male_quarterly', planTitle: 'Male Quarterly Plan'))),
          ),
          _buildPlanTile(
            context,
            title: 'Female Quarterly Plan',
            icon: Icons.female,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlanDaysScreen(planId: 'female_quarterly', planTitle: 'Female Quarterly Plan'))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlanTile(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}