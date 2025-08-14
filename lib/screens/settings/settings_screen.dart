import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeColor: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.admin_panel_settings, color: theme.colorScheme.secondary),
              title: const Text('Admin Panel'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
              },
            ),
          ),
          const SizedBox(height: 20),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.info_outline),
              title: Text('About This App'),
              subtitle: Text('Version 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}