import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';

class GenderSelectionScreen extends StatelessWidget {
  const GenderSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome!',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'To personalize your vocal exercises, please select your vocal profile.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGenderCard(context, 'Male', Icons.male),
                  const SizedBox(width: 24),
                  _buildGenderCard(context, 'Female', Icons.female),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard(BuildContext context, String gender, IconData icon) {
    final progressProvider = Provider.of<VocalProgressProvider>(context, listen: false);
    return GestureDetector(
      onTap: () => progressProvider.setGender(gender),
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
              Text(gender, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}