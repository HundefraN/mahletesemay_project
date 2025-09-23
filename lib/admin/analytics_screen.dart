import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/providers/song_provider.dart';
import 'package:mahlete_semay_project/providers/stats_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatsProvider>(context);
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final theme = Theme.of(context);

    final songs = songProvider.allSongs;
    final artists = songProvider.artists;

    final ethiopianCount = artists.where((a) => a.region == 'Ethiopian').length;
    final worldwideCount = artists.where((a) => a.region == 'Worldwide').length;
    final totalArtists = ethiopianCount + worldwideCount;

    final last7DaysData = _getLast7DaysSongData(songs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Analytics Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Key Metrics'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _StatCard(icon: Icons.music_note, label: 'Total Songs', value: stats.totalSongs.toString(), color: theme.colorScheme.primary),
              _StatCard(icon: Icons.person, label: 'Total Artists', value: stats.totalArtists.toString(), color: Colors.orange),
              _StatCard(icon: Icons.album, label: 'Total Albums', value: stats.totalAlbums.toString(), color: Colors.green),
              _StatCard(icon: Icons.play_circle_fill, label: 'Total Song Views', value: NumberFormat.compact().format(stats.totalSongViews), color: Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Songs Added (Last 7 Days)'),
          SizedBox(
            height: 200,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BarChart(
                  _buildBarChartData(last7DaysData, theme),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Content Breakdown'),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                children: [
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: PieChart(
                      PieChartData(
                        sections: totalArtists > 0 ? [
                          PieChartSectionData(value: ethiopianCount.toDouble(), title: '${(ethiopianCount / totalArtists * 100).toStringAsFixed(0)}%', color: theme.colorScheme.primary, radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          PieChartSectionData(value: worldwideCount.toDouble(), title: '${(worldwideCount / totalArtists * 100).toStringAsFixed(0)}%', color: theme.colorScheme.secondary, radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        ] : [],
                        centerSpaceRadius: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Indicator(color: theme.colorScheme.primary, text: 'Ethiopian Artists', value: ethiopianCount),
                        const SizedBox(height: 8),
                        _Indicator(color: theme.colorScheme.secondary, text: 'Worldwide Artists', value: worldwideCount),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Top 5 Most Viewed Songs'),
          if (stats.mostViewedSong != null)
            ...songProvider.trendingSongs.take(5).map((song) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.trending_up)),
                title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis,),
                subtitle: Text(song.artistName),
                trailing: Text('${NumberFormat.compact().format(song.viewCount)} views'),
              ),
            ))
          else
            const Card(child: ListTile(title: Text('No song data available.'))),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Top 5 Most Active Artists'),
          ...songProvider.getRecommendedArtists(count: 5).map((artist) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(backgroundImage: artist.imageUrl.isNotEmpty ? NetworkImage(artist.imageUrl) : null, child: artist.imageUrl.isEmpty ? const Icon(Icons.person) : null),
              title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(artist.region),
            ),
          )),
        ],
      ),
    );
  }

  Map<int, int> _getLast7DaysSongData(List<dynamic> songs) {
    Map<int, int> data = { for (var i = 0; i < 7; i++) i: 0 };
    final now = DateTime.now();
    for (var song in songs) {
      final diff = now.difference(song.createdAt.toDate()).inDays;
      if (diff < 7) {
        data[6 - diff] = (data[6 - diff] ?? 0) + 1;
      }
    }
    return data;
  }

  BarChartData _buildBarChartData(Map<int, int> data, ThemeData theme) {
    final DateFormat formatter = DateFormat('EEE');
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              final day = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
              return SideTitleWidget(
                meta: meta,
                space: 4,
                child: Text(formatter.format(day), style: theme.textTheme.bodySmall),
              );
            },
            reservedSize: 28,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: data.entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(toY: entry.value.toDouble(), color: theme.colorScheme.primary, width: 16, borderRadius: BorderRadius.circular(4)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final int value;

  const _Indicator({required this.color, required this.text, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text('$text ($value)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
      ],
    );
  }
}