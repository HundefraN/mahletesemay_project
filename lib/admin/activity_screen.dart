import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Activity'),
        actions: [
          TextButton.icon(
            onPressed: () => _firebaseService.markAllActivitiesAsSeen(),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all as seen'),
          ),
        ],
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
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: log.isSeen ? Colors.grey.shade300 : Theme.of(context).colorScheme.primary,
                        child: Icon(
                          _getIconForAction(log.action),
                          color: log.isSeen ? Colors.grey.shade600 : Colors.white,
                          size: 20,
                        ),
                      ),
                      title: TextHighlighter(
                        text: log.details,
                        query: _searchQuery,
                        style: TextStyle(fontWeight: log.isSeen ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: TextHighlighter(
                        text: '${log.moderatorName} • ${timeago.format(log.timestamp.toDate())}',
                        query: _searchQuery,
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