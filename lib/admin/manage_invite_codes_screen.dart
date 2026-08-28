import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/invitation_model.dart';
import '../../services/search_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'create_invitation_screen.dart';
import 'widgets/admin_ui_kit.dart';

class ManageInviteCodesScreen extends StatefulWidget {
  const ManageInviteCodesScreen({super.key});

  @override
  State<ManageInviteCodesScreen> createState() => _ManageInviteCodesScreenState();
}

class _ManageInviteCodesScreenState extends State<ManageInviteCodesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String _filterStatus = 'All'; // 'All', 'pending', 'claimed'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareInvitation(Invitation invite) {
    final name = invite.fullName.isNotEmpty ? invite.fullName : 'Moderator';
    final message = '''
Hello $name,

You have been invited to join the Mahlete Semay Moderator Portal as a ${invite.role.toUpperCase()}!

Your One-Time Invitation Code: ${invite.code}

How to activate your account:
1. Open the Mahlete Semay App.
2. Go to Settings ⚙️ -> Moderator Portal 🛡️.
3. Tap "Claim Account".
4. Enter your email (${invite.email}), create your password, and enter your invitation code (${invite.code}).

This code is single-use and linked to your email.
''';
    Share.share(message, subject: 'Mahlete Semay - Moderator Portal Invitation');
  }

  Future<void> _deleteInvitation(Invitation invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)?.deleteInvitePrompt ?? 'Delete Invitation?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(AppLocalizations.of(context)?.deleteInviteConfirm(invite.email) ?? 'Are you sure you want to delete the invitation code for "${invite.email}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context)?.deleteAction ?? 'Delete'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.deleteInvitation(invite.id);
        if (mounted) {
          CustomSnackbar.show(context, 'Invitation deleted.');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Failed to delete invitation: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Manage Invitations',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Create New Invitation',
            icon: const Icon(Icons.add_circle_rounded, color: AdminUiKit.goldAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvitationScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Invitation>>(
        stream: _supabaseService.getInvitationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminUiKit.goldAccent));
          }

          final allInvites = snapshot.data ?? [];

          final filteredInvites = allInvites.where((invite) {
            final queryMatch = SearchService().matches(
              query: _searchQuery,
              text: invite.fullName,
              secondaryText: '${invite.email} ${invite.code}',
            );

            bool statusMatch = true;
            if (_filterStatus == 'pending') {
              statusMatch = !invite.isClaimed;
            } else if (_filterStatus == 'claimed') {
              statusMatch = invite.isClaimed;
            }
            return queryMatch && statusMatch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AdminSearchBar(
                  controller: _searchController,
                  hintText: AppLocalizations.of(context)?.searchByNameOrEmail ?? 'Search by name, email, or code...',
                ),
              ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip('All (${allInvites.length})', _filterStatus == 'All', () => setState(() => _filterStatus = 'All')),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending (${allInvites.where((i) => !i.isClaimed).length})', _filterStatus == 'pending', () => setState(() => _filterStatus = 'pending')),
                    const SizedBox(width: 8),
                    _buildFilterChip('Claimed (${allInvites.where((i) => i.isClaimed).length})', _filterStatus == 'claimed', () => setState(() => _filterStatus = 'claimed')),
                  ],
                ),
              ),

              Expanded(
                child: filteredInvites.isEmpty
                    ? AdminEmptyState(
                        icon: Icons.vpn_key_off_rounded,
                        title: AppLocalizations.of(context)?.noInvitationsFound ?? 'No Invitations Found',
                        description: 'No invitation codes match your current filter or search criteria.',
                        actionLabel: 'Create Invitation',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateInvitationScreen()),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredInvites.length,
                        itemBuilder: (context, index) {
                          final invite = filteredInvites[index];
                          return _buildInviteCard(invite, isDark);
                        },
                      ),
              ),
            ],
          );
        },
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

  Widget _buildInviteCard(Invitation invite, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AdminGlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.fullName.isNotEmpty ? invite.fullName : 'Invited Moderator',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        invite.email,
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
                      label: invite.isClaimed ? 'CLAIMED' : 'PENDING',
                      color: invite.isClaimed ? AdminUiKit.emeraldGreen : AdminUiKit.amberOrange,
                      icon: invite.isClaimed ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                    ),
                    const SizedBox(height: 4),
                    AdminStatusBadge(
                      label: invite.role.toUpperCase(),
                      color: invite.role == 'admin' ? AdminUiKit.goldAccent : AdminUiKit.royalBlue,
                      fontSize: 10,
                      isOutlined: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Code Display Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, size: 16, color: AdminUiKit.goldAccent),
                  const SizedBox(width: 8),
                  Text(
                    invite.code,
                    style: GoogleFonts.firaCode(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy Code',
                    splashRadius: 18,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: invite.code));
                      CustomSnackbar.show(context, 'Code copied: ${invite.code}');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    tooltip: 'Share Invitation',
                    splashRadius: 18,
                    onPressed: () => _shareInvitation(invite),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminUiKit.roseRed),
                    tooltip: 'Delete Invitation',
                    splashRadius: 18,
                    onPressed: () => _deleteInvitation(invite),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.createdAgo(timeago.format(invite.createdAt, locale: Localizations.localeOf(context).languageCode)) ?? 'Created ${timeago.format(invite.createdAt, locale: Localizations.localeOf(context).languageCode)}',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}