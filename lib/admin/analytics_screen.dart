import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/providers/stats_provider.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Content Overview'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                icon: MdiIcons.musicNote,
                label: 'Total Songs',
                value: stats.totalSongs.toString(),
                color: theme.colorScheme.primary,
              ),
              _StatCard(
                icon: MdiIcons.accountMusic,
                label: 'Total Artists',
                value: stats.totalArtists.toString(),
                color: Colors.orange,
              ),
              _StatCard(
                icon: MdiIcons.album,
                label: 'Total Albums',
                value: stats.totalAlbums.toString(),
                color: Colors.green,
              ),
              _StatCard(
                icon: MdiIcons.eye,
                label: 'Total Song Views',
                value: stats.totalSongViews.toString(),
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Top Performers'),
          if (stats.mostViewedSong != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.analytics_outlined)),
                title: Text(stats.mostViewedSong!.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Most Viewed Song (${stats.mostViewedSong!.viewCount} views)'),
              ),
            )
          else
            const Card(
              child: ListTile(
                title: Text('No song data available.'),
              ),
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
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}