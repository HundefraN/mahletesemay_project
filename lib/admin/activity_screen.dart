import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/activity_log_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/loading_placeholders.dart';
import 'package:mahlete_semay_project/widgets/text_highlighter.dart';
import 'package:timeago/timeago.dart' as timeago;

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
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
    _firebaseService.markAllActivitiesAsSeen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getIconForAction(String action) {
    if (action.startsWith('CREATE')) return Icons.add_circle_outline;
    if (action.startsWith('UPDATE')) return Icons.edit_outlined;
    if (action.startsWith('DELETE')) return Icons.delete_outline;
    if (action.startsWith('APPROVE')) return Icons.check_circle_outline;
    if (action.startsWith('REJECT')) return Icons.cancel_outlined;
    return Icons.history;
  }

  Color _getColorForAction(BuildContext context, String action) {
    final theme = Theme.of(context);
    if (action.startsWith('CREATE')) return Colors.green;
    if (action.startsWith('UPDATE')) return theme.colorScheme.primary;
    if (action.startsWith('DELETE')) return theme.colorScheme.error;
    if (action.startsWith('APPROVE')) return Colors.blue;
    if (action.startsWith('REJECT')) return Colors.orange;
    return Colors.grey;
  }

  void _showFilterSheet(List<ActivityLog> allLogs) {
    final uniqueActions = allLogs.map((log) => log.action.split('_').first).toSet().toList();
    final uniqueModerators = allLogs.map((log) => log.moderatorName).toSet().toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter Activities', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                Text('Action Type', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: ['All', ...uniqueActions].map((action) => ChoiceChip(
                    label: Text(action),
                    selected: _filterByAction == action,
                    onSelected: (selected) => setModalState(() => _filterByAction = action),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                Text('Moderator', style: Theme.of(context).textTheme.titleMedium),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: _filterByModerator,
                  hint: const Text('All Moderators'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Moderators')),
                    ...uniqueModerators.map((name) => DropdownMenuItem(value: name, child: Text(name))),
                  ],
                  onChanged: (value) => setModalState(() => _filterByModerator = value),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(child: const Text('Apply Filters'), onPressed: () { setState(() {}); Navigator.pop(context); })),
              ],
            ),
          );
        });
      },
    );
  }

  void _showLogDetails(ActivityLog log) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Activity Details", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                _buildDetailRow(context, Icons.person_outline, "Moderator", log.moderatorName),
                _buildDetailRow(context, _getIconForAction(log.action), "Action", log.action.replaceAll('_', ' ')),
                _buildDetailRow(context, Icons.info_outline, "Details", log.details),
                _buildDetailRow(context, Icons.access_time, "Timestamp", DateFormat('MMM d, yyyy - hh:mm a').format(log.timestamp.toDate())),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))),
              ],
            ),
          );
        }
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Activity'),
      ),
      body: StreamBuilder<List<ActivityLog>>(
        stream: _firebaseService.getActivityLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 10, itemBuilder: (_, __) => const ListTileShimmer());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No activity has been logged yet.'));
          }
          final allLogs = snapshot.data!;

          final filteredLogs = allLogs.where((log) {
            final query = _searchQuery.toLowerCase();
            final searchMatch = query.isEmpty ||
                log.details.toLowerCase().contains(query) ||
                log.moderatorName.toLowerCase().contains(query);
            final actionMatch = _filterByAction == 'All' || log.action.startsWith(_filterByAction);
            final moderatorMatch = _filterByModerator == null || log.moderatorName == _filterByModerator;
            return searchMatch && actionMatch && moderatorMatch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search details or names...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.filter_list_rounded),
                      onPressed: () => _showFilterSheet(allLogs),
                    )
                  ],
                ),
              ),
              Expanded(
                child: filteredLogs.isEmpty
                    ? const Center(child: Text('No activities match your criteria.'))
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return ListTile(
                      onTap: () => _showLogDetails(log),
                      leading: CircleAvatar(
                        backgroundColor: _getColorForAction(context, log.action).withOpacity(0.1),
                        child: Icon(
                          _getIconForAction(log.action),
                          color: _getColorForAction(context, log.action),
                          size: 20,
                        ),
                      ),
                      title: TextHighlighter(
                        text: log.details,
                        query: _searchQuery,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'By: ${log.moderatorName} • ${timeago.format(log.timestamp.toDate())}',
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