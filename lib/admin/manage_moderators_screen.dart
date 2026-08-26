import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/moderator_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../services/search_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'create_invitation_screen.dart';
import 'widgets/admin_ui_kit.dart';

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
  String _searchQuery = '';
  String _roleFilter = 'All'; // 'All', 'admin', 'moderator'
  String _statusFilter = 'All'; // 'All', 'active', 'review', 'blocked', 'inactive'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subscribeToModerators();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  void _subscribeToModerators() {
    _moderatorSubscription = _firebaseService.getModeratorsStream().listen((moderatorList) {
      if (mounted) {
        setState(() {
          moderatorList.sort((a, b) {
            if (a.pendingDevice != null && b.pendingDevice == null) return -1;
            if (a.pendingDevice == null && b.pendingDevice != null) return 1;
            if (a.status == 'review' && b.status != 'review') return -1;
            if (b.status == 'review' && a.status != 'review') return 1;
            if (a.role == 'admin' && b.role != 'admin') return -1;
            if (b.role == 'admin' && a.role != 'admin') return 1;
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
    _searchController.dispose();
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

  Future<void> _updateRole(Moderator moderator, String newRole) async {
    try {
      await _firebaseService.updateModeratorRole(moderator.id, newRole);
      if (mounted) {
        CustomSnackbar.show(context, 'Updated ${moderator.fullName} role to ${newRole.toUpperCase()}');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Failed to update role: $e', isError: true);
      }
    }
  }

  Future<void> _toggleBlockStatus(Moderator moderator) async {
    final newStatus = moderator.status == 'blocked' ? 'active' : 'blocked';
    final actionName = newStatus == 'blocked' ? 'Block' : 'Unblock';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$actionName Moderator?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to $actionName "${moderator.fullName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newStatus == 'blocked' ? AdminUiKit.roseRed : AdminUiKit.emeraldGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firebaseService.updateModeratorStatus(moderator.id, newStatus);
        if (mounted) {
          CustomSnackbar.show(context, '${moderator.fullName} is now $newStatus');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Failed to update status: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteModerator(Moderator moderator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Moderator?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to completely remove "${moderator.fullName}" from the team?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firebaseService.deleteModerator(moderator.id);
        if (mounted) {
          CustomSnackbar.show(context, '${moderator.fullName} removed.');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Failed to delete moderator: $e', isError: true);
        }
      }
    }
  }

  void _showModeratorDetails(Moderator mod) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13233D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AdminUiKit.goldAccent.withOpacity(0.18),
                  child: Text(
                    mod.fullName.isNotEmpty ? mod.fullName[0].toUpperCase() : 'M',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AdminUiKit.goldAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mod.fullName,
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        mod.email,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                AdminStatusBadge(
                  label: mod.role.toUpperCase(),
                  color: mod.role == 'admin' ? AdminUiKit.goldAccent : AdminUiKit.royalBlue,
                ),
              ],
            ),
            const Divider(height: 32),

            _buildDetailTile(Icons.info_outline_rounded, 'Status', mod.status.toUpperCase()),
            _buildDetailTile(Icons.phone_android_rounded, 'Current Device', mod.currentDeviceModel ?? 'None bound'),
            if (mod.lastLogin != null)
              _buildDetailTile(Icons.access_time_rounded, 'Last Active', timeago.format(mod.lastLogin!)),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AdminPrimaryButton(
                    label: mod.role == 'admin' ? 'Demote to Moderator' : 'Promote to Admin',
                    icon: Icons.shield_rounded,
                    isSecondary: true,
                    height: 46,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateRole(mod, mod.role == 'admin' ? 'moderator' : 'admin');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminPrimaryButton(
                    label: mod.status == 'blocked' ? 'Unblock' : 'Block',
                    icon: mod.status == 'blocked' ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: mod.status == 'blocked' ? AdminUiKit.emeraldGreen : AdminUiKit.roseRed,
                    height: 46,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleBlockStatus(mod);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AdminUiKit.roseRed),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Permanently Remove Moderator Account'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteModerator(mod);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdminUiKit.goldAccent),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredModerators = _moderators.where((mod) {
      final queryMatch = SearchService().matches(
        query: _searchQuery,
        text: mod.fullName,
        secondaryText: mod.email,
      );
      final roleMatch = _roleFilter == 'All' || mod.role.toLowerCase() == _roleFilter.toLowerCase();
      final statusMatch = _statusFilter == 'All' || mod.status.toLowerCase() == _statusFilter.toLowerCase();
      return queryMatch && roleMatch && statusMatch;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Manage Moderators',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite Moderator',
            icon: const Icon(Icons.person_add_rounded, color: AdminUiKit.goldAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvitationScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminUiKit.goldAccent))
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: AdminSearchBar(
                    controller: _searchController,
                    hintText: 'Search by name or email...',
                  ),
                ),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('All Roles', _roleFilter == 'All', () => setState(() => _roleFilter = 'All')),
                      const SizedBox(width: 8),
                      _buildFilterChip('Admins', _roleFilter == 'admin', () => setState(() => _roleFilter = 'admin')),
                      const SizedBox(width: 8),
                      _buildFilterChip('Moderators', _roleFilter == 'moderator', () => setState(() => _roleFilter = 'moderator')),
                      const SizedBox(width: 14),
                      Container(height: 20, width: 1, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(width: 14),
                      _buildFilterChip('Active', _statusFilter == 'active', () => setState(() => _statusFilter = _statusFilter == 'active' ? 'All' : 'active')),
                      const SizedBox(width: 8),
                      _buildFilterChip('Under Review', _statusFilter == 'review', () => setState(() => _statusFilter = _statusFilter == 'review' ? 'All' : 'review')),
                      const SizedBox(width: 8),
                      _buildFilterChip('Blocked', _statusFilter == 'blocked', () => setState(() => _statusFilter = _statusFilter == 'blocked' ? 'All' : 'blocked')),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: filteredModerators.isEmpty
                      ? AdminEmptyState(
                          icon: Icons.shield_outlined,
                          title: 'No Moderators Found',
                          description: 'No moderators match your current search or filter criteria.',
                          actionLabel: 'Invite New Moderator',
                          onAction: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateInvitationScreen()),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredModerators.length,
                          itemBuilder: (context, index) {
                            final mod = filteredModerators[index];
                            return _buildModeratorCard(mod, isDark);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        AdminUiKit.hapticLight();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
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
  }

  Widget _buildModeratorCard(Moderator mod, bool isDark) {
    final hasPendingDevice = mod.pendingDevice != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AdminGlassCard(
        onTap: () => _showModeratorDetails(mod),
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        borderColor: hasPendingDevice ? AdminUiKit.amberOrange : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AdminUiKit.goldAccent.withOpacity(0.15),
                  child: Text(
                    mod.fullName.isNotEmpty ? mod.fullName[0].toUpperCase() : 'M',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminUiKit.goldAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mod.fullName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                        ),
                      ),
                      Text(
                        mod.email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AdminStatusBadge(
                      label: mod.role.toUpperCase(),
                      color: mod.role == 'admin' ? AdminUiKit.goldAccent : AdminUiKit.royalBlue,
                    ),
                    const SizedBox(height: 4),
                    AdminStatusBadge(
                      label: mod.status.toUpperCase(),
                      color: mod.status == 'active'
                          ? AdminUiKit.emeraldGreen
                          : (mod.status == 'blocked' ? AdminUiKit.roseRed : AdminUiKit.amberOrange),
                      isOutlined: true,
                      fontSize: 10,
                    ),
                  ],
                ),
              ],
            ),

            // Pending Device Approval Banner
            if (hasPendingDevice) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminUiKit.amberOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminUiKit.amberOrange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phonelink_lock_rounded, size: 18, color: AdminUiKit.amberOrange),
                        const SizedBox(width: 8),
                        Text(
                          'New Device Authorization Pending',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AdminUiKit.amberOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Model: ${mod.pendingDevice!['model']} (${mod.pendingDevice!['os']})',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AdminUiKit.emeraldGreen,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Approve Device'),
                            onPressed: () => _approveDevice(mod),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminUiKit.roseRed,
                              side: BorderSide(color: AdminUiKit.roseRed.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Reject'),
                            onPressed: () => _rejectDevice(mod),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}