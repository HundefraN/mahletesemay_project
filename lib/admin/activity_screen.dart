import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/activity_log_model.dart';
import '../../services/firebase_service.dart';
import '../../services/search_service.dart';
import '../../widgets/loading_placeholders.dart';
import '../../widgets/text_highlighter.dart';
import 'widgets/admin_ui_kit.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterByAction = 'All';
  String? _filterByModerator;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim()));
    _firebaseService.markAllActivitiesAsSeen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getIconForAction(String action) {
    if (action.startsWith('CREATE')) return Icons.add_circle_outline_rounded;
    if (action.startsWith('UPDATE')) return Icons.edit_note_rounded;
    if (action.startsWith('DELETE')) return Icons.delete_outline_rounded;
    if (action.startsWith('APPROVE')) return Icons.check_circle_outline_rounded;
    if (action.startsWith('REJECT')) return Icons.cancel_outlined;
    return Icons.history_rounded;
  }

  Color _getColorForAction(String action) {
    if (action.startsWith('CREATE')) return AdminUiKit.emeraldGreen;
    if (action.startsWith('UPDATE')) return AdminUiKit.royalBlue;
    if (action.startsWith('DELETE')) return AdminUiKit.roseRed;
    if (action.startsWith('APPROVE')) return AdminUiKit.emeraldGreen;
    if (action.startsWith('REJECT')) return AdminUiKit.amberOrange;
    return AdminUiKit.goldAccent;
  }

  void _showFilterSheet(List<ActivityLog> allLogs) {
    final uniqueActions = allLogs.map((log) => log.action.split('_').first).toSet().toList();
    final uniqueModerators = allLogs.map((log) => log.moderatorName).toSet().toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13233D) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Filter Activities',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Text(
                  'Action Type',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', ...uniqueActions].map((action) {
                    final isSelected = _filterByAction == action;
                    return InkWell(
                      onTap: () => setModalState(() => _filterByAction = action),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy)
                              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          action,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isDark ? AdminUiKit.primaryNavy : Colors.white)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Moderator',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _filterByModerator,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Moderators')),
                    ...uniqueModerators.map((name) => DropdownMenuItem(value: name, child: Text(name))),
                  ],
                  onChanged: (value) => setModalState(() => _filterByModerator = value),
                ),
                const SizedBox(height: 24),
                AdminPrimaryButton(
                  label: 'Apply Filters',
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );
  }

  void _showLogDetails(ActivityLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13233D) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Activity Event Details',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Divider(height: 24),
              _buildDetailRow(Icons.person_rounded, 'Moderator', log.moderatorName),
              _buildDetailRow(_getIconForAction(log.action), 'Action', log.action.replaceAll('_', ' ')),
              _buildDetailRow(Icons.description_rounded, 'Details', log.details),
              _buildDetailRow(
                Icons.schedule_rounded,
                'Timestamp',
                DateFormat('MMM d, yyyy • hh:mm a').format(log.timestamp.toDate()),
              ),
              const SizedBox(height: 24),
              AdminPrimaryButton(
                label: 'Close',
                isSecondary: true,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AdminUiKit.goldAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Moderator Activity Log',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: StreamBuilder<List<ActivityLog>>(
        stream: _firebaseService.getActivityLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 8, itemBuilder: (_, __) => const ListTileShimmer());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'No Activity Logged',
              description: 'No admin or moderator activities have been recorded yet.',
            );
          }
          final allLogs = snapshot.data!;

          final filteredLogs = allLogs.where((log) {
            final searchMatch = SearchService().matches(
              query: _searchQuery,
              text: log.details,
              secondaryText: log.moderatorName,
            );
            final actionMatch = _filterByAction == 'All' || log.action.startsWith(_filterByAction);
            final moderatorMatch = _filterByModerator == null || log.moderatorName == _filterByModerator;
            return searchMatch && actionMatch && moderatorMatch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AdminSearchBar(
                  controller: _searchController,
                  hintText: 'Search actions or names...',
                  trailing: IconButton(
                    icon: const Icon(Icons.filter_list_rounded, size: 20),
                    tooltip: 'Filter Logs',
                    onPressed: () => _showFilterSheet(allLogs),
                  ),
                ),
              ),
              Expanded(
                child: filteredLogs.isEmpty
                    ? const AdminEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Matching Logs',
                        description: 'No activity matches your active search and filter filters.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final actionColor = _getColorForAction(log.action);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: AdminGlassCard(
                              onTap: () => _showLogDetails(log),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              borderRadius: 16,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: actionColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getIconForAction(log.action),
                                      color: actionColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextHighlighter(
                                          text: log.details,
                                          query: _searchQuery,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${log.moderatorName} • ${timeago.format(log.timestamp.toDate())}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white30 : Colors.black26,
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
        },
      ),
    );
  }
}