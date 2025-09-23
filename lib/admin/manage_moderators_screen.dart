// lib/screens/admin/moderators_management_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/models/moderator_model.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

class ModeratorsManagementScreen extends StatefulWidget {
  const ModeratorsManagementScreen({super.key});

  @override
  State<ModeratorsManagementScreen> createState() => _ModeratorsManagementScreenState();
}

class _ModeratorsManagementScreenState extends State<ModeratorsManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late StreamSubscription<List<Moderator>> _moderatorSubscription;
  List<Moderator> _moderators = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscribeToModerators();
  }

  void _subscribeToModerators() {
    _moderatorSubscription = _firebaseService.getModeratorsStream().listen((moderatorList) {
      if (mounted) {
        setState(() {
          moderatorList.sort((a, b) {
            if (a.pendingDevice != null && b.pendingDevice == null) return -1;
            if (a.pendingDevice == null && b.pendingDevice != null) return 1;
            if (a.status != b.status) {
              if (a.status == 'review') return -1;
              if (b.status == 'review') return 1;
            }
            return a.fullName.compareTo(b.fullName);
          });
          _moderators = moderatorList;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.show(context, 'Failed to load moderators: $error', isError: true);
      }
    });
  }

  @override
  void dispose() {
    _moderatorSubscription.cancel();
    super.dispose();
  }

  Future<void> _approveDevice(Moderator moderator) async {
    try {
      await _firebaseService.approvePendingDevice(moderator.id);
      if (mounted) {
        CustomSnackbar.show(context, 'Device approved for ${moderator.fullName}');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Failed to approve device: $e', isError: true);
      }
    }
  }

  Future<void> _rejectDevice(Moderator moderator) async {
    try {
      await _firebaseService.rejectPendingDevice(moderator.id);
      if (mounted) {
        CustomSnackbar.show(context, 'Device rejected for ${moderator.fullName}');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Failed to reject device: $e', isError: true);
      }
    }
  }

  void _showDeviceDetails(Moderator moderator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Devices for ${moderator.fullName}',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (moderator.approvedDevices.isEmpty)
              const Text('No approved devices'),
            for (var device in moderator.approvedDevices) _buildDeviceItem(moderator, device),

            const SizedBox(height: 16),
            if (moderator.pendingDevice != null) ...[
              Text('Pending Device',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              _buildPendingDeviceItem(moderator),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(Moderator moderator, Map<String, dynamic> device) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              Navigator.pop(context);
              await _firebaseService.removeDevice(moderator.id, device['id']);
              if (mounted) {
                CustomSnackbar.show(context, 'Device removed');
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Remove',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  device['type'] == 'Physical' ? Icons.phone_android : Icons.phone_iphone,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    device['model'] ?? 'Unknown Device',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('OS: ${device['os'] ?? 'Unknown'}'),
            const SizedBox(height: 4),
            Text('Added: ${device['addedAt'] != null ? timeago.format(device['addedAt'].toDate()) : 'Unknown'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDeviceItem(Moderator moderator) {
    if (moderator.pendingDevice == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                moderator.pendingDevice!['type'] == 'Physical' ? Icons.phone_android : Icons.phone_iphone,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  moderator.pendingDevice!['model'] ?? 'Unknown Device',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('OS: ${moderator.pendingDevice!['os'] ?? 'Unknown'}'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _approveDevice(moderator);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectDevice(moderator);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _moderatorSubscription.cancel();
              _subscribeToModerators();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _moderators.isEmpty
          ? const Center(child: Text('No moderators found'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _moderators.length,
        itemBuilder: (context, index) {
          final moderator = _moderators[index];
          return _buildModeratorCard(moderator);
        },
      ),
    );
  }

  Widget _buildModeratorCard(Moderator moderator) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (moderator.id == authProvider.currentUser?.uid) return const SizedBox.shrink();

    Color statusColor;
    switch (moderator.status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'review':
        statusColor = Colors.orange;
        break;
      case 'blocked':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: moderator.pendingDevice != null
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showDeviceDetails(moderator),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      moderator.fullName.isNotEmpty
                          ? moderator.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moderator.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          moderator.email,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      moderator.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (moderator.pendingDevice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'New device login request pending approval',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveDevice(moderator),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectDevice(moderator),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Devices: ${moderator.approvedDevices.length}',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showDeviceDetails(moderator),
                    icon: const Icon(Icons.devices, size: 16),
                    label: const Text('Manage'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}