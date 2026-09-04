import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';

import 'package:mahlete_semay_project/widgets/web_content_wrapper.dart';

class GenderSelectionScreen extends StatelessWidget {
  const GenderSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: WebContentWrapper(
          maxWidth: 600,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.welcome,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.genderSelectionDesc,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGenderCard(context, l10n.male, 'Male', Icons.male),
                    const SizedBox(width: 24),
                    _buildGenderCard(context, l10n.female, 'Female', Icons.female),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard(BuildContext context, String displayLabel, String genderValue, IconData icon) {
    final progressProvider = Provider.of<VocalProgressProvider>(context, listen: false);
    return GestureDetector(
      onTap: () => progressProvider.setGender(genderValue),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: SizedBox(
          width: 120,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(displayLabel, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}