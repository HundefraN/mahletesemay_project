import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/usage_stats_model.dart';
import '../../providers/song_provider.dart';
import '../../providers/stats_provider.dart';
import '../../services/usage_analytics_service.dart';
import '../../utils/responsive_sizer.dart';
import '../../widgets/web_content_wrapper.dart';
import 'widgets/admin_ui_kit.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  UsageStats? _usage;
  bool _loadingUsage = true;
  String? _usageError;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    setState(() {
      _loadingUsage = true;
      _usageError = null;
    });
    try {
      final stats = await UsageAnalyticsService.instance.fetchStats();
      if (!mounted) return;
      setState(() {
        _usage = stats;
        _loadingUsage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usageError = e.toString();
        _loadingUsage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatsProvider>(context);
    final songProvider = Provider.of<SongProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final songs = songProvider.allSongs;
    final artists = songProvider.artists;

    final ethiopianCount = artists.where((a) => a.region == 'Ethiopian').length;
    final worldwideCount = artists.where((a) => a.region == 'Worldwide').length;
    final totalArtists = ethiopianCount + worldwideCount;

    final last7DaysData = _getLast7DaysSongData(songs);

    return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: Text(
            'Analytics & Metrics',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 19),
          ),
        ),
        body: WebContentWrapper(
          maxWidth: 1000,
          child: RefreshIndicator(
            color: AdminUiKit.goldAccent,
            onRefresh: _loadUsage,
            child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              AdminSectionHeader(
                title: l10n?.audienceOverview ?? 'Audience',
                icon: Icons.groups_rounded,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
              ),
              Text(
                l10n?.audienceSubtitle ??
                    'Unique devices that installed the app and browsers that visited the website',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 14),
              _buildAudienceSection(context, isDark, l10n),
              const SizedBox(height: 24),

              // Key Metrics Header
              AdminSectionHeader(
                title: l10n?.keyPlatformMetrics ?? 'Key Platform Metrics',
                icon: Icons.dashboard_customize_rounded,
                padding: const EdgeInsets.only(top: 8, bottom: 12),
              ),

              // 2x2 Metric Cards
              GridView.count(
                crossAxisCount:
                    context.isDesktop ? 4 : (context.isTablet ? 3 : 2),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
                children: [
                  _buildStatCard(
                    context,
                    title: AppLocalizations.of(context)?.totalSongs ??
                        'Total Songs',
                    value: stats.totalSongs.toString(),
                    icon: Icons.music_note_rounded,
                    accentColor: AdminUiKit.royalBlue,
                  ),
                  _buildStatCard(
                    context,
                    title: AppLocalizations.of(context)?.totalArtists ??
                        'Total Singers',
                    value: stats.totalArtists.toString(),
                    icon: Icons.person_rounded,
                    accentColor: AdminUiKit.goldAccent,
                  ),
                  _buildStatCard(
                    context,
                    title: AppLocalizations.of(context)?.totalAlbums ??
                        'Total Albums',
                    value: stats.totalAlbums.toString(),
                    icon: Icons.album_rounded,
                    accentColor: AdminUiKit.emeraldGreen,
                  ),
                  _buildStatCard(
                    context,
                    title: AppLocalizations.of(context)?.totalSongViews ??
                        'Total Song Views',
                    value: NumberFormat.compact().format(stats.totalSongViews),
                    icon: Icons.play_circle_fill_rounded,
                    accentColor: AdminUiKit.amberOrange,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 7-day trend chart
              AdminSectionHeader(
                title: AppLocalizations.of(context)?.songsAdded7Days ??
                    'Songs Added (Last 7 Days)',
                icon: Icons.bar_chart_rounded,
                padding: EdgeInsets.only(top: 8, bottom: 12),
              ),
              AdminGlassCard(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 180,
                  child: BarChart(
                    _buildBarChartData(last7DaysData, theme, isDark),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Artist Distribution Pie Chart
              AdminSectionHeader(
                title:
                    AppLocalizations.of(context)?.artistDistributionBreakdown ??
                        'Artist Distribution Breakdown',
                icon: Icons.pie_chart_outline_rounded,
                padding: EdgeInsets.only(top: 8, bottom: 12),
              ),
              AdminGlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      height: 130,
                      width: 130,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections: totalArtists > 0
                              ? [
                                  PieChartSectionData(
                                    value: ethiopianCount.toDouble(),
                                    title:
                                        '${(ethiopianCount / totalArtists * 100).toStringAsFixed(0)}%',
                                    color: AdminUiKit.goldAccent,
                                    radius: 42,
                                    titleStyle: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AdminUiKit.primaryNavy,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: worldwideCount.toDouble(),
                                    title:
                                        '${(worldwideCount / totalArtists * 100).toStringAsFixed(0)}%',
                                    color: AdminUiKit.royalBlue,
                                    radius: 42,
                                    titleStyle: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildIndicator(AdminUiKit.goldAccent,
                              'Ethiopian Artists', ethiopianCount, isDark),
                          const SizedBox(height: 12),
                          _buildIndicator(AdminUiKit.royalBlue,
                              'Worldwide Artists', worldwideCount, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Top Viewed Songs
              AdminSectionHeader(
                title: AppLocalizations.of(context)?.top5ViewedSongs ??
                    'Top 5 Most Viewed Songs',
                icon: Icons.trending_up_rounded,
                padding: EdgeInsets.only(top: 8, bottom: 12),
              ),
              if (songProvider.trendingSongs.isNotEmpty)
                ...songProvider.trendingSongs.take(5).map((song) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AdminGlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        borderRadius: 16,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdminUiKit.amberOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.trending_up_rounded,
                                  color: AdminUiKit.amberOrange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: isDark
                                          ? Colors.white
                                          : AdminUiKit.primaryNavy,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    song.artistName,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            AdminStatusBadge(
                              label:
                                  '${NumberFormat.compact().format(song.viewCount)} ${AppLocalizations.of(context)?.views?.toLowerCase() ?? "views"}',
                              color: AdminUiKit.emeraldGreen,
                              icon: Icons.visibility_rounded,
                            ),
                          ],
                        ),
                      ),
                    ))
              else
                AdminEmptyState(
                  icon: Icons.music_off_rounded,
                  title: AppLocalizations.of(context)?.noSongViewsYet ??
                      'No Song Views Yet',
                  description:
                      'Song view statistics will appear once listeners start playing songs.',
                ),

              const SizedBox(height: 24),

              // Top Artists
              AdminSectionHeader(
                title: AppLocalizations.of(context)?.topRecommendedArtists ??
                    'Top Recommended Singers',
                icon: Icons.star_rounded,
                padding: EdgeInsets.only(top: 8, bottom: 12),
              ),
              ...songProvider
                  .getRecommendedArtists(count: 5)
                  .map((artist) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: AdminGlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          borderRadius: 16,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: artist.imageUrl.isNotEmpty
                                    ? NetworkImage(artist.imageUrl)
                                    : null,
                                child: artist.imageUrl.isEmpty
                                    ? const Icon(Icons.person, size: 18)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artist.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: isDark
                                            ? Colors.white
                                            : AdminUiKit.primaryNavy,
                                      ),
                                    ),
                                    Text(
                                      artist.region,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              AdminStatusBadge(
                                label: artist.region.toUpperCase(),
                                color: artist.region == 'Ethiopian'
                                    ? AdminUiKit.goldAccent
                                    : AdminUiKit.royalBlue,
                                isOutlined: true,
                              ),
                            ],
                          ),
                        ),
                      )),

              const SizedBox(height: 40),
            ],
          ),
        )));
  }

  Widget _buildAudienceSection(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    if (_loadingUsage && _usage == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_usageError != null && _usage == null) {
      return AdminGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.noAudienceDataYet ?? 'No audience data yet',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Run supabase_usage_analytics_migration.sql in the Supabase SQL editor, then pull to refresh.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final usage = _usage ?? UsageStats.empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: context.isDesktop ? 4 : (context.isTablet ? 3 : 2),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.35,
          children: [
            _buildStatCard(
              context,
              title: l10n?.appInstalls ?? 'App Installs',
              value: NumberFormat.compact().format(usage.appInstalls),
              icon: Icons.download_done_rounded,
              accentColor: AdminUiKit.royalBlue,
            ),
            _buildStatCard(
              context,
              title: l10n?.websiteVisitors ?? 'Website Visitors',
              value: NumberFormat.compact().format(usage.websiteVisitors),
              icon: Icons.language_rounded,
              accentColor: AdminUiKit.emeraldGreen,
            ),
            _buildStatCard(
              context,
              title: l10n?.websiteVisits ?? 'Website Visits',
              value: NumberFormat.compact().format(usage.websiteVisits),
              icon: Icons.travel_explore_rounded,
              accentColor: AdminUiKit.violetPurple,
            ),
            _buildStatCard(
              context,
              title: l10n?.visitsToday ?? 'Visits today',
              value: NumberFormat.compact().format(usage.visitorsToday),
              icon: Icons.today_rounded,
              accentColor: AdminUiKit.amberOrange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminSectionHeader(
          title: l10n?.trafficLast7Days ?? 'Traffic (Last 7 Days)',
          icon: Icons.stacked_bar_chart_rounded,
          padding: const EdgeInsets.only(top: 8, bottom: 12),
        ),
        AdminGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: BarChart(
                  _buildTrafficChartData(usage.last7Days, isDark: isDark),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildIndicator(
                    AdminUiKit.royalBlue,
                    l10n?.appInstalls ?? 'App Installs',
                    usage.last7Days.fold(0, (sum, p) => sum + p.appInstalls),
                    isDark,
                  ),
                  const SizedBox(width: 20),
                  _buildIndicator(
                    AdminUiKit.emeraldGreen,
                    l10n?.websiteVisits ?? 'Website Visits',
                    usage.last7Days.fold(0, (sum, p) => sum + p.websiteVisits),
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  BarChartData _buildTrafficChartData(
    List<UsageDailyPoint> points, {
    required bool isDark,
  }) {
    final formatter = DateFormat('EEE');
    final days = points.isNotEmpty
        ? points
        : List.generate(
            7,
            (i) => UsageDailyPoint(
              day: DateTime.now().subtract(Duration(days: 6 - i)),
              appInstalls: 0,
              websiteVisits: 0,
            ),
          );
    final maxVal = days.fold<int>(
      0,
      (max, p) => [
        max,
        p.appInstalls,
        p.websiteVisits,
      ].reduce((a, b) => a > b ? a : b),
    );

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: (maxVal < 4 ? 4 : maxVal + 1).toDouble(),
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              final index = value.toInt();
              if (index < 0 || index >= days.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 4,
                child: Text(
                  formatter.format(days[index].day.toLocal()),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              );
            },
            reservedSize: 24,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: [
        for (var i = 0; i < days.length; i++)
          BarChartGroupData(
            x: i,
            barsSpace: 3,
            barRods: [
              BarChartRodData(
                toY: days[i].appInstalls.toDouble(),
                color: AdminUiKit.royalBlue,
                width: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: days[i].websiteVisits.toDouble(),
                color: AdminUiKit.emeraldGreen,
                width: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(Color color, String text, int value, bool isDark) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          '$text: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Text(
          value.toString(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AdminUiKit.primaryNavy,
          ),
        ),
      ],
    );
  }

  Map<int, int> _getLast7DaysSongData(List<dynamic> songs) {
    Map<int, int> data = {for (var i = 0; i < 7; i++) i: 0};
    final now = DateTime.now();
    for (var song in songs) {
      if (song.createdAt != null) {
        final DateTime dt = song.createdAt is DateTime
            ? song.createdAt
            : song.createdAt.toDate();
        final diff = now.difference(dt).inDays;
        if (diff < 7 && diff >= 0) {
          data[6 - diff] = (data[6 - diff] ?? 0) + 1;
        }
      }
    }
    return data;
  }

  BarChartData _buildBarChartData(
      Map<int, int> data, ThemeData theme, bool isDark) {
    final DateFormat formatter = DateFormat('EEE');
    final maxVal = data.values.fold(0, (max, v) => v > max ? v : max);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: (maxVal < 4 ? 4 : maxVal + 1).toDouble(),
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              final day =
                  DateTime.now().subtract(Duration(days: 6 - value.toInt()));
              return SideTitleWidget(
                meta: meta,
                space: 4,
                child: Text(
                  formatter.format(day),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              );
            },
            reservedSize: 24,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: data.entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: entry.value.toDouble(),
              gradient: const LinearGradient(
                colors: [AdminUiKit.goldAccent, AdminUiKit.goldHighlight],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 16,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        );
      }).toList(),
    );
  }
}
